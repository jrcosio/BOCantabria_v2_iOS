//
//  HomeSelection.swift
//  What the initial screen is showing at a given moment.
//
//  Determina el listado, el texto y el **rótulo** de la cabecera, y si hay segunda fila de chips.
//  No es una entrada de pila de navegación: el panel la reemplaza, no la apila.
//

import Foundation

enum HomeSelection: Sendable, Hashable, Codable {
    /// Las publicaciones de la fecha más reciente disponible **entre todas las secciones**.
    case todaysBulletin
    /// Esa sección entera, **sin límite de fecha**. `subsectionCode` afina dentro de ella.
    case section(code: String, subsectionCode: String?)

    /// El código que la pantalla marca en la primera fila de chips.
    var topLevelCode: String? {
        if case .section(let code, _) = self { code } else { nil }
    }

    /// El código que la pantalla marca en la segunda fila, si la hay.
    var subsectionCode: String? {
        if case .section(_, let subsection) = self { subsection } else { nil }
    }

    /// Lo que se guarda para sobrevivir a la muerte del proceso: **el código, nunca un índice**.
    var storedCode: String? {
        switch self {
        case .todaysBulletin: nil
        case .section(let code, let subsection): subsection ?? code
        }
    }

    /// Lo que se restaura. **Se resuelve contra el catálogo**, y un código que ya no existe cae a
    /// «Boletín de hoy» en silencio en vez de dejar la pantalla inservible. Las subsecciones del
    /// BOC pueden cambiar, y ése es el único camino que nadie recorre a mano.
    static func restored(from storedCode: String?) -> HomeSelection {
        guard let storedCode, let section = BocSection.named(storedCode) else {
            return .todaysBulletin
        }
        if let parent = section.parentCode {
            return .section(code: parent, subsectionCode: section.code)
        }
        return .section(code: section.code, subsectionCode: nil)
    }
}
