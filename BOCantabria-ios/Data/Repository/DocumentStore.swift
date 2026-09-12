//
//  DocumentStore.swift
//  The one place that knows what is being downloaded, and what everybody is watching.
//
//  **Es el corazón de la feature**, y existe porque cuatro requisitos son invariantes de
//  coordinación que no tienen otro sitio donde vivir: una sola descarga por documento (FR-026),
//  quien espera no hereda la cancelación de quien inició (FR-028), cancelar no es fallar (FR-027) y
//  **todo camino publica un estado terminal** (FR-029).
//
//  ## El tipo del trabajo en vuelo ES el requisito
//
//  ```swift
//  Task<AppResult<OfficialDocument>, Never>
//  //                                ^^^^^ esto
//  ```
//
//  En la aplicación de origen, quien esperaba una descarga que otro había iniciado **heredaba su
//  cancelación**, porque el `await` de aquella primitiva propaga la excepción. La consecuencia
//  medida allí: los dos botones de reintento —que cancelan y relanzan— dejaban la pantalla cargando
//  **sin botón de reintento**, atascada hasta salir. Arreglarlo costó seis líneas que distinguían
//  «me han cancelado a mí» de «han cancelado al que yo esperaba».
//
//  Aquí no hace falta ninguna de esas seis líneas, y no por listeza: con `Failure == Never`,
//  `await task.value` **no lanza** —comprobado en `_Concurrency.swiftinterface:2556-2571`— y no
//  existe el canal por el que heredar nada. FR-028 sale del sistema de tipos (research.md D-507).
//
//  **La trampa es la contraria**: si alguien tipa esto como `Task<OfficialDocument, Error>` —que es
//  lo que sale natural al escribir `try await` dentro—, vuelve el defecto entero. La forma del tipo
//  no es un detalle de estilo.
//
//  ## `settle` es el no-cancelable de esta plataforma
//
//  Allí la limpieza necesitaba un envoltorio explícito. Aquí la cancelación es cooperativa y **un
//  salto a un actor no es un punto de cancelación**: llamar a un método de actor desde una tarea ya
//  cancelada lo ejecuta entero, y `FileManager` es síncrono y no consulta nada. Por eso `settle` es
//  no-cancelable **por construcción** (D-509).
//
//  La regla que eso impone, y que hay que respetar: **dentro de `settle` no puede aparecer un
//  `await`**, ni un `Task.sleep`, ni un `Task.checkCancellation()`. El día que haga falta trabajo
//  asíncrono ahí, el equivalente es un `Task { }` poseído por este actor.
//

import Foundation

actor DocumentStore {
    private struct Job {
        let task: Task<AppResult<OfficialDocument>, Never>
        var watchers: Int
    }

    private let downloader: DocumentDownloader
    private let cache: DocumentCache
    private let crashReporter: CrashReporter
    private let budget: Int64

    private var statuses: [String: DocumentStatus] = [:]
    private var observers: [String: [UUID: AsyncStream<DocumentStatus>.Continuation]] = [:]
    private var inFlight: [String: Job] = [:]

    init(
        downloader: DocumentDownloader,
        cache: DocumentCache,
        crashReporter: CrashReporter,
        budget: Int64 = FileDocumentCache.defaultBudget
    ) {
        self.downloader = downloader
        self.cache = cache
        self.crashReporter = crashReporter
        self.budget = budget
    }

    // MARK: - Observación

    /// **Lo primero que recibe quien se suscribe es el estado vigente.**
    ///
    /// Sin esa reproducción, el visor que se abre con el documento ya disponible no recibe nada
    /// —la publicación ocurrió antes de que él llegara— y **se queda cargando para siempre**: un
    /// cuelgue silencioso, sin excepción y sin nada en el registro, indistinguible a simple vista
    /// del defecto que FR-029 viene a evitar. La línea del `yield` de abajo es la feature (D-510).
    nonisolated func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus> {
        // «El más nuevo, uno»: el progreso son cientos de valores de los que solo interesa el
        // último, y el terminal es el que no se puede perder.
        let (stream, continuation) = AsyncStream.makeStream(
            of: DocumentStatus.self, bufferingPolicy: .bufferingNewest(1)
        )
        let id = UUID()
        // `onTermination` es **síncrono** —comprobado en el SDK—, así que retirar la continuación
        // del actor obliga a saltar. Sin esto no compila; con un `nonisolated(unsafe)` compilaría
        // y sería una carrera.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id, for: externalKey) }
        }
        Task { await self.addObserver(id, continuation, for: externalKey) }
        return stream
    }

    private func addObserver(
        _ id: UUID,
        _ continuation: AsyncStream<DocumentStatus>.Continuation,
        for key: String
    ) {
        observers[key, default: [:]][id] = continuation
        continuation.yield(statuses[key] ?? .absent)
    }

    private func removeObserver(_ id: UUID, for key: String) {
        observers[key]?[id] = nil
        if observers[key]?.isEmpty == true { observers[key] = nil }
    }

    private func publish(_ key: String, _ status: DocumentStatus) {
        statuses[key] = status
        for continuation in observers[key]?.values ?? [:].values { continuation.yield(status) }
    }

    // MARK: - Obtención

    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument> {
        let key = publication.externalKey

        if let cached = cache.get(key) {
            publish(key, .available(cached))
            return .success(cached)
        }

        let task = claim(key, publication)
        return await withTaskCancellationHandler {
            // **No lanza**: `Failure == Never`. Quien espera no puede heredar nada.
            await task.value
        } onCancel: {
            Task { await self.withdraw(key) }
        }
    }

    /// ¿Estaba ya en el dispositivo antes de pedirlo?
    ///
    /// Lo consulta el repositorio para poder marcar el evento, y **nada más**: la decisión de
    /// descargar o no la toma `ensureLocalCopy`, que es quien tiene el cerrojo del actor. Preguntar
    /// aquí y decidir fuera sería una carrera.
    func isCached(_ externalKey: String) -> Bool {
        cache.get(externalKey) != nil
    }

    func releaseUnused() async {
        // Lo que se está mirando **no se retira**: hacerlo dejaría al visor leyendo un fichero que
        // acaba de desaparecer (FR-030).
        let enUso = Set(statuses.compactMap { $0.value.document != nil ? $0.key : nil })
        cache.evict(maxBytes: budget, keeping: enUso)
    }

    /// Crea el trabajo, o se apunta al que ya hay.
    private func claim(
        _ key: String,
        _ publication: Publication
    ) -> Task<AppResult<OfficialDocument>, Never> {
        if var job = inFlight[key] {
            job.watchers += 1
            inFlight[key] = job
            return job.task
        }
        // `Task { }` **no hereda la cancelación** del contexto que lo crea: hereda prioridad,
        // valores de tarea y aislamiento. Es lo que hace que la descarga pertenezca al almacén y no
        // a la pantalla que la pidió primero. Y **no es `Task.detached`**, que la regla 12 prohíbe.
        let task = Task { [weak self] in
            guard let self else { return AppResult<OfficialDocument>.failure(.cancelled) }
            return await self.perform(publication)
        }
        inFlight[key] = Job(task: task, watchers: 1)
        return task
    }

    /// Un espectador se marcha. **Se cancela cuando se va el último** (FR-027, FR-028).
    ///
    /// Es lo que sustituye al traspaso de propiedad que la aplicación de origen necesitó, y es más
    /// simple: no hay dueño, hay público.
    private func withdraw(_ key: String) {
        guard var job = inFlight[key] else { return }
        job.watchers -= 1
        if job.watchers <= 0 {
            job.task.cancel()
            inFlight[key] = job
        } else {
            inFlight[key] = job
        }
    }

    private func perform(_ publication: Publication) async -> AppResult<OfficialDocument> {
        let key = publication.externalKey
        publish(key, .downloading(bytesRead: 0, totalBytes: nil))

        let part = cache.stage(key)
        let outcome: AppResult<OfficialDocument>

        switch await downloader.download(from: publication.documentUrl, into: part, progress: { [weak self] read, total in
            await self?.publishProgress(key, read: read, total: total)
        }) {
        case .downloaded(let byteCount, let checksum):
            if let document = cache.commit(key, from: part, byteCount: byteCount, checksum: checksum) {
                outcome = .success(document)
            } else {
                // El disco lleno llega por aquí. **Es un fallo y se publica como tal**: es
                // exactamente el camino que en la aplicación de origen devolvía el error sin
                // publicarlo y dejaba la pantalla cargando para siempre.
                crashReporter.log("document: commit failed")
                outcome = .failure(.storage)
            }
        case .rejected(.cancelled):
            outcome = .failure(.cancelled)
        case .rejected(let reason):
            // El motivo exacto va **al registro**, nunca a analítica y nunca a la pantalla. Y sin
            // el título, la dirección ni la clave.
            crashReporter.log("document: rejected: \(reason.rawValue)")
            outcome = .failure(reason.domainError)
        }

        settle(key: key, part: part, outcome: outcome)
        return outcome
    }

    private func publishProgress(_ key: String, read: Int64, total: Int64?) {
        // Solo mientras siga siendo una descarga: un progreso que llegue tarde no puede resucitar
        // un estado ya terminal.
        guard case .downloading = statuses[key] ?? .absent else { return }
        publish(key, .downloading(bytesRead: read, totalBytes: total))
    }

    /// **Síncrona y aislada al actor: ni un `await` dentro.** Ver la cabecera.
    private func settle(key: String, part: URL, outcome: AppResult<OfficialDocument>) {
        cache.discard(part)
        inFlight[key] = nil

        switch outcome {
        case .success(let document):
            publish(key, .available(document))
        case .failure(.cancelled):
            // **Cancelar no es fallar** (FR-027). Quien canceló ya no está mirando, y la próxima
            // visita no debe encontrarse un error que nadie provocó.
            //
            // El guardián: solo si lo que hay sigue siendo *esta* descarga. Sin él, la limpieza de
            // un trabajo viejo pisa el `downloading` de uno nuevo y la barra desaparece con la
            // descarga en marcha.
            if case .downloading = statuses[key] ?? .absent { publish(key, .absent) }
        case .failure(let error):
            publish(key, .failed(error))
        }
    }
}
