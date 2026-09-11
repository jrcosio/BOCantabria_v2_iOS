//
//  MainViewModel.swift
//  The shell: which destination, which selection, which sections are expanded.
//

import Foundation

@MainActor
@Observable
final class MainViewModel {
    private(set) var state = MainUiState()

    private let store: HomeSelectionStore
    private let sections: [BocSection]

    init(store: HomeSelectionStore, sections: [BocSection]) {
        self.store = store
        self.sections = sections
        state.sections = sections
            .filter(\.isTopLevel)
            .sorted { $0.order < $1.order }
            .map { SectionRow(section: $0, children: BocSection.children(of: $0.code)) }
        // Se restaura al nacer: si el código guardado ya no existe, «Boletín de hoy» en silencio.
        state.selection = store.load()
    }

    func onSelect(_ selection: HomeSelection) {
        state.selection = selection
        store.save(selection)
    }

    func onToggleExpanded(_ sectionCode: String) {
        if state.expanded.contains(sectionCode) {
            state.expanded.remove(sectionCode)
        } else {
            state.expanded.insert(sectionCode)
        }
    }

    func onSelectTab(_ tab: MainTab) {
        state.tab = tab
    }

    /// Al cerrar el panel se contrae todo: volver a abrirlo lo presenta como lo dibuja el
    /// documento de diseño, no como lo dejó la última visita.
    func onDrawerClosed() {
        state.expanded.removeAll()
    }
}
