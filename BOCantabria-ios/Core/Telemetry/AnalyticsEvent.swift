//
//  AnalyticsEvent.swift
//  A usage event: a name and its parameters.
//
//  **El filtro de datos personales vive aquí, en el modelo, y no en la implementación del
//  proveedor.** Es lo que permite probarlo sin tocar ningún SDK y lo que hace que cambiar de
//  proveedor no pueda perderlo por el camino.
//

import Foundation

struct AnalyticsEvent: Equatable, Sendable {
    /// Minúscula inicial, después minúsculas, dígitos o guiones bajos. Entre 1 y 40 caracteres.
    ///
    /// Calculada y no almacenada: `Regex` no es `Sendable`, así que una constante estática no
    /// sería segura entre hilos. El coste de construirla es irrelevante al lado de una llamada de
    /// red, que es lo que hay al otro extremo de cada evento.
    static var namePattern: Regex<Substring> { /^[a-z][a-z0-9_]{0,39}$/ }

    /// Las claves que nunca viajan. Se comparan **exactas y en minúsculas**: ni por subcadena, ni
    /// por el valor. Está ordenada alfabéticamente para que añadir una sea evidente en la
    /// revisión.
    static let sensitiveKeys: Set<String> = [
        "address", "dni", "email", "ip", "latitude", "longitude", "name", "nie", "nif",
        "password", "phone", "surname", "token", "user_id", "username",
    ]

    static let parameterScreenName = "screen_name"

    let name: String
    let parameters: [String: String]

    /// Un nombre que no cumple el patrón es un error de programación, no un caso que tolerar.
    init(name: String, parameters: [String: String] = [:]) {
        precondition(
            name.wholeMatch(of: Self.namePattern) != nil,
            "Nombre de evento inválido: «\(name)». Debe cumplir ^[a-z][a-z0-9_]{0,39}$"
        )
        self.name = name
        self.parameters = parameters
    }

    /// Los parámetros que sí pueden enviarse.
    func sanitizedParameters() -> [String: String] {
        parameters.filter { !Self.sensitiveKeys.contains($0.key.lowercased()) }
    }
}

// MARK: - Los eventos del boletín

extension AnalyticsEvent {
    /// El resultado de una sincronización. **Solo recuentos** (FR-029).
    ///
    /// Ni un título, ni un organismo, ni una dirección: lo que una persona lee es asunto suyo.
    /// Los recuentos dicen si el servicio responde, que es lo único que hace falta saber desde
    /// fuera del dispositivo.
    static func bulletinSync(_ summary: SyncSummary) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "boc_sync",
            parameters: [
                "succeeded": String(summary.succeededFeeds),
                "unchanged": String(summary.unchangedFeeds),
                "failed": String(summary.failedFeeds),
                "inserted": String(summary.inserted),
                "updated": String(summary.updated),
                "rejected": String(summary.rejected),
            ]
        )
    }

    /// Qué sección se está mirando.
    ///
    /// El código **sí** puede viajar: es un enumerado de veintitrés valores de un catálogo
    /// público, no un texto libre. La línea está aquí, y conviene saber dónde: en la feature de
    /// Avisos la misma pregunta llega con **palabras clave**, y entonces la respuesta es la
    /// contraria, porque las palabras de una regla son un interés personal (research.md D-327).
    static func sectionSelected(code: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "home_section_selected", parameters: ["section_code": code])
    }
}

