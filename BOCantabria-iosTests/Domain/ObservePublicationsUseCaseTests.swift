//
//  ObservePublicationsUseCaseTests.swift
//
//  El caso de uso no añade lógica, y eso es exactamente lo que hay que proteger: el día que
//  alguien meta aquí un filtro o un orden, la pantalla dejará de ver lo mismo que la base.
//

import Testing
@testable import BOCantabria_ios

@Suite("Observar publicaciones")
struct ObservePublicationsUseCaseTests {

    @Test("Pasa la selección al repositorio y devuelve lo que emite, sin tocarlo")
    func forwardsWithoutAltering() async {
        let expected = [publication(externalKey: "boc:1"), publication(externalKey: "boc:2")]
        let repository = FakePublicationRepository(publications: .success(expected))
        let observe = ObservePublicationsUseCase(repository: repository)

        var received: [Publication] = []
        for await result in observe(.section(code: "2", subsectionCode: "2.2")) {
            if case .success(let items) = result { received = items }
        }
        #expect(received == expected)

        let selections = repository.observedSelections
        #expect(selections == [.section(code: "2", subsectionCode: "2.2")])
    }

    @Test("Una lista vacía es un éxito, no un fallo")
    func emptyIsSuccess() async {
        // «Vacío» y «error» se distinguen en la capa de presentación, y esa distinción empieza
        // aquí: la sección 8.1 responde bien y no trae nada.
        let repository = FakePublicationRepository(publications: .success([]))
        let observe = ObservePublicationsUseCase(repository: repository)
        var results: [AppResult<[Publication]>] = []
        for await result in observe(.todaysBulletin) { results.append(result) }
        #expect(results == [.success([])])
    }

    @Test("El fallo viaja como valor, no como excepción")
    func failureTravelsAsAValue() async {
        let repository = FakePublicationRepository(publications: .failure(.network))
        let observe = ObservePublicationsUseCase(repository: repository)
        var results: [AppResult<[Publication]>] = []
        for await result in observe(.todaysBulletin) { results.append(result) }
        #expect(results == [.failure(.network)])
    }
}
