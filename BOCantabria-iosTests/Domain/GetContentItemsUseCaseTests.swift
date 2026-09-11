//
//  GetContentItemsUseCaseTests.swift
//
//  El caso de uso no añade lógica: existe para que la presentación no conozca los repositorios.
//  Lo que se prueba, por tanto, es que **no altera nada por el camino** — y muy en particular que
//  un éxito vacío sigue siendo un éxito.
//

import Testing
@testable import BOCantabria_ios

@Suite("Caso de uso: obtener el contenido")
struct GetContentItemsUseCaseTests {

    @Test("Propaga el éxito sin alterarlo")
    func propagatesSuccess() async {
        let items = [contentItem(id: "1"), contentItem(id: "2")]
        let useCase = GetContentItemsUseCase(repository: FakeContentRepository(result: .success(items)))

        let result = await useCase()

        #expect(result == .success(items))
    }

    @Test("Un éxito vacío es un éxito, no un fallo")
    func propagatesEmptySuccessAsSuccess() async {
        let useCase = GetContentItemsUseCase(repository: FakeContentRepository(result: .success([])))

        let result = await useCase()

        #expect(result == .success([]))
    }

    @Test("Propaga el fallo sin alterarlo")
    func propagatesFailure() async {
        let useCase = GetContentItemsUseCase(repository: FakeContentRepository(result: .failure(.network)))

        let result = await useCase()

        #expect(result == .failure(.network))
    }
}
