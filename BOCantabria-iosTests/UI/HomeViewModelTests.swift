//
//  HomeViewModelTests.swift
//
//  Los seis comportamientos que el contrato de presentación promete.
//

import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: Inicio")
@MainActor
struct HomeViewModelTests {

    private func makeViewModel(
        _ results: [AppResult<[ContentItem]>],
        analytics: AnalyticsTracker = NoOpAnalyticsTracker()
    ) -> HomeViewModel {
        HomeViewModel(
            getContentItems: GetContentItemsUseCase(repository: SequencedContentRepository(results)),
            analytics: analytics
        )
    }

    @Test("Arranca en carga y llega a contenido")
    func startsLoadingAndReachesContent() async {
        let viewModel = makeViewModel([.success([contentItem()])])

        #expect(viewModel.state == .loading, "El estado inicial es siempre carga.")
        await viewModel.onAppear()

        #expect(viewModel.state == .content([contentItem()]))
    }

    @Test("Un resultado vacío es «sin contenido», no un error")
    func emptyIsEmptyNotError() async {
        let viewModel = makeViewModel([.success([])])

        await viewModel.onAppear()

        #expect(viewModel.state == .empty)
    }

    @Test("Un fallo llega a error con su error de dominio")
    func failureReachesError() async {
        let viewModel = makeViewModel([.failure(.network)])

        await viewModel.onAppear()

        #expect(viewModel.state == .error(.network))
    }

    @Test("Reintentar desde error llega a contenido")
    func retryFromErrorRecovers() async {
        let viewModel = makeViewModel([.failure(.network), .success([contentItem()])])

        await viewModel.onAppear()
        #expect(viewModel.state == .error(.network))

        await viewModel.onRetry()

        #expect(viewModel.state == .content([contentItem()]))
    }

    @Test("La carga inicial se dispara una sola vez aunque la vista vuelva a aparecer")
    func loadsOnlyOnce() async {
        let repository = SequencedContentRepository([.success([contentItem()])])
        let viewModel = HomeViewModel(
            getContentItems: GetContentItemsUseCase(repository: repository),
            analytics: NoOpAnalyticsTracker()
        )

        await viewModel.onAppear()
        await viewModel.onAppear()

        let calls = await repository.callCount
        #expect(calls == 1, "Volver a aparecer no puede recargar: el estado sobrevive (FR-005).")
    }

    @Test("Registra la pantalla vista exactamente una vez por instancia")
    func recordsScreenViewOnce() async {
        let analytics = RecordingAnalyticsTracker()
        let viewModel = makeViewModel([.success([contentItem()])], analytics: analytics)

        await viewModel.onAppear()
        await viewModel.onAppear()
        await viewModel.onRetry()

        #expect(analytics.screenViews == ["home"])
    }
}
