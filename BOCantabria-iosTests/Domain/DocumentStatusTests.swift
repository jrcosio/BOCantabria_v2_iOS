//
//  DocumentStatusTests.swift
//
//  `isTerminal` existe para que la prueba de FR-029 pueda afirmar **una sola cosa** sobre los siete
//  caminos de error. Si esta derivada se equivoca, aquella prueba pasa en verde sin comprobar nada.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Estado del documento")
struct DocumentStatusTests {

    @Test("«Obteniéndose» es el único estado no terminal")
    func downloadingIsTheOnlyNonTerminalState() {
        #expect(!DocumentStatus.downloading(bytesRead: 0, totalBytes: nil).isTerminal)
        #expect(!DocumentStatus.downloading(bytesRead: 500, totalBytes: 1000).isTerminal)

        #expect(DocumentStatus.absent.isTerminal)
        #expect(DocumentStatus.failed(.network).isTerminal)
        #expect(DocumentStatus.available(Self.documento).isTerminal)
    }

    @Test("El total puede faltar, y eso es información: la barra es indeterminada")
    func aMissingTotalIsInformationAndNotAnOversight() {
        // El servicio puede no declarar la longitud. Fingir un total con un valor negativo
        // pintaría una barra llena, que es peor que una indeterminada.
        let sinTotal = DocumentStatus.downloading(bytesRead: 42, totalBytes: nil)
        let conTotal = DocumentStatus.downloading(bytesRead: 42, totalBytes: 1000)
        #expect(sinTotal != conTotal)
    }

    @Test("Solo «disponible» lleva documento")
    func onlyAvailableCarriesADocument() {
        #expect(DocumentStatus.available(Self.documento).document == Self.documento)
        #expect(DocumentStatus.absent.document == nil)
        #expect(DocumentStatus.failed(.storage).document == nil)
        #expect(DocumentStatus.downloading(bytesRead: 1, totalBytes: nil).document == nil)
    }

    private static let documento = OfficialDocument(
        externalKey: "boc:439765", localPath: "/tmp/x.pdf", byteCount: 609,
        checksum: String(repeating: "a", count: 64), lastUsedAt: .distantPast
    )
}
