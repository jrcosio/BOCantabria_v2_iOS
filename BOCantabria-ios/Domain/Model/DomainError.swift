//
//  DomainError.swift
//  The closed catalogue of what can go wrong, in the language of the problem.
//
//  Es cerrado a propósito: así el `switch` de la pantalla es exhaustivo y el compilador avisa
//  cuando alguien añade un caso. Los errores **no salen de `Data`**: se capturan allí y se
//  traducen aquí.
//

enum DomainError: Error, Equatable, Sendable {
    /// No se pudo traer y no había copia local usable.
    case network
    /// Cualquier fallo inesperado, traducido en la capa de datos.
    case unknown
}
