//
//  RefreshPublicationsUseCaseTests.swift
//
//  Hay dos entradas y una sola política, y la diferencia entre ellas es un booleano que decide si
//  se respeta la caducidad de la caché. Confundirlo haría que el arranque saliera a la red siempre
//  o que deslizar no sirviera de nada.
//

import Testing
@testable import BOCantabria_ios

@Suite("Actualizar el boletín")
struct RefreshPublicationsUseCaseTests {

    @Test("El arranque respeta la caducidad; deslizar siempre sale a la red")
    func theTwoEntryPointsDifferOnlyInForce() async {
        let repository = FakePublicationRepository()
        let refresh = RefreshPublicationsUseCase(repository: repository)

        _ = await refresh(force: false)   // arranque
        _ = await refresh(force: true)    // gesto de deslizar

        let calls = repository.refreshCalls
        #expect(calls == [false, true])
    }

    @Test("Devuelve el resumen, no las publicaciones")
    func returnsASummary() async {
        // Es lo que garantiza que no exista ningún camino por el que un dato recién traído de la
        // red llegue a una vista sin pasar por lo guardado.
        let summary = SyncSummary(succeededFeeds: 18, failedFeeds: 1, inserted: 40)
        let repository = FakePublicationRepository(refreshResult: .success(summary))
        let refresh = RefreshPublicationsUseCase(repository: repository)
        #expect(await refresh(force: true) == .success(summary))
    }

    @Test("Un fallo total llega como fallo de red")
    func aTotalFailureIsANetworkFailure() async {
        let repository = FakePublicationRepository(refreshResult: .failure(.network))
        let refresh = RefreshPublicationsUseCase(repository: repository)
        #expect(await refresh(force: true) == .failure(.network))
    }
}
