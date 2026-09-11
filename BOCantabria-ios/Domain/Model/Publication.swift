//
//  Publication.swift
//  A single announcement of the Boletín Oficial de Cantabria.
//
//  Lo que el resto de la aplicación entiende por una publicación. No sabe de dónde salió el XML
//  ni cómo se guarda: eso son los otros dos vocabularios, y la traducción entre los tres es real,
//  no una copia de campos.
//

import Foundation

struct Publication: Sendable, Hashable, Identifiable, Codable {
    /// Identidad estable de la publicación. `boc:439765` cuando el enlace trae identificador.
    let externalKey: String

    /// El identificador del enlace, cuando lo hay.
    let blobId: String?

    /// Cuál de los tres escalones de la cascada dio `externalKey`.
    let idSource: IdSource

    /// La fuente de la que se obtuvo. **Es la clasificación autoritativa** (FR-012).
    let feedId: String

    let sectionCode: String
    let subsectionCode: String?

    /// Íntegro, tal como se recibe. Recortar es cosa de la pantalla (FR-018).
    let title: String

    /// Organismo emisor deducido. Es **auxiliar** y puede quedar nulo.
    let issuer: String?

    /// Ruta jerárquica del organismo, de más general a más concreta.
    let organizationPath: [String]

    let editionType: EditionType
    let publicationDate: BocDate

    /// Enlace al documento oficial. Siempre HTTPS.
    let documentUrl: URL

    /// El campo de clasificación original, sin tocar. Solo enriquece y verifica (FR-013).
    let rawCategories: String?

    /// Las anomalías detectadas al normalizar. Tenerlas **no** rompe ningún invariante.
    let warnings: Set<ParserWarning>

    var id: String { externalKey }

    /// El código más específico que la publicación tiene. Es lo que la pantalla usa para nombrar
    /// su sección.
    var mostSpecificSectionCode: String { subsectionCode ?? sectionCode }
}
