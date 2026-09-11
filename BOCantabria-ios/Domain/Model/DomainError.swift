//
//  DomainError.swift
//  The closed catalogue of what can go wrong, in the language of the problem.
//
//  Es cerrado a propósito: así el `switch` de la pantalla es exhaustivo y el compilador avisa
//  cuando alguien añade un caso. Los errores **no salen de `Data`**: se capturan allí y se
//  traducen aquí.
//
//  **Lo que NO entra**: «sin conexión pero con contenido guardado». Eso no es un error, es un
//  resultado correcto con una bandera en el estado de pantalla. Mezclar «si hay contenido» con
//  «si hay conexión» en un solo enumerado obliga a la pantalla a desenredarlos otra vez (D-331).
//

enum DomainError: Error, Equatable, Sendable {
    /// No se pudo traer y no había copia local usable.
    case network
    /// La base local no se pudo abrir, migrar o escribir. Es el desenlace que la portada
    /// convierte en un mensaje con reintento en vez de en un cierre inesperado (D-305).
    case storage
    /// La operación se canceló. Se distingue para **no contarla como un fallo**: quien la canceló
    /// ya no está mirando.
    case cancelled
    /// Cualquier fallo inesperado, traducido en la capa de datos.
    case unknown
}
