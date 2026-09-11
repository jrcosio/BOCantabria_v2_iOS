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
