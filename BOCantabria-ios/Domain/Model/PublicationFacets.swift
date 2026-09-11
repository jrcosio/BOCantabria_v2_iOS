//
//  PublicationFacets.swift
//  The small closed vocabularies a publication carries.
//
//  Los tres son enumerados sin comportamiento y están en la lista de exentos de la regla 9: lo
//  único que podría afirmar un fichero de prueba propio es que el compilador funciona. Su
//  semántica se prueba donde vive, en `PublicationNormalizerTests`.
//

import Foundation

/// Ordinaria o extraordinaria. Se detecta **en cualquier posición** del campo de clasificación,
/// porque hay una fuente que los trae permutados (FR-014).
enum EditionType: String, Sendable, Codable, CaseIterable {
    case ordinary = "ORD"
    case extraordinary = "EXT"
    case unknown = "UNKNOWN"
}

/// Qué escalón de la cascada dio la identidad de una publicación (FR-017).
///
/// Se guarda porque decide si un registro es **sustituible**: si mañana una publicación
/// identificada por huella aparece con su identificador de verdad, hay que poder saberlo.
enum IdSource: String, Sendable, Codable, CaseIterable {
    case blobId = "BLOB_ID"
    case canonicalUrl = "CANONICAL_URL"
    case contentHash = "CONTENT_HASH"
}

/// Lo que se detectó al normalizar. **Nunca es motivo de descarte** (FR-015): se guarda y se
/// cuenta, y es lo que permite saber sobre un dispositivo real si el servicio ha cambiado de
/// forma.
enum ParserWarning: String, Sendable, Codable, CaseIterable {
    case categoryDoesNotMatchFeed = "CATEGORY_DOES_NOT_MATCH_FEED"
    case editionTypeMissing = "EDITION_TYPE_MISSING"
    case categoryOrderUnreliable = "CATEGORY_ORDER_UNRELIABLE"
    case categoriesAbsent = "CATEGORIES_ABSENT"
}
