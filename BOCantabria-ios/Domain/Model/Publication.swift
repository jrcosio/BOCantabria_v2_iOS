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

    /// The title with the leading issuer removed, when the title merely repeats it.
    ///
    /// **El BOC publica el organismo dos veces y las dos son el mismo dato.** Viene en la ruta de
    /// clasificación —de donde sale `issuer`— y otra vez al principio del título, en mayúsculas y
    /// seguido de dos puntos: «CONSEJERÍA DE SALUD: Convocatoria de concurso-oposición…». Pintar
    /// las dos deja la tarjeta diciendo lo mismo dos veces seguidas, que es exactamente lo que el
    /// propietario pidió evitar —«y debajo, **sin el nombre de la entidad**, el título»— y lo que
    /// `AccessibilityUITests.testTheIssuerIsNotPaintedTwice` existía para impedir. Esa prueba
    /// estaba en verde por accidente: comparaba distinguiendo mayúsculas (research.md D-416).
    ///
    /// **Se recorta solo cuando la coincidencia es exacta**, sin distinguir mayúsculas, sobre el
    /// texto anterior a los primeros dos puntos. Un prefijo que solo se parezca se deja intacto:
    /// «FRATERNIDAD MUPRESPA MATEPSS Nº 275» no es «Fraternidad Muprespa», y recortar por
    /// parecido mutilaría títulos oficiales. Ante la duda, el título entero.
    ///
    /// **Es presentación, no dato.** Lo almacenado no cambia: compartir manda el título completo y
    /// la búsqueda sigue comparando contra el texto original.
    var titleWithoutIssuer: String {
        guard let issuer, let colon = title.firstIndex(of: ":") else { return title }
        let prefix = title[title.startIndex..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.compare(issuer, options: .caseInsensitive) == .orderedSame else { return title }
        let rest = title[title.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Un título que fuera solo el organismo y los dos puntos se quedaría vacío: entonces vale
        // más el título entero que una tarjeta sin título.
        return rest.isEmpty ? title : rest
    }
}
