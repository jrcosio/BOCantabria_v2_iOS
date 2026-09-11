//
//  TelemetryBundle.swift
//  Decides which telemetry the application runs with.
//
//  **Es el único sitio que toma esa decisión, y vive fuera del contenedor a propósito.** Si la
//  tomara el contenedor, el contenedor tendría que importar el SDK del proveedor y la regla de
//  arquitectura 6 se pondría roja — con razón: el grafo no es sitio para conocer a nadie de fuera.
//

import FirebaseCore
import Foundation

struct TelemetryBundle: Sendable {
    let analytics: AnalyticsTracker
    let crashReporter: CrashReporter

    /// La que no hace nada. Es la que se usa en pruebas y cuando falta la configuración.
    static let noOp = TelemetryBundle(
        analytics: NoOpAnalyticsTracker(),
        crashReporter: NoOpCrashReporter()
    )

    /// Decide con qué telemetría arranca la aplicación.
    ///
    /// **Sin el fichero de configuración no se arranca el proveedor y se devuelve la no
    /// operación** (FR-021). No es una cortesía: `FirebaseApp.configure()` **lanza** si el fichero
    /// no está, y ese fichero no se versiona —en iOS la clave solo puede restringirse por
    /// identificador de paquete, sin prueba criptográfica, así que el razonamiento que sí vale en
    /// Android no se traslada—. Un clon nuevo del repositorio no lo tiene, y la aplicación tiene
    /// que arrancar igual (SC-008).
    static func resolved(
        configurationURL: URL? = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist")
    ) -> TelemetryBundle {
        guard configurationURL != nil else { return .noOp }
        FirebaseApp.configure()
        return TelemetryBundle(
            analytics: FirebaseAnalyticsTracker(sink: FirebaseAnalyticsSink()),
            crashReporter: FirebaseCrashReporter(sink: FirebaseCrashSink())
        )
    }
}
