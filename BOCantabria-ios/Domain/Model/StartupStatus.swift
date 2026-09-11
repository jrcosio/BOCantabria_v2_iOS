//
//  StartupStatus.swift
//  How the startup preparation concluded, when it did not fail.
//
//  Los fallos **no** son casos de este enumerado: viajan como `AppResult.failure(DomainError)`.
//  El arranque no necesita un vocabulario de errores propio.
//

enum StartupStatus: Equatable, Sendable {
    /// Se puede continuar al contenido principal.
    case ready
    /// La versión instalada es inferior a la mínima soportada.
    case updateRequired
    /// El servicio ha publicado un mensaje de mantenimiento, que es el que se pinta.
    case maintenance(String)
}
