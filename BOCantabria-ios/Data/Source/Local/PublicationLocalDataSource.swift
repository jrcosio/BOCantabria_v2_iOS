//
//  PublicationLocalDataSource.swift
//  The only door between GRDB and everything else.
//
//  **Existe porque la regla 10 lo exige, y la regla 10 tenía razón.** El primer intento puso la
//  observación en el repositorio y la escritura en el coordinador, y las dos cosas obligaban a
//  nombrar `Database` fuera de esta carpeta. Empujado aquí, el resultado es mejor: hay un solo
//  fichero que sabe SQL, y lo que sale de él son tipos de dominio.
//
//  Lo que devuelve son `AsyncStream<AppResult<…>>`, no la observación de GRDB: `AsyncValueObservation`
//  ya es `AsyncSequence` y `Sendable`, así que Combine no hace falta —cosa imprescindible, porque
//  la constitución lo prohíbe—, pero es un tipo de la biblioteca y no puede aparecer en la firma
//  de un protocolo de dominio.
//

import Foundation
import GRDB

struct PublicationLocalDataSource: Sendable {
    private let provider: BocDatabaseProvider
    private let crashReporter: CrashReporter

    init(provider: BocDatabaseProvider, crashReporter: CrashReporter) {
        self.provider = provider
        self.crashReporter = crashReporter
    }

    /// La base ya abierta. Si no lo está —la portada no llegó a prepararla, o falló—, lo que sale
    /// de aquí son flujos vacíos y lecturas nulas, nunca un cierre inesperado.
    private var database: BocDatabase? { provider.database() }

    // MARK: - Observación

    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>> {
        stream { database in
            try PublicationQueries.publications(for: selection, in: database)
        }
    }

    /// Una publicación concreta. Emite `nil` cuando ya no está guardada, y eso es un éxito.
    func observePublication(externalKey: String) -> AsyncStream<AppResult<Publication?>> {
        stream { database in
            try PublicationQueries.publication(externalKey: externalKey, in: database)
        }
    }

    func observeHeader(
        _ selection: HomeSelection,
        title: String
    ) -> AsyncStream<AppResult<BulletinHeader>> {
        stream { database in
            BulletinHeader(
                title: title,
                date: try PublicationQueries.latestDate(for: selection, in: database),
                count: try PublicationQueries.count(for: selection, in: database),
                // Los dos significados de la fecha, que son los dos rótulos (FR-034).
                dateMeaning: selection == .todaysBulletin ? .edition : .latestInSection
            )
        }
    }

    /// Bombea la observación de la base hacia un flujo de dominio.
    ///
    /// **La tarea que bombea tiene dueño, aunque no lo parezca**: vive en una variable local y se
    /// cancela desde `onTermination`. Cuando la vista abandona su `.task`, el `for await` del
    /// modelo de pantalla se cancela, el flujo termina, la tarea se cancela y la observación se
    /// desmonta sola. Se documenta porque a primera vista parece una `Task` sin dueño, que este
    /// proyecto prohíbe.
    private func stream<T: Sendable>(
        _ fetch: @escaping @Sendable (Database) throws -> T
    ) -> AsyncStream<AppResult<T>> {
        guard let database else {
            return AsyncStream { continuation in
                continuation.yield(.failure(.storage))
                continuation.finish()
            }
        }
        let observation = database.observe(fetch)
        let reporter = crashReporter
        return AsyncStream { continuation in
            let task = Task {
                do {
                    for try await value in observation {
                        continuation.yield(.success(value))
                    }
                } catch is CancellationError {
                    // La cancelación se repropaga cerrando el flujo, no se traduce: quien la
                    // canceló ya no está mirando.
                } catch {
                    reporter.log("reads: observation failed: \(error)")
                    continuation.yield(.failure(.storage))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Lectura puntual

    //  Cada una se escribe con `guard let` y `do/catch` explícitos. Encadenar `try?` con opcionales
    //  y `??` compila, pero el comprobador de tipos tarda minutos en resolverlo: la primera
    //  versión de este fichero dejó la suite sin terminar en diez minutos.

    func lastSuccess() -> Date? {
        guard let database else { return nil }
        return try? database.read { try PublicationQueries.lastSuccess(in: $0) }
    }

    func hasAnyPublication() -> Bool {
        guard let database else { return false }
        let count: Int? = try? database.read { database in
            try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM publications")
        }
        return (count ?? 0) > 0
    }

    func knownBodyHash(feedId: String) -> String? {
        guard let database else { return nil }
        let hash: String?? = try? database.read { database in
            try PublicationQueries.knownBodyHash(feedId: feedId, in: database)
        }
        return hash ?? nil
    }

    /// Lectura puntual de una publicación. Lanza si la base no se puede leer.
    ///
    /// Existe además de la observación porque la prueba de la consulta no necesita un flujo, y
    /// porque el caso de compartir desde una lista tampoco.
    func publication(externalKey: String) throws -> Publication? {
        guard let database else { return nil }
        return try database.read { database in
            try PublicationQueries.publication(externalKey: externalKey, in: database)
        }
    }

    func publications(for selection: HomeSelection) -> [Publication] {
        guard let database else { return [] }
        let rows: [Publication]? = try? database.read { database in
            try PublicationQueries.publications(for: selection, in: database)
        }
        return rows ?? []
    }

    // MARK: - Escritura

    /// Una transacción por fuente, y **la escribe siempre el mismo llamante**: el padre del grupo
    /// de tareas. Un solo escritor.
    func store(
        _ publications: [Publication],
        bodyHash: String,
        feedId: String,
        at instant: Date
    ) -> (inserted: Int, updated: Int) {
        guard let database else { return (0, 0) }
        do {
            return try database.write { database in
                let counts = try PublicationQueries.upsert(
                    publications, seenAt: instant, in: database
                )
                try PublicationQueries.markSuccess(
                    feedId: feedId, bodyHash: bodyHash, at: instant, in: database
                )
                return counts
            }
        } catch {
            crashReporter.log("sync: write failed for \(feedId): \(error)")
            return (0, 0)
        }
    }

    func recordFailure(feedId: String) {
        guard let database else { return }
        try? database.write { database in
            try PublicationQueries.markFailure(feedId: feedId, in: database)
        }
    }

    /// Las sentencias ejecutadas, cuando la base se abrió recogiéndolas. Es lo que hace
    /// demostrable que nunca se borra una publicación.
    var executedStatements: [String] { database?.executedStatements ?? [] }
}
