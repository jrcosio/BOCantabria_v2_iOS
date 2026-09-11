//
//  ContentFlowIntegrationTests.swift
//
//  El recorrido completo con el cableado real y dobles **solo en la frontera externa** (FR-024).
//  Es la prueba que se pondría roja si alguien desenchufa una capa de la siguiente sin romper
//  ninguna prueba unitaria.
//

import Testing
@testable import BOCantabria_ios

@Suite("Integración: el contenido recorre todas las capas")
@MainActor
struct ContentFlowIntegrationTests {

    @Test("El contenido viaja del origen remoto hasta el estado de la pantalla")
    func contentTravelsAllTheWay() async {
        let viewModel = HomeViewModel(
            getContentItems: GetContentItemsUseCase(
                repository: ContentRepositoryImpl(
                    remote: FakeContentRemoteDataSource(.responds([contentItemDTO(id: "9", label: "Desde el origen")])),
                    local: FakeContentLocalDataSource()
                )
            ),
            analytics: NoOpAnalyticsTracker()
        )

        await viewModel.onAppear()

        #expect(viewModel.state == .content([ContentItem(id: "9", title: "Desde el origen")]))
    }

    @Test("Un fallo en la frontera aflora como estado de error")
    func failureAtTheBoundarySurfaces() async {
        let viewModel = HomeViewModel(
            getContentItems: GetContentItemsUseCase(
                repository: ContentRepositoryImpl(
                    remote: FakeContentRemoteDataSource(.fails),
                    local: FakeContentLocalDataSource()
                )
            ),
            analytics: NoOpAnalyticsTracker()
        )

        await viewModel.onAppear()

        #expect(viewModel.state == .error(.network))
    }

    @Test("Un origen que falla y se recupera: el reintento recorre la cadena entera")
    func retryTravelsTheWholeChain() async {
        let viewModel = HomeViewModel(
            getContentItems: GetContentItemsUseCase(
                repository: ContentRepositoryImpl(
                    remote: FakeContentRemoteDataSource(.failsThenResponds([contentItemDTO(id: "3", label: "Al segundo")])),
                    local: FakeContentLocalDataSource()
                )
            ),
            analytics: NoOpAnalyticsTracker()
        )

        await viewModel.onAppear()
        #expect(viewModel.state == .error(.network))

        await viewModel.onRetry()

        #expect(viewModel.state == .content([ContentItem(id: "3", title: "Al segundo")]))
    }
}
