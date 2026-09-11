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
        publications: AppResult<[Publication]> = .success([]),
        header: AppResult<BulletinHeader> = .success(.empty),
        refreshResult: AppResult<SyncSummary> = .success(SyncSummary(succeededFeeds: 19)),
        analytics: AnalyticsTracker = NoOpAnalyticsTracker()
    ) -> HomeViewModel {
        let repository = FakePublicationRepository(
            publications: publications, header: header, refreshResult: refreshResult
        )
        return HomeViewModel(
            observePublications: ObservePublicationsUseCase(repository: repository),
            observeHeader: ObserveBulletinHeaderUseCase(repository: repository),
            refreshPublications: RefreshPublicationsUseCase(repository: repository),
            analytics: analytics
        )
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

    // MARK: - Contenido

    @Test("Con publicaciones guardadas, se pintan")
    func storedPublicationsAreShown() async {
        let items = [publication(externalKey: "boc:1"), publication(externalKey: "boc:2")]
        let viewModel = makeViewModel(publications: .success(items))
        await viewModel.apply(.todaysBulletin)
        #expect(viewModel.state.content == .publications(items))
    }

    @Test("Una lista vacía ANTES de la primera sincronización son marcadores, no «no hay nada»")
    func emptyBeforeTheFirstSyncMeansSkeleton() async {
        // «No se sabe todavía» y «no hay nada» son cosas distintas, y confundirlas enseñaría un
        // estado vacío en la primera ejecución mientras las fuentes todavía están respondiendo.
        let viewModel = makeViewModel(publications: .success([]))
        await viewModel.apply(.todaysBulletin)
        #expect(viewModel.state.content == .skeleton)
    }

    @Test("Una lista vacía DESPUÉS de sincronizar sí es el estado vacío")
    func emptyAfterSyncingIsTheEmptyState() async {
        let viewModel = makeViewModel(publications: .success([]))
        await viewModel.apply(.todaysBulletin)
        await viewModel.onAppear()
        #expect(viewModel.state.content == .empty)
    }

    @Test("La cabecera llega de lo guardado, con su fecha y su recuento")
    func theHeaderComesFromWhatIsStored() async {
        let header = BulletinHeader(
            title: "Boletín de hoy", date: BocDate(iso: "2026-08-27"), count: 48,
            dateMeaning: .edition
        )
        let viewModel = makeViewModel(header: .success(header))
        await viewModel.apply(.todaysBulletin)
        // La cabecera se observa por su cuenta; se le da margen para publicar.
        for _ in 0..<50 where viewModel.state.header == nil { await Task.yield() }
        #expect(viewModel.state.header == header)
    }

    // MARK: - Sincronización

    @Test("Si todo falla y no hay nada guardado, error con reintento (FR-027)")
    func aTotalFailureWithoutContentIsAnError() async {
        let viewModel = makeViewModel(publications: .success([]), refreshResult: .failure(.network))
        await viewModel.apply(.todaysBulletin)
        await viewModel.onAppear()
        #expect(viewModel.state.content == .error(.network))
        #expect(viewModel.state.isOffline)
    }

    @Test("Si todo falla PERO hay contenido, se ve el contenido y se enciende el aviso")
    func aTotalFailureWithContentKeepsTheContent() async {
        // No es un error: es un resultado correcto con una bandera. Mezclar las dos cosas en el
        // enumerado obligaría a la pantalla a desenredarlas otra vez.
        let items = [publication()]
        let viewModel = makeViewModel(
            publications: .success(items),
            refreshResult: .success(SyncSummary(failedFeeds: 19))
        )
        await viewModel.apply(.todaysBulletin)
        await viewModel.onAppear()
        #expect(viewModel.state.content == .publications(items))
        #expect(viewModel.state.isOffline)
    }

    @Test("Una sincronización sin novedades deja el contenido intacto y no muestra error")
    func aQuietSyncChangesNothing() async {
        let items = [publication()]
        let viewModel = makeViewModel(publications: .success(items))
        await viewModel.apply(.todaysBulletin)
        await viewModel.onRefresh()
        #expect(viewModel.state.content == .publications(items))
        #expect(!viewModel.state.isOffline)
    }

    @Test("El resumen de la sincronización viaja a analítica con solo recuentos (FR-029)")
    func theSyncEventCarriesOnlyCounts() async {
        // Ni un título, ni un organismo, ni una dirección: lo que una persona lee es asunto suyo.
        let analytics = RecordingAnalyticsTracker()
        let viewModel = makeViewModel(
            refreshResult: .success(SyncSummary(succeededFeeds: 19, inserted: 40)),
            analytics: analytics
        )
        await viewModel.onAppear()

        let sync = analytics.events.first { $0.name == "boc_sync" }
        #expect(sync != nil)
        let values = sync?.parameters.values.joined() ?? ""
        let onlyDigits = values.allSatisfy { $0.isASCII && $0.isNumber }
        #expect(onlyDigits, "Un parámetro con texto libre sería un dato de la persona")
        #expect(sync?.parameters["inserted"] == "40")
    }

    @Test("La sección elegida sí viaja: es un enumerado del catálogo público")
    func theSelectedSectionCodeMayTravel() async {
        let analytics = RecordingAnalyticsTracker()
        let viewModel = makeViewModel(analytics: analytics)
        await viewModel.apply(.section(code: "2", subsectionCode: "2.2"))

        let selected = analytics.events.first { $0.name == "home_section_selected" }
        #expect(selected?.parameters["section_code"] == "2.2")
    }
}
