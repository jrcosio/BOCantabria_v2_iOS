//
//  AppConfigRepository.swift
//  The contract for reading the published startup parameters.
//

protocol AppConfigRepository: Sendable {
    /// **Nunca lanza**: los fallos viajan dentro del resultado.
    ///
    /// Cuando no hay configuración utilizable devuelve `.success(AppConfig.default)`, no un
    /// fallo: «no hay nada publicado» es un estado normal del servicio, no una avería.
    func loadConfig() async -> AppResult<AppConfig>
}
