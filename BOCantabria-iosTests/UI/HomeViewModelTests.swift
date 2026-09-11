//
//  HomeViewModelTests.swift
//
//  Lo que el contrato de presentación promete. Mientras la cadena real no exista, lo que ya se
//  puede afirmar es la **forma**: los chips, la segunda fila y el estado vacío, que es donde vive
//  la mitad de los requisitos de la pantalla.
//

import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: Inicio")
@MainActor
struct HomeViewModelTests {

    private func makeViewModel(
        analytics: AnalyticsTracker = NoOpAnalyticsTracker()
    ) -> HomeViewModel {
        HomeViewModel(analytics: analytics)
    }

    @Test("Arranca con marcadores, no con una pantalla en blanco")
    func startsWithSkeletons() {
        #expect(makeViewModel().state.content == .skeleton)
    }

    @Test("La primera fila es «Boletín de hoy» más las nueve secciones")
    func theFirstRowIsTodayPlusNineSections() {
        let chips = makeViewModel().state.sectionChips
        #expect(chips.count == 10)
        #expect(chips.first?.code == SectionChip.todayCode)
        #expect(chips.first?.title == "Boletín de hoy")
        #expect(chips.dropFirst().map(\.code) == BocSection.topLevel.map(\.code))
    }

    @Test("El primer chip no dice «Todo», porque no muestra todo")
    func theFirstChipNamesTodaysBulletin() {
        // Muestra la última edición publicada, no el archivo entero. El comportamiento era
        // correcto y la palabra era la equivocada (FR-046).
        #expect(makeViewModel().state.sectionChips.first?.title != "Todo")
    }

    @Test("Con el boletín del día no hay segunda fila")
    func noSubsectionRowForTodaysBulletin() async {
        let viewModel = makeViewModel()
        await viewModel.apply(.todaysBulletin)
        #expect(viewModel.state.subsectionChips.isEmpty)
        #expect(!viewModel.state.hasSubsectionRow)
    }

    @Test("Con una sección sin subsecciones tampoco", arguments: ["1", "3", "5", "6", "9"])
    func noSubsectionRowForFlatSections(code: String) async {
        let viewModel = makeViewModel()
        await viewModel.apply(.section(code: code, subsectionCode: nil))
        #expect(viewModel.state.subsectionChips.isEmpty)
    }

    @Test("Con una sección que las tiene, la fila aparece con «Toda la sección» delante")
    func theSubsectionRowLeadsWithTheWholeSection() async {
        let viewModel = makeViewModel()
        await viewModel.apply(.section(code: "2", subsectionCode: nil))

        let chips = viewModel.state.subsectionChips
        #expect(chips.count == 4)   // «Toda la sección» + las tres de Personal
        #expect(chips.first?.title == "Toda la sección")
        #expect(chips.dropFirst().map(\.code) == ["2.1", "2.2", "2.3"])
    }

    @Test("Pasar a una sección sin subsecciones RETIRA la segunda fila")
    func movingToAFlatSectionRemovesTheRow() async {
        // Es el caso que deja hueco si nadie lo prueba: se llega desde una sección con fila y la
        // siguiente no la tiene.
        let viewModel = makeViewModel()
        await viewModel.apply(.section(code: "7", subsectionCode: "7.1"))
        #expect(viewModel.state.hasSubsectionRow)

        await viewModel.apply(.section(code: "1", subsectionCode: nil))
        #expect(!viewModel.state.hasSubsectionRow)
    }

    @Test("La selección queda publicada, con su sección padre marcada")
    func theSelectionIsPublished() async {
        let viewModel = makeViewModel()
        await viewModel.apply(.section(code: "4", subsectionCode: "4.3"))
        #expect(viewModel.state.selection == .section(code: "4", subsectionCode: "4.3"))
        // Estar en 4.3 es estar en 4: si la fila de arriba se apagara, la segunda parecería no
        // depender de nada (FR-051).
        #expect(viewModel.state.selection.topLevelCode == "4")
    }

    @Test("La visita a la pantalla se registra una sola vez por instancia")
    func theScreenViewIsTrackedOnce() async {
        let analytics = RecordingAnalyticsTracker()
        let viewModel = makeViewModel(analytics: analytics)
        await viewModel.apply(.todaysBulletin)
        await viewModel.apply(.section(code: "1", subsectionCode: nil))
        #expect(analytics.screenViews == [HomeViewModel.screenName])
    }
}
