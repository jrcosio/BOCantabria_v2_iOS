//
//  Route.swift
//  The typed destinations of the application.
//
//  Un enumerado y no una cadena, a propósito: una ruta mal escrita tiene que ser un error de
//  compilación y no un fallo en el móvil (research.md D-107). Hoy solo hay un destino; el
//  mecanismo queda montado para que añadir el siguiente no obligue a rediseñarlo (FR-006).
//

enum Route: Hashable {
    case home
}
