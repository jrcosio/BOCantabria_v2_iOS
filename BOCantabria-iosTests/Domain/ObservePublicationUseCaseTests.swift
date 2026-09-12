//
//  ObservePublicationUseCaseTests.swift
//
//  Lo que hace verificable FR-003 y FR-004: la pantalla **observa** la fila, así que una
//  sincronización posterior la corrige sola y una publicación retirada llega como `nil`.
//

import Testing
@testable import BOCantabria_ios

@Suite("Caso de uso: observar una publicación")
struct ObservePublicationUseCaseTests {

    @Test("Pide al repositorio exactamente la clave que se le da")
    func itAsksForTheKeyItWasGiven() async {
        let repository = FakePublicationRepository(single: [.success(publication(externalKey: "boc:1"))])
        let useCase = ObservePublicationUseCase(repository: repository)

        for await _ in useCase("boc:1") {}

        #expect(repository.observedPublicationKeys == ["boc:1"])
    }

    @Test("Una publicación retirada llega como nulo dentro de un éxito, no como fallo")
    func aRetiredPublicationArrivesAsNilInsideASuccess() async {
        // Es la distinción que FR-004 necesita: «ya no está» es un desenlace previsto, y la
        // pantalla lo explica y ofrece volver. Un fallo pintaría «algo ha ido mal».
        let useCase = ObservePublicationUseCase(
            repository: FakePublicationRepository(single: [.success(nil)])
        )

        var recibidos: [AppResult<Publication?>] = []
        for await value in useCase("boc:1") { recibidos.append(value) }

        #expect(recibidos.count == 1)
        #expect(recibidos.first == .success(nil))
    }

    @Test("Una corrección posterior llega sin salir y volver a entrar")
    func aLaterCorrectionArrivesWithoutLeavingTheScreen() async {
        // FR-003. La fuente emite dos veces: lo guardado cambió.
        let antes = publication(externalKey: "boc:1", title: "AYUNTAMIENTO: título truncado")
        let despues = publication(externalKey: "boc:1", title: "AYUNTAMIENTO: título completo y corregido")
        let useCase = ObservePublicationUseCase(
            repository: FakePublicationRepository(single: [.success(antes), .success(despues)])
        )

        var titulos: [String] = []
        for await value in useCase("boc:1") {
            if case .success(let publicacion) = value, let publicacion { titulos.append(publicacion.title) }
        }

        #expect(titulos == [antes.title, despues.title])
    }
}
