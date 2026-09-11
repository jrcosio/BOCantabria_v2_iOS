//
//  FirebaseCrashReporter.swift
//  The crash-reporting wrapper over the provider.
//
//  **De un fallo no mortal se registra el tipo del error, nunca su mensaje.** Un mensaje puede
//  llevar dentro lo que alguien escribió, una ruta con datos o el contenido de un documento; el
//  tipo no puede llevar nada.
//

import FirebaseCrashlytics
import Foundation
import OSLog

struct FirebaseCrashReporter: CrashReporter {
    private let sink: CrashSink
    private let logger = Logger(subsystem: "com.jrblanco.BOCantabria", category: "telemetry")

    init(sink: CrashSink) {
        self.sink = sink
    }

    func recordNonFatal(_ error: Error) {
        // El eco al registro **solo en depuración**: en producción no aporta y todo lo que se
        // escribe es una oportunidad de escribir de más.
        #if DEBUG
        logger.warning("non-fatal: \(String(describing: type(of: error)), privacy: .public)")
        #endif
        try? sink.record(error)
    }

    func log(_ message: String) {
        #if DEBUG
        logger.warning("\(message, privacy: .public)")
        #endif
        try? sink.log(message)
    }
}

/// El único sitio del proyecto que llama al SDK de informes de fallo.
struct FirebaseCrashSink: CrashSink {
    func record(_ error: Error) throws {
        Crashlytics.crashlytics().record(error: error)
    }

    func log(_ message: String) throws {
        Crashlytics.crashlytics().log(message)
    }
}
