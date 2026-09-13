//
//  OfficialDocumentTests.swift
//
//  **La prueba de `isValidChecksum` es la que protege FR-024**, y protege contra un fallo real: en
//  la aplicación de origen, un lateral presente pero vacío no se trataba como ausente y cerraba la
//  aplicación al abrir esa publicación. El caso de la cadena vacía de aquí abajo es ese defecto.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Documento oficial")
struct OfficialDocumentTests {
    private static let valida = String(repeating: "a1b2c3d4", count: 8)  // 64 hex

    @Test("Una huella de sesenta y cuatro hexadecimales en minúscula es válida")
    func aLowercaseHexOfSixtyFourIsValid() {
        #expect(Self.valida.count == 64)
        #expect(OfficialDocument.isValidChecksum(Self.valida))
        #expect(OfficialDocument.isValidChecksum(String(repeating: "0", count: 64)))
        #expect(OfficialDocument.isValidChecksum(String(repeating: "f", count: 64)))
    }

    @Test(
        "Todo lo demás es huella perdida",
        arguments: [
            Case(name: "vacía", value: ""),
            Case(name: "sesenta y tres", value: String(repeating: "a", count: 63)),
            Case(name: "sesenta y cinco", value: String(repeating: "a", count: 65)),
            Case(name: "en mayúsculas", value: String(repeating: "A1B2C3D4", count: 8)),
            Case(name: "con un espacio al final", value: String(repeating: "a", count: 63) + " "),
            Case(name: "con un carácter no hexadecimal", value: String(repeating: "a", count: 63) + "z"),
            Case(name: "con un salto de línea", value: String(repeating: "a", count: 63) + "\n"),
        ]
    )
    func everythingElseIsALostFingerprint(_ testCase: Case) {
        #expect(!OfficialDocument.isValidChecksum(testCase.value), "«\(testCase.name)» debería ser inválida")
    }

    @Test("La huella desconocida mide sesenta y cuatro, para que el tipo no se rompa al llevarla")
    func theUnknownChecksumIsItselfWellFormed() {
        // Es la clave de FR-024: el documento se sirve **igual**, así que el valor que lo acompaña
        // tiene que ser uno que el propio tipo acepte.
        #expect(OfficialDocument.isValidChecksum(OfficialDocument.unknownChecksum))
        #expect(OfficialDocument.unknownChecksum.count == 64)
    }

    @Test("Un documento con huella perdida lo dice")
    func aDocumentWithAnUnknownChecksumSaysSo() {
        let perdida = OfficialDocument(
            externalKey: "boc:1", localPath: "/x.pdf", byteCount: 10,
            checksum: OfficialDocument.unknownChecksum, lastUsedAt: .distantPast
        )
        let buena = OfficialDocument(
            externalKey: "boc:1", localPath: "/x.pdf", byteCount: 10,
            checksum: Self.valida, lastUsedAt: .distantPast
        )
        #expect(perdida.hasUnknownChecksum)
        #expect(!buena.hasUnknownChecksum)
    }

    /// Un `struct` de caso y **no una tupla**: `CLAUDE.md` anota que un `arguments:` con tuplas y
    /// miembros inferidos hace explotar al comprobador de tipos.
    struct Case: Sendable {
        let name: String
        let value: String
    }
}
