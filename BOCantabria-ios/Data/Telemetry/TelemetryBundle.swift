//
//  TelemetryBundle.swift
//  Decides which telemetry the application runs with.
//
//  **Es el único sitio que toma esa decisión, y vive fuera del contenedor a propósito.** Si la
//  tomara el contenedor, el contenedor tendría que importar el SDK del proveedor y la regla de
//  arquitectura 6 se pondría roja — con razón: el grafo no es sitio para conocer a nadie de fuera.
//

struct TelemetryBundle: Sendable {
    let analytics: AnalyticsTracker
    let crashReporter: CrashReporter

    /// La que no hace nada. Es la que se usa en pruebas y cuando falta la configuración.
    static let noOp = TelemetryBundle(
        analytics: NoOpAnalyticsTracker(),
        crashReporter: NoOpCrashReporter()
    )
}
