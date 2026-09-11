//
//  MainUiState.swift
//  What the shell knows: the selection, the section tree and what is expanded.
//
//  **El abierto/cerrado del panel no está aquí.** Es `@State` de la vista, porque es efímero y no
//  sobrevive a nada. Se escribe porque la regla 5 solo mira los tipos que se llaman `*ViewModel` y
//  alguien propondrá un modelo de pantalla para el panel.
//

import Foundation

struct MainUiState: Equatable {
    var selection: HomeSelection = .todaysBulletin
    var tab: MainTab = .home
    var sections: [SectionRow] = []
    /// Qué secciones están desplegadas en el panel. **No sobrevive** a cerrarlo: volver a abrirlo
    /// lo presenta contraído, que es lo que el documento de diseño dibuja.
    var expanded: Set<String> = []
}

struct SectionRow: Equatable, Identifiable {
    let section: BocSection
    let children: [BocSection]

    var id: String { section.code }
    var isExpandable: Bool { !children.isEmpty }
}

/// Los tres destinos. **Se restaura por nombre**, nunca por índice: un valor guardado que ya no
/// exista tumbaría la aplicación al volver de la muerte del proceso.
enum MainTab: String, CaseIterable, Equatable, Sendable {
    case home
    case search
    case saved

    static func restored(from raw: String?) -> MainTab {
        guard let raw, let tab = MainTab(rawValue: raw) else { return .home }
        return tab
    }
}
