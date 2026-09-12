//
//  OpenOfficialDocumentUseCaseTests.swift
//

import Testing
@testable import BOCantabria_ios

@Suite("Caso de uso: abrir el documento oficial")
struct OpenOfficialDocumentUseCaseTests {

    @Test("Pide la copia local de esa publicación")
    func itAsksForThatPublicationsLocalCopy() async {
        let documento = officialDocument()
        let repository = FakeDocumentRepository(result: .success(documento))
        let useCase = OpenOfficialDocumentUseCase(repository: repository)

        let resultado = await useCase(publication(externalKey: "boc:439765"))

        #expect(resultado == .success(documento))
        #expect(repository.ensuredKeys == ["boc:439765"])
    }

    @Test("El fallo llega como fallo, sin traducirse por el camino")
    func aFailureArrivesAsAFailure() async {
        let useCase = OpenOfficialDocumentUseCase(
            repository: FakeDocumentRepository(result: .failure(.storage))
        )

        #expect(await useCase(publication()) == .failure(.storage))
    }
}
