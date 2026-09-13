//
//  SharedDocumentTests.swift
//
//  Lo que se comparte tiene que llegar con un nombre que la otra persona pueda reconocer. El
//  fichero en disco se llama con una huella de sesenta y cuatro caracteres.
//

import Testing
@testable import BOCantabria_ios

@Suite("Documento compartido")
struct SharedDocumentTests {

    @Test("La clave del boletín da un nombre legible")
    func theBulletinKeyBecomesAReadableName() {
        #expect(SharedDocument.fileName(forExternalKey: "boc:439765") == "boc-439765.pdf")
    }

    @Test("Una clave que es una URL entera también da un nombre válido")
    func aWholeUrlAsKeyAlsoWorks() {
        // Pasa de verdad: cuando el enlace no trae identificador, la clave es la dirección
        // canónica. Los dos puntos y las barras no valen en un nombre de fichero.
        let nombre = SharedDocument.fileName(
            forExternalKey: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=1"
        )
        #expect(nombre.hasSuffix(".pdf"))
        #expect(!nombre.contains("/"))
        #expect(!nombre.contains(":"))
        #expect(!nombre.contains("?"))
        #expect(!nombre.contains("--"))
    }

    @Test("Una clave sin un solo carácter utilizable no deja el nombre vacío")
    func aKeyWithNothingUsableStillGetsAName() {
        #expect(SharedDocument.fileName(forExternalKey: ":::") == "documento.pdf")
        #expect(SharedDocument.fileName(forExternalKey: "") == "documento.pdf")
    }

    @Test("Sin copia local, la ruta es nula y el cierre de exportación la resolverá")
    func withoutALocalCopyThePathIsNil() {
        let pendiente = SharedDocument(externalKey: "boc:1", fileName: "boc-1.pdf", localPath: nil)
        #expect(pendiente.localPath == nil)
        #expect(pendiente.id == "boc:1")
    }
}
