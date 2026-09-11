//
//  AppConfig.swift
//  The published parameters that gate the startup.
//
//  Portador de datos con una sola regla: el mensaje de mantenimiento se normaliza a nulo cuando
//  llega vacío o en blanco, **para que nadie tenga que comprobar las dos cosas**.
//

import Foundation

struct AppConfig: Equatable, Sendable {

    let minSupportedVersion: AppVersion
    /// Nulo significa «sin mantenimiento». Nunca una cadena vacía.
    let maintenanceMessage: String?

    /// «Todo permitido», y **la única declaración de este valor en el proyecto**.
    ///
    /// Se usa en los tres casos en que no hay configuración utilizable: el servicio no ha
    /// publicado nada, ha publicado algo ilegible, o no hay servicio en este puesto. Que sea uno
    /// solo es lo que impide que dos respaldos dejen de coincidir.
    static let `default` = AppConfig(minSupportedVersion: .zero, maintenanceMessage: nil)

    init(minSupportedVersion: AppVersion, maintenanceMessage: String?) {
        self.minSupportedVersion = minSupportedVersion

        let trimmed = maintenanceMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.maintenanceMessage = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
