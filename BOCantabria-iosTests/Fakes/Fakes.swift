//
//  Fakes.swift
//  The shared test doubles.
//
//  Escritos a mano contra los protocolos (research.md D-110). Swift no tiene *mocking* dinámico y
//  no hace falta: lo que se quiere afirmar es **exactamente qué se envía**, y un espía que guarda
//  lo recibido es más directo y más legible que un doble generado.
//
//  **Todos son `Sendable`**, y eso no es decoración: con concurrencia estricta, un doble que cruce
//  la frontera de un `actor` sin serlo no compila. Descubrirlo en el doble número doce sale caro.
//

import Foundation
import Synchronization
@testable import BOCantabria_ios

// MARK: - Transversales

/// No espera nunca, y **su «ahora» no se mueve**.
///
/// La fecha es un valor del inicializador y no `Date()` a propósito: un doble que devolviera la
/// hora del sistema sería el reloj del sistema disfrazado, y la prueba volvería a depender de
/// cuándo se ejecuta.
struct ImmediateClock: AppClock {
    /// Un instante fijo y reconocible: 1 de enero de 2026, 00:00 UTC.
    static let fixedNow = Date(timeIntervalSince1970: 1_767_225_600)

    let instant: Date

    init(now instant: Date = ImmediateClock.fixedNow) {
        self.instant = instant
    }

    func sleep(seconds: Double) async throws {}
    func now() -> Date { instant }
}

/// Aleatoriedad que no lo es. `FixedRandom(0.5)` deja el jitter en el centro del intervalo, así
/// que la espera resultante es exactamente la nominal y se puede afirmar.
struct FixedRandom: AppRandom {
    let value: Double

    init(_ value: Double = 0.5) {
        self.value = value
    }

    func fraction() -> Double { value }
}

final class RecordingAnalyticsTracker: AnalyticsTracker {
    private let storage = Mutex<[AnalyticsEvent]>([])

    var events: [AnalyticsEvent] { storage.withLock { $0 } }

    var screenViews: [String] {
        events
            .filter { $0.name == "screen_view" }
            .compactMap { $0.parameters[AnalyticsEvent.parameterScreenName] }
    }

    func track(_ event: AnalyticsEvent) {
        storage.withLock { $0.append(event) }
    }

    func trackScreenView(_ screenName: String) {
        track(AnalyticsEvent(name: "screen_view", parameters: [AnalyticsEvent.parameterScreenName: screenName]))
    }
}

final class RecordingCrashReporter: CrashReporter {
    private let nonFatalStorage = Mutex<[String]>([])
    private let messageStorage = Mutex<[String]>([])

    /// Se guarda el **nombre del tipo**, no el error, porque es lo único que la implementación
    /// real puede registrar.
    var nonFatalTypes: [String] { nonFatalStorage.withLock { $0 } }
    var messages: [String] { messageStorage.withLock { $0 } }

    func recordNonFatal(_ error: Error) {
        nonFatalStorage.withLock { $0.append(String(describing: type(of: error))) }
    }

    func log(_ message: String) {
        messageStorage.withLock { $0.append(message) }
    }
}

/// Un reloj que **no avanza solo**: cada espera queda suspendida hasta que la prueba adelanta el
/// tiempo a mano, y su «ahora» solo se mueve cuando la prueba lo mueve.
///
/// **Por qué no basta `ImmediateClock`.** El arranque enfrenta el trabajo real contra una espera
/// de ocho segundos, y gana el primero que termine. Con un reloj que devuelve al instante, *esa
/// espera gana siempre*: toda prueba del arranque acabaría en «se agotó el tiempo», las del camino
/// feliz fallarían por un motivo que no tiene nada que ver con lo que quieren comprobar, y la del
/// propio límite pasaría en verde **sin haber comprobado nada**, porque también habría ganado si
/// el límite estuviera mal escrito. Lo mismo vale para la caducidad de la caché: con un reloj que
/// no se mueve no se distingue «no había caducado» de «no se miró».
///
/// **Por qué es una clase con cerrojo y no un `actor`.** Porque `AppClock.now()` es síncrono, y un
/// actor no puede ofrecer un método síncrono que lea su estado. El `Mutex` envuelto en una clase
/// es el patrón que el proyecto ya usa en `RecordingAnalyticsTracker` (research.md D-317).
///
/// Espera girando en vez de con continuaciones, a propósito: `Task.yield()` cede el hilo para que
/// `advance(by:)` pueda entrar, y `Task.checkCancellation()` hace que una espera cancelada muera
/// en el acto —que es justo lo que tiene que pasar cuando el trabajo gana la carrera—. Es código
/// de prueba y el bucle está acotado por lo que la prueba adelante.
final class ManualClock: AppClock, @unchecked Sendable {
    private struct State {
        var elapsed: Double = 0
        var requested: [Double] = []
    }

    private let state = Mutex(State())
    private let origin: Date

    init(now origin: Date = ImmediateClock.fixedNow) {
        self.origin = origin
    }

    /// Lo que se ha pedido esperar, en orden. Sirve para afirmar *qué* se esperó, no solo cuánto.
    var requestedSleeps: [Double] { state.withLock { $0.requested } }

    func now() -> Date {
        origin.addingTimeInterval(state.withLock { $0.elapsed })
    }

    func sleep(seconds: Double) async throws {
        let deadline = state.withLock { state -> Double in
            state.requested.append(seconds)
            return state.elapsed + seconds
        }
        while state.withLock({ $0.elapsed }) < deadline {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    /// Adelanta el tiempo virtual. Las esperas cuyo plazo se cumpla se reanudan.
    func advance(by seconds: Double) async {
        state.withLock { $0.elapsed += seconds }
        await Task.yield()
    }

    /// Espera a que haya al menos `count` esperas registradas.
    ///
    /// Sin esto, adelantar el reloj antes de que el trabajo haya llegado a pedir su espera hace
    /// que el adelanto se pierda y la prueba se cuelgue, que es la forma más cara de fallar.
    func waitUntilSleeping(count: Int = 1) async {
        while state.withLock({ $0.requested.count }) < count {
            await Task.yield()
        }
    }
}

// MARK: - Arranque

actor FakeAppConfigRepository: AppConfigRepository {
    enum Behaviour: Sendable {
        case responds(AppConfig)
        case fails(DomainError)
        /// Falla la primera vez y responde después. Es la que necesita el reintento.
        case failsThenResponds(AppConfig)
        /// No termina nunca por sí sola. Muere en cuanto la cancelan, que es lo que hace el
        /// límite de espera al ganar la carrera.
        case neverReturns
    }

    private let behaviour: Behaviour
    private(set) var callCount = 0

    init(_ behaviour: Behaviour) {
        self.behaviour = behaviour
    }

    func loadConfig() async -> AppResult<AppConfig> {
        defer { callCount += 1 }
        switch behaviour {
        case let .responds(config):
            return .success(config)
        case let .fails(error):
            return .failure(error)
        case let .failsThenResponds(config):
            return callCount == 0 ? .failure(.network) : .success(config)
        case .neverReturns:
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return .failure(.unknown)
            }
            return .failure(.unknown)
        }
    }
}

struct FakeConnectivityRepository: ConnectivityRepository {
    let online: Bool

    init(online: Bool = true) {
        self.online = online
    }

    func isOnline() async -> Bool { online }
}

struct FakeRemoteConfigDataSource: RemoteConfigDataSource {
    struct Failure: Error {}

    let values: RemoteConfigValues?

    init(values: RemoteConfigValues? = .empty) {
        self.values = values
    }

    func fetchValues() async throws -> RemoteConfigValues {
        guard let values else { throw Failure() }
        return values
    }
}

struct FakeConnectivityDataSource: ConnectivityDataSource {
    let online: Bool

    func isOnline() async -> Bool { online }
}

func appConfig(
    minimum: String = "0.0.0",
    maintenance: String? = nil
) -> AppConfig {
    AppConfig(minSupportedVersion: AppVersion(minimum)!, maintenanceMessage: maintenance)
}

// MARK: - Boletín

/// Repositorio de publicaciones con respuestas fijas. Los flujos emiten **una vez y terminan**,
/// que es lo que hace afirmables las pruebas de los casos de uso sin montar una base.
///
/// Es una clase con cerrojo y no un `actor` porque `observePublications` es síncrona —devuelve un
/// flujo, no lo espera— y tiene que poder anotar la selección **en el acto**. Con un actor habría
/// que anotarla desde una tarea, y la prueba afirmaría antes de que esa tarea llegara a correr:
/// se pondría roja por la forma del doble y no por lo que quiere comprobar.
final class FakePublicationRepository: PublicationRepository, @unchecked Sendable {
    private let publications: AppResult<[Publication]>
    private let header: AppResult<BulletinHeader>
    private let refreshResult: AppResult<SyncSummary>
    private let stale: Bool

    private let calls = Mutex<[Bool]>([])
    private let selections = Mutex<[HomeSelection]>([])

    var refreshCalls: [Bool] { calls.withLock { $0 } }
    var observedSelections: [HomeSelection] { selections.withLock { $0 } }

    /// Los valores que emite `observePublication`, en orden. Varios valores sirven para comprobar
    /// que el detalle **se corrige solo** cuando una sincronización cambia la fila (FR-003).
    private let single: [AppResult<Publication?>]
    private let observedKeys = Mutex<[String]>([])
    var observedPublicationKeys: [String] { observedKeys.withLock { $0 } }

    init(
        publications: AppResult<[Publication]> = .success([]),
        header: AppResult<BulletinHeader> = .success(.empty),
        refreshResult: AppResult<SyncSummary> = .success(SyncSummary(succeededFeeds: 19)),
        stale: Bool = true,
        single: [AppResult<Publication?>] = [.success(nil)]
    ) {
        self.publications = publications
        self.header = header
        self.refreshResult = refreshResult
        self.stale = stale
        self.single = single
    }

    func observePublication(externalKey: String) -> AsyncStream<AppResult<Publication?>> {
        observedKeys.withLock { $0.append(externalKey) }
        let values = single
        return AsyncStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }

    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>> {
        selections.withLock { $0.append(selection) }
        let value = publications
        return AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }

    func observeHeader(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>> {
        let value = header
        return AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }

    func isCacheStale() async -> Bool { stale }

    func refresh(force: Bool) async -> AppResult<SyncSummary> {
        calls.withLock { $0.append(force) }
        return refreshResult
    }
}

/// El repositorio de documentos, con el estado que la prueba le dicte.
///
/// **Emite el estado vigente al suscribirse**, igual que el de verdad: sin esa reproducción, una
/// prueba que se suscriba después de disparar la descarga no recibiría nada y se colgaría en vez de
/// fallar (research.md D-510).
final class FakeDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let statuses: Mutex<[String: [DocumentStatus]]>
    private let result: AppResult<OfficialDocument>
    private let ensureCalls = Mutex<[String]>([])
    private let releaseCalls = Mutex<Int>(0)

    var ensuredKeys: [String] { ensureCalls.withLock { $0 } }
    var releaseCount: Int { releaseCalls.withLock { $0 } }

    init(
        statuses: [String: [DocumentStatus]] = [:],
        result: AppResult<OfficialDocument> = .failure(.network)
    ) {
        self.statuses = Mutex(statuses)
        self.result = result
    }

    func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus> {
        let values = statuses.withLock { $0[externalKey] ?? [.absent] }
        return AsyncStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }

    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument> {
        ensureCalls.withLock { $0.append(publication.externalKey) }
        return result
    }

    func releaseUnused() async { releaseCalls.withLock { $0 += 1 } }
}

func officialDocument(
    externalKey: String = "boc:439765",
    localPath: String = "/tmp/boc/documents/abc.pdf",
    byteCount: Int64 = 609,
    checksum: String = String(repeating: "a", count: 64),
    lastUsedAt: Date = ImmediateClock.fixedNow
) -> OfficialDocument {
    OfficialDocument(
        externalKey: externalKey, localPath: localPath, byteCount: byteCount,
        checksum: checksum, lastUsedAt: lastUsedAt
    )
}

func publication(
    externalKey: String = "boc:439765",
    title: String = "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva",
    sectionCode: String = "1",
    subsectionCode: String? = nil,
    date: String = "2026-08-26",
    warnings: Set<ParserWarning> = []
) -> Publication {
    Publication(
        externalKey: externalKey,
        // Se deriva de la clave: `blob_id` es **único** en la base, así que un doble que lo fijara
        // siempre igual haría fallar la transacción entera al guardar más de una publicación —y la
        // prueba vería una lista vacía sin saber por qué—.
        blobId: externalKey.hasPrefix("boc:") ? String(externalKey.dropFirst(4)) : nil,
        idSource: externalKey.hasPrefix("boc:") ? .blobId : .canonicalUrl,
        feedId: "6802081",
        sectionCode: sectionCode,
        subsectionCode: subsectionCode,
        title: title,
        issuer: "Ayuntamiento de Piélagos",
        organizationPath: ["Ayuntamiento de Piélagos"],
        editionType: .ordinary,
        publicationDate: BocDate(iso: date)!,
        documentUrl: URL(
            string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob="
                + (externalKey.hasPrefix("boc:") ? String(externalKey.dropFirst(4)) : "0")
        )!,
        rawCategories: "1.Disposiciones Generales|Ayuntamiento de Piélagos|ORD",
        warnings: warnings
    )
}

/// Almacén que se abre o no se abre, según le digan. Es lo que permite probar el desenlace de la
/// portada cuando la base no se puede migrar, sin tener que corromper un fichero.
struct FakeStorage: StoragePreparing {
    let result: AppResult<Void>

    init(opens: Bool = true) {
        result = opens ? .success(()) : .failure(.storage)
    }

    func prepare() async -> AppResult<Void> { result }
}

/// Descargador que **cuenta cuántas descargas hay en vuelo y guarda el máximo**, y que se queda
/// suspendido hasta que la prueba lo libera.
///
/// La retención es imprescindible: sin ella, la prueba del tope de cuatro mediría la velocidad de
/// la máquina en lugar del tope, y pasaría en verde aunque el tope estuviera mal escrito.
actor CountingFeedDownloader: FeedDownloader {
    private let body: Data
    private let failing: Set<String>
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var calls: [String] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var held = false

    init(body: Data, failing: Set<String> = [], holdUntilReleased: Bool = false) {
        self.body = body
        self.failing = failing
        self.held = holdUntilReleased
    }

    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult {
        calls.append(definition.feedId)
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        if held { await waitForRelease() }
        inFlight -= 1

        if failing.contains(definition.feedId) { return .failed(.serverError) }
        let hash = HttpFeedDownloader.sha256(of: body)
        if knownBodyHash == hash { return .notModified }
        return .fetched(body: body, bodyHash: hash)
    }

    /// Deja pasar a todas las que están esperando.
    func release() {
        held = false
        gate?.resume()
        gate = nil
    }

    /// Espera a que haya al menos `count` descargas en vuelo. Sin esto, liberar antes de que
    /// lleguen haría que la prueba midiera otra cosa.
    func waitUntilInFlight(_ count: Int) async {
        while inFlight < count { await Task.yield() }
    }

    private func waitForRelease() async {
        while held {
            await Task.yield()
        }
    }
}

/// Descargador que siempre falla. Es el camino de «ninguna fuente responde».
struct FailingFeedDownloader: FeedDownloader {
    let failure: FeedFailure

    init(_ failure: FeedFailure = .offline) {
        self.failure = failure
    }

    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult {
        .failed(failure)
    }
}
