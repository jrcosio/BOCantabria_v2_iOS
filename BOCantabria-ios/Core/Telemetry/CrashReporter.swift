//
//  CrashReporter.swift
//  The crash-reporting contract.
//
//  **Disparar y olvidar: nunca lanza ni bloquea a quien la llama.**
//
//  De un fallo no mortal se registra el **tipo** del error, nunca su mensaje: un mensaje puede
//  llevar dentro lo que alguien escribió, una ruta con datos o el contenido de un documento.
//

protocol CrashReporter: Sendable {
    func recordNonFatal(_ error: Error)
    func log(_ message: String)
}

/// La implementación que no hace nada. Ver `NoOpAnalyticsTracker`.
struct NoOpCrashReporter: CrashReporter {
    func recordNonFatal(_ error: Error) {}
    func log(_ message: String) {}
}
