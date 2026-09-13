//
//  SharedDocument.swift
//  The document as the system's share sheet will see it.
//
//  Vive en `Domain` y no en `UI` porque **el nombre visible es una decisión de producto**: quien
//  recibe el anuncio tiene que poder reconocerlo. El fichero en disco se llama con una huella de
//  sesenta y cuatro caracteres (research.md D-505), y mandarlo así sería técnicamente correcto e
//  inservible.
//

import Foundation

struct SharedDocument: Sendable, Hashable, Identifiable {
    let externalKey: String

    /// El nombre legible, `2026-6695.pdf`. **Nunca la huella** (FR-042).
    let fileName: String

    /// `nil` mientras el documento no esté en caché: el cierre de exportación lo resolverá.
    let localPath: String?

    var id: String { externalKey }

    /// El nombre que se ofrece, derivado de la clave externa cuando no hay otro mejor.
    ///
    /// `boc:439765` da `boc-439765.pdf`. Los dos puntos y las barras no valen en un nombre de
    /// fichero, y la clave puede traer **una URL entera** cuando el enlace no lleva identificador.
    static func fileName(forExternalKey key: String) -> String {
        let safe = key.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(safe).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
        return collapsed.isEmpty ? "documento.pdf" : "\(collapsed).pdf"
    }
}
