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

// MARK: - Orígenes de contenido

actor FakeContentRemoteDataSource: ContentRemoteDataSource {
    enum Behaviour: Sendable {
        case responds([ContentItemDTO])
        case fails
        /// Falla la primera vez y responde después. Es lo que hace comprobable el reintento.
        case failsThenResponds([ContentItemDTO])
    }

    struct Failure: Error {}

    private let behaviour: Behaviour
    private(set) var callCount = 0

    init(_ behaviour: Behaviour) { self.behaviour = behaviour }

    func fetchContentItems() async throws -> [ContentItemDTO] {
        callCount += 1
        switch behaviour {
        case .responds(let items):
            return items
        case .fails:
            throw Failure()
        case .failsThenResponds(let items):
            if callCount == 1 { throw Failure() }
            return items
        }
    }
}

actor FakeContentLocalDataSource: ContentLocalDataSource {
    private(set) var stored: [ContentItemRecord]
    private(set) var writeCount = 0

    init(stored: [ContentItemRecord] = []) { self.stored = stored }

    func readContentItems() async -> [ContentItemRecord] { stored }

    func writeContentItems(_ items: [ContentItemRecord]) async {
        stored = items
        writeCount += 1
    }
}

/// Un repositorio falseable, para las pruebas del caso de uso y del modelo de pantalla.
struct FakeContentRepository: ContentRepository {
    let result: AppResult<[ContentItem]>
    func contentItems() async -> AppResult<[ContentItem]> { result }
}

/// Devuelve resultados distintos en cada llamada: el primero, el segundo, y así. Es lo que permite
/// comprobar que reintentar desde un error llega a contenido.
actor SequencedContentRepository: ContentRepository {
    private let results: [AppResult<[ContentItem]>]
    private(set) var callCount = 0

    init(_ results: [AppResult<[ContentItem]>]) { self.results = results }

    func contentItems() async -> AppResult<[ContentItem]> {
        defer { callCount += 1 }
        return results[min(callCount, results.count - 1)]
    }
}

// MARK: - Transversales

/// No espera de verdad. Es lo que mantiene la suite por debajo de los dos minutos (SC-003).
struct ImmediateClock: AppClock {
    func sleep(seconds: Double) async throws {}
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
/// tiempo a mano.
///
/// **Por qué no basta `ImmediateClock`.** El arranque enfrenta el trabajo real contra una espera
/// de ocho segundos, y gana el primero que termine. Con un reloj que devuelve al instante, *esa
/// espera gana siempre*: toda prueba del arranque acabaría en «se agotó el tiempo», las del camino
/// feliz fallarían por un motivo que no tiene nada que ver con lo que quieren comprobar, y la del
/// propio límite pasaría en verde **sin haber comprobado nada**, porque también habría ganado si
/// el límite estuviera mal escrito. Lo mismo vale para el mínimo en pantalla: con un reloj que no
/// espera no se distingue «esperó en paralelo» de «no esperó».
///
/// Espera girando en vez de con continuaciones, a propósito: `Task.yield()` cede el actor para que
/// `advance(by:)` pueda entrar, y `Task.checkCancellation()` hace que una espera cancelada muera
/// en el acto —que es justo lo que tiene que pasar cuando el trabajo gana la carrera—. Es código
/// de prueba y el bucle está acotado por lo que la prueba adelante.
actor ManualClock: AppClock {
    private var now: Double = 0
    private var requested: [Double] = []

    /// Lo que se ha pedido esperar, en orden. Sirve para afirmar *qué* se esperó, no solo cuánto.
    var requestedSleeps: [Double] { requested }

    func sleep(seconds: Double) async throws {
        requested.append(seconds)
        let deadline = now + seconds
        while now < deadline {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    /// Adelanta el tiempo virtual. Las esperas cuyo plazo se cumpla se reanudan.
    func advance(by seconds: Double) async {
        now += seconds
        await Task.yield()
    }

    /// Espera a que haya al menos `count` esperas registradas.
    ///
    /// Sin esto, adelantar el reloj antes de que el trabajo haya llegado a pedir su espera hace
    /// que el adelanto se pierda y la prueba se cuelgue, que es la forma más cara de fallar.
    func waitUntilSleeping(count: Int = 1) async {
        while requested.count < count {
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

// MARK: - Constructores

func contentItem(id: String = "1", title: String = "Un título") -> ContentItem {
    ContentItem(id: id, title: title)
}

func contentItemDTO(id: String = "1", label: String = "Un título") -> ContentItemDTO {
    ContentItemDTO(id: id, label: label)
}

func contentItemRecord(id: String = "1", title: String = "Un título") -> ContentItemRecord {
    ContentItemRecord(id: id, title: title)
}
