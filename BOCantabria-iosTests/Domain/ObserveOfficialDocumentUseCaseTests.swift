//
//  ObserveOfficialDocumentUseCaseTests.swift
//

import Testing
@testable import BOCantabria_ios

@Suite("Caso de uso: observar el documento oficial")
struct ObserveOfficialDocumentUseCaseTests {

    @Test("Entrega los estados tal cual llegan, sin envolverlos en un resultado")
    func itDeliversStatusesUnwrapped() async {
        // `DocumentStatus` ya lleva su propio caso de fallo. Envolverlo en `AppResult` daría dos
        // formas de decir lo mismo y dos sitios donde mirar.
        let documento = officialDocument()
        let useCase = ObserveOfficialDocumentUseCase(
            repository: FakeDocumentRepository(statuses: [
                "boc:1": [.absent, .downloading(bytesRead: 0, totalBytes: nil), .available(documento)],
            ])
        )

        var estados: [DocumentStatus] = []
        for await estado in useCase("boc:1") { estados.append(estado) }

        #expect(estados == [.absent, .downloading(bytesRead: 0, totalBytes: nil), .available(documento)])
        #expect(estados.last?.isTerminal == true)
    }

    @Test("Una clave que nadie ha pedido está ausente")
    func anUnrequestedKeyIsAbsent() async {
        let useCase = ObserveOfficialDocumentUseCase(repository: FakeDocumentRepository())

        var estados: [DocumentStatus] = []
        for await estado in useCase("boc:desconocida") { estados.append(estado) }

        #expect(estados == [.absent])
    }
}
