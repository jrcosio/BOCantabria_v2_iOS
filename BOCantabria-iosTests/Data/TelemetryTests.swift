//
//  TelemetryTests.swift
//
//  Se prueba **lo que este proyecto controla**: qué nombre y qué parámetros salen hacia el
//  proveedor, y que un fallo suyo no llega a quien llama. Lo que pase al otro lado de esa frontera
//  se comprueba una vez a mano, en la consola (quickstart.md §6).
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

private struct SinkFailure: Error {}

private final class RecordingAnalyticsSink: AnalyticsSink {
    private let storage = Mutex<[(name: String, parameters: [String: String])]>([])
    private let shouldFail: Bool

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    var sent: [(name: String, parameters: [String: String])] { storage.withLock { $0 } }

    func logEvent(_ name: String, parameters: [String: String]) throws {
        storage.withLock { $0.append((name, parameters)) }
        if shouldFail { throw SinkFailure() }
    }
}

private final class RecordingCrashSink: CrashSink {
    private let errorStorage = Mutex<[String]>([])
    private let messageStorage = Mutex<[String]>([])
    private let shouldFail: Bool

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    var recordedTypes: [String] { errorStorage.withLock { $0 } }
    var messages: [String] { messageStorage.withLock { $0 } }

    func record(_ error: Error) throws {
        errorStorage.withLock { $0.append(String(describing: type(of: error))) }
        if shouldFail { throw SinkFailure() }
    }

    func log(_ message: String) throws {
        messageStorage.withLock { $0.append(message) }
        if shouldFail { throw SinkFailure() }
    }
}

@Suite("Telemetría sobre el proveedor")
struct TelemetryTests {

    @Test("Envía el nombre del evento y sus parámetros")
    func sendsNameAndParameters() {
        let sink = RecordingAnalyticsSink()
        let tracker = FirebaseAnalyticsTracker(sink: sink)

        tracker.track(AnalyticsEvent(name: "boc_test", parameters: ["results": "3"]))

        #expect(sink.sent.count == 1)
        #expect(sink.sent[0].name == "boc_test")
        #expect(sink.sent[0].parameters == ["results": "3"])
    }

    @Test("Nunca envía parámetros personales")
    func neverSendsPersonalParameters() {
        let sink = RecordingAnalyticsSink()
        let tracker = FirebaseAnalyticsTracker(sink: sink)

        tracker.track(AnalyticsEvent(name: "boc_test", parameters: ["email": "a@b.c", "results": "3"]))

        #expect(sink.sent[0].parameters == ["results": "3"], "El saneado del modelo tiene que llegar hasta el envío.")
    }

    @Test("Una pantalla vista lleva su nombre")
    func screenViewCarriesTheName() {
        let sink = RecordingAnalyticsSink()

        FirebaseAnalyticsTracker(sink: sink).trackScreenView("home")

        #expect(sink.sent[0].parameters.values.contains("home"))
    }

    @Test("Un fallo del proveedor de analítica no llega a quien llama")
    func analyticsFailureNeverReachesTheCaller() {
        let tracker = FirebaseAnalyticsTracker(sink: RecordingAnalyticsSink(shouldFail: true))

        // Si el fallo escapara, esta llamada no compilaría sin `try` o rompería la prueba.
        tracker.track(AnalyticsEvent(name: "boc_test"))
        tracker.trackScreenView("home")
    }

    @Test("De un fallo no mortal se registra el tipo, no su mensaje")
    func recordsTheErrorTypeNotItsMessage() {
        struct SecretBearingError: Error { let message = "contiene algo que no debe salir" }
        let sink = RecordingCrashSink()

        FirebaseCrashReporter(sink: sink).recordNonFatal(SecretBearingError())

        #expect(sink.recordedTypes == ["SecretBearingError"])
    }

    @Test("Delega los mensajes de registro")
    func delegatesLogMessages() {
        let sink = RecordingCrashSink()

        FirebaseCrashReporter(sink: sink).log("cycle: 0 new")

        #expect(sink.messages == ["cycle: 0 new"])
    }

    @Test("Un fallo del proveedor de informes no llega a quien llama")
    func crashFailureNeverReachesTheCaller() {
        let reporter = FirebaseCrashReporter(sink: RecordingCrashSink(shouldFail: true))

        reporter.recordNonFatal(SinkFailure())
        reporter.log("da igual")
    }

    @Test("Sin fichero de configuración, la telemetría queda en no operación")
    func withoutConfigurationTelemetryIsNoOp() {
        // Es FR-021 y SC-008: un clon nuevo del repositorio no tiene ese fichero, y la aplicación
        // tiene que arrancar igual. La rama contraria la recorre la aplicación misma.
        let bundle = TelemetryBundle.resolved(configurationURL: nil)

        #expect(bundle.analytics is NoOpAnalyticsTracker)
        #expect(bundle.crashReporter is NoOpCrashReporter)
    }
}
