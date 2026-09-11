//
//  FirebaseAnalyticsTracker.swift
//  The analytics wrapper over the provider.
//
//  **Envía siempre los parámetros saneados, nunca el mapa crudo.** El saneado vive en
//  `AnalyticsEvent`, en el modelo, y aquí solo se usa: si un día se cambia de proveedor, el filtro
//  no se va con él.
//

import FirebaseAnalytics
import Foundation

struct FirebaseAnalyticsTracker: AnalyticsTracker {
    private let sink: AnalyticsSink

    init(sink: AnalyticsSink) {
        self.sink = sink
    }

    func track(_ event: AnalyticsEvent) {
        send(event.name, event.sanitizedParameters())
    }

    func trackScreenView(_ screenName: String) {
        send(
            AnalyticsEventScreenView,
            [AnalyticsParameterScreenName: screenName]
        )
    }

    /// **Disparar y olvidar.** Un fallo del cliente nunca llega a quien llama: una pantalla no se
    /// cae porque la analítica tenga un mal día.
    private func send(_ name: String, _ parameters: [String: String]) {
        try? sink.logEvent(name, parameters: parameters)
    }
}

/// El único sitio del proyecto que llama al SDK de analítica.
struct FirebaseAnalyticsSink: AnalyticsSink {
    func logEvent(_ name: String, parameters: [String: String]) throws {
        Analytics.logEvent(name, parameters: parameters)
    }
}
