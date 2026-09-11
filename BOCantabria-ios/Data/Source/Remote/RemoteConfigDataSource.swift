//
//  RemoteConfigDataSource.swift
//  What the remote configuration service hands over, with its own names.
//
//  `RemoteConfigValues` **no cruza a `Domain`**: lo traduce `AppConfigRepositoryImpl`. La
//  traducción es real, no una copia: el servicio devuelve cadena vacía para lo que no está
//  publicado y el dominio quiere un valor por defecto y un opcional.
//

protocol RemoteConfigDataSource: Sendable {
    /// **Puede lanzar.** El repositorio es quien captura y traduce.
    func fetchValues() async throws -> RemoteConfigValues
}

struct RemoteConfigValues: Equatable, Sendable {
    /// Cadena vacía cuando no hay nada publicado.
    let minSupportedVersion: String
    /// Cadena vacía cuando no hay nada publicado.
    let maintenanceMessage: String

    static let empty = RemoteConfigValues(minSupportedVersion: "", maintenanceMessage: "")
}

/// Las claves publicadas en la consola del proveedor.
enum RemoteConfigKey {
    /// La versión mínima soportada **de esta plataforma**, como texto: «1.0.0».
    ///
    /// Es un parámetro propio y no el entero `min_supported_version_code`, que habla del contador
    /// de compilación de la otra plataforma y sigue siendo suyo. Un solo nombre con dos
    /// significados, repartidos por una condición invisible desde el código, es exactamente lo que
    /// esta decisión evita (research.md D-207).
    static let minSupportedVersion = "min_supported_version_ios"
    /// El aviso de mantenimiento. Compartido con la otra plataforma, porque dice lo mismo.
    static let maintenanceMessage = "maintenance_message"
}
