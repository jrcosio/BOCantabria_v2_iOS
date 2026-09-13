//
//  ShareOfficialDocumentUseCaseTests.swift
//
//  **Es el único sitio donde vive la regla de degradación**, así que es el único sitio donde hay
//  que probarla. Las tres pantallas que comparten preguntan y obedecen.
//

import Testing
@testable import BOCantabria_ios

@Suite("Caso de uso: compartir el documento oficial")
struct ShareOfficialDocumentUseCaseTests {

    @Test("Con la copia en caché se ofrece el documento, con nombre legible")
    func withACachedCopyTheDocumentIsOffered() async {
        let documento = officialDocument(externalKey: "boc:439765", localPath: "/tmp/abc.pdf")
        let useCase = make(document: .success(documento), online: false)

        let destino = await useCase(publication(externalKey: "boc:439765"))

        guard case .document(let compartido) = destino else {
            Issue.record("Debería ofrecer el documento"); return
        }
        #expect(compartido.localPath == "/tmp/abc.pdf")
        // Nunca la huella de sesenta y cuatro caracteres (FR-042).
        #expect(compartido.fileName == "boc-439765.pdf")
    }

    @Test("Sin copia pero con conexión se ofrece el documento: el cierre de exportación lo traerá")
    func withoutACopyButOnlineTheDocumentIsStillOffered() async {
        let useCase = make(document: .failure(.network), online: true)

        let destino = await useCase(publication(externalKey: "boc:1"))

        guard case .document(let compartido) = destino else {
            Issue.record("Debería ofrecer el documento"); return
        }
        #expect(compartido.localPath == nil)
    }

    @Test("Sin copia y sin conexión se ofrece el enlace, con su motivo")
    func withoutACopyAndOfflineTheLinkIsOfferedWithItsReason() async {
        let useCase = make(document: .failure(.network), online: false)
        let publicacion = publication(externalKey: "boc:1")

        let destino = await useCase(publicacion)

        #expect(destino == .link(url: publicacion.documentUrl, reason: .noConnection))
    }

    @Test("Con conexión, un fallo que NO es la falta de red no se disfraza de enlace")
    func aNonNetworkFailureIsNeverDisguisedAsALink() async {
        // FR-040. El disco lleno no es «sin conexión», y decir que lo es le mentiría a la persona
        // sobre qué ha pasado. Es la lección de la 002: un arreglo que convierte un error en otro
        // es peor que no arreglar nada.
        let useCase = make(document: .failure(.storage), online: true)

        let destino = await useCase(publication())

        if case .link = destino { Issue.record("Un fallo de almacenamiento no puede degradar al enlace") }
    }

    private func make(
        document: AppResult<OfficialDocument>,
        online: Bool
    ) -> ShareOfficialDocumentUseCase {
        ShareOfficialDocumentUseCase(
            documents: FakeDocumentRepository(result: document),
            connectivity: FakeConnectivityRepository(online: online)
        )
    }
}
