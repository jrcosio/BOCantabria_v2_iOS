//
//  MainViewModelTests.swift
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: armazón")
@MainActor
struct MainViewModelTests {

    private func makeViewModel(stored: String? = nil) -> (MainViewModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "boc-main-\(UUID().uuidString)")!
        if let stored { defaults.set(stored, forKey: UserDefaultsSelectionStore.key) }
        let viewModel = MainViewModel(
            store: UserDefaultsSelectionStore(defaults: defaults),
            sections: BocSection.all
        )
        return (viewModel, defaults)
    }

    @Test("El panel presenta las nueve secciones en orden, con sus hijas")
    func theDrawerShowsTheNineSections() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.state.sections.count == 9)
        #expect(viewModel.state.sections.map(\.id) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
        #expect(viewModel.state.sections.filter(\.isExpandable).map(\.id) == ["2", "4", "7", "8"])
    }

    @Test("Elegir guarda la selección")
    func selectingStoresIt() {
        let (viewModel, defaults) = makeViewModel()
        viewModel.onSelect(.section(code: "2", subsectionCode: "2.2"))
        #expect(viewModel.state.selection == .section(code: "2", subsectionCode: "2.2"))
        #expect(defaults.string(forKey: UserDefaultsSelectionStore.key) == "2.2")
    }

    @Test("Al nacer restaura lo guardado")
    func itRestoresOnBirth() {
        let (viewModel, _) = makeViewModel(stored: "7.3")
        #expect(viewModel.state.selection == .section(code: "7", subsectionCode: "7.3"))
    }

    @Test("Un valor guardado inválido no tumba nada")
    func anInvalidStoredValueIsHarmless() {
        let (viewModel, _) = makeViewModel(stored: "2.9")
        #expect(viewModel.state.selection == .todaysBulletin)
    }

    @Test("Desplegar y contraer una sección")
    func expandingAndCollapsing() {
        let (viewModel, _) = makeViewModel()
        viewModel.onToggleExpanded("4")
        #expect(viewModel.state.expanded == ["4"])
        viewModel.onToggleExpanded("4")
        #expect(viewModel.state.expanded.isEmpty)
    }

    @Test("Cerrar el panel lo deja contraído para la próxima vez")
    func closingTheDrawerCollapsesEverything() {
        let (viewModel, _) = makeViewModel()
        viewModel.onToggleExpanded("2")
        viewModel.onToggleExpanded("7")
        viewModel.onDrawerClosed()
        #expect(viewModel.state.expanded.isEmpty)
    }

    @Test("La pestaña se restaura por nombre, nunca por índice", arguments: [
        (nil, MainTab.home), ("search", .search), ("saved", .saved),
        ("avisos", .home), ("", .home), ("2", .home),
    ])
    func theTabIsRestoredByName(stored: String?, expected: MainTab) {
        // «Preguntar» fue pestaña y hoy es pantalla: un valor guardado que ya no existe tumbaría
        // la aplicación al volver de la muerte del proceso.
        #expect(MainTab.restored(from: stored) == expected)
    }
}
