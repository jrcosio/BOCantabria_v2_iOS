//
//  AnalyticsTracker.swift
//  The usage-analytics contract.
//
//  **Disparar y olvidar: nunca lanza ni bloquea a quien la llama.** Un fallo de telemetría jamás
//  puede tumbar una pantalla.
//

protocol AnalyticsTracker: Sendable {
    func track(_ event: AnalyticsEvent)
    func trackScreenView(_ screenName: String)
}

/// La implementación que no hace nada. Se usa en pruebas y cuando falta el fichero de
/// configuración del proveedor (FR-021).
struct NoOpAnalyticsTracker: AnalyticsTracker {
    func track(_ event: AnalyticsEvent) {}
    func trackScreenView(_ screenName: String) {}
}
