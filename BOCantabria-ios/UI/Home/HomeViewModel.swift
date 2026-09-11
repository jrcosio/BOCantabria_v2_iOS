//
//  HomeViewModel.swift
//  The screen model of the initial screen.
//

import Foundation

@MainActor
@Observable
final class HomeViewModel {
    /// El identificador de pantalla que viaja a analítica.
    static let screenName = "home"

    private(set) var state = HomeUiState()

    private let analytics: AnalyticsTracker

    init(analytics: AnalyticsTracker) {
        self.analytics = analytics
        // Exactamente una vez por instancia, no una por aparición de la vista: la vista aparece
        // otra vez al volver de segundo plano, y eso no es una visita nueva.
        analytics.trackScreenView(Self.screenName)
        state.sectionChips = Self.chips(for: BocSection.topLevel)
    }

    /// Aplica una selección. **No retorna hasta publicar el primer estado**, para que la prueba
    /// pueda afirmar en la línea siguiente.
    ///
    /// Todavía no hay de dónde leer: la cadena real llega con la historia 1. Lo que ya está puesto
    /// es la forma —los chips y el estado vacío—, que es lo que permite que la pantalla y sus
    /// pruebas no se reescriban cuando llegue.
    func apply(_ selection: HomeSelection) async {
        state.selection = selection
        state.subsectionChips = Self.subsectionChips(for: selection)
        state.content = .empty
        state.header = nil
    }

    func onRetry() async {
        await apply(state.selection)
    }

    private static func chips(for sections: [BocSection]) -> [SectionChip] {
        [SectionChip(code: SectionChip.todayCode, title: String(localized: Strings.Chip.todaysBulletin))]
            + sections.map { SectionChip(code: $0.code, title: $0.shortName) }
    }

    /// La segunda fila: `Toda la sección` más las subsecciones. **Vacía** con el boletín del día y
    /// con una sección que no las tiene (FR-052).
    private static func subsectionChips(for selection: HomeSelection) -> [SectionChip] {
        guard let code = selection.topLevelCode else { return [] }
        let children = BocSection.children(of: code)
        guard !children.isEmpty else { return [] }
        return [SectionChip(code: code, title: String(localized: Strings.Chip.wholeSection))]
            + children.map { SectionChip(code: $0.code, title: $0.shortName) }
    }
}
