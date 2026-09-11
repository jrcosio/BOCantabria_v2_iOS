//
//  PublicationRecord.swift
//  A row of `publications`, and its translation to the domain.
//
//  El registro **no cruza a la interfaz**: se traduce dentro del cierre de lectura, de modo que la
//  regla que lo prohíbe se cumple por construcción y no por disciplina. Un registro que sale del
//  cierre es un registro que alguien acabará pasando a una vista «solo por esta vez».
//
//  La conversión de `BocDate` vive aquí y no en el tipo de dominio: `DatabaseValueConvertible` es
//  un protocolo de GRDB, y ponérselo a `BocDate` le daría a un tipo de dominio una capacidad que
//  solo existe por la capa de datos (research.md D-315).
//

import Foundation
import GRDB

struct PublicationRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "publications"

    var externalKey: String
    var blobId: String?
    var idSource: String
    var feedId: String
    var sectionCode: String
    var subsectionCode: String?
    var title: String
    var issuer: String?
    /// La ruta jerárquica serializada. El separador es el mismo que usa el servicio, así que una
    /// inspección manual de la base se lee igual que el campo original.
    var organizationPath: String
    var editionType: String
    /// Texto ISO: **el orden lexicográfico coincide con el cronológico**, así que ordenar por esta
    /// columna funciona sin conversión y la base es legible con cualquier herramienta.
    var publicationDate: String
    var documentUrl: String
    var rawCategories: String?
    var warnings: String
    var firstSeenAt: Int64
    var lastSeenAt: Int64

    enum CodingKeys: String, CodingKey {
        case externalKey = "external_key"
        case blobId = "blob_id"
        case idSource = "id_source"
        case feedId = "feed_id"
        case sectionCode = "section_code"
        case subsectionCode = "subsection_code"
        case title
        case issuer
        case organizationPath = "organization_path"
        case editionType = "edition_type"
        case publicationDate = "publication_date"
        case documentUrl = "document_url"
        case rawCategories = "raw_categories"
        case warnings
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
    }

    static let pathSeparator = "|"
    static let warningSeparator = ","
}

extension PublicationRecord {
    init(_ publication: Publication, seenAt: Date) {
        let timestamp = Int64(seenAt.timeIntervalSince1970)
        self.init(
            externalKey: publication.externalKey,
            blobId: publication.blobId,
            idSource: publication.idSource.rawValue,
            feedId: publication.feedId,
            sectionCode: publication.sectionCode,
            subsectionCode: publication.subsectionCode,
            title: publication.title,
            issuer: publication.issuer,
            organizationPath: publication.organizationPath.joined(separator: Self.pathSeparator),
            editionType: publication.editionType.rawValue,
            publicationDate: publication.publicationDate.iso,
            documentUrl: publication.documentUrl.absoluteString,
            rawCategories: publication.rawCategories,
            warnings: publication.warnings.map(\.rawValue).sorted()
                .joined(separator: Self.warningSeparator),
            firstSeenAt: timestamp,
            lastSeenAt: timestamp
        )
    }

    /// - Returns: `nil` si la fila está corrupta —una fecha ilegible, una dirección imposible—.
    ///   Es preferible saltarse una fila a devolver una publicación inventada.
    func toDomain() -> Publication? {
        guard let date = BocDate(iso: publicationDate),
              let url = URL(string: documentUrl),
              let source = IdSource(rawValue: idSource),
              let edition = EditionType(rawValue: editionType)
        else { return nil }

        let path = organizationPath.isEmpty
            ? []
            : organizationPath.components(separatedBy: Self.pathSeparator)
        let parsedWarnings = warnings.isEmpty
            ? []
            : warnings.components(separatedBy: Self.warningSeparator)
                .compactMap(ParserWarning.init(rawValue:))

        return Publication(
            externalKey: externalKey,
            blobId: blobId,
            idSource: source,
            feedId: feedId,
            sectionCode: sectionCode,
            subsectionCode: subsectionCode,
            title: title,
            issuer: issuer,
            organizationPath: path,
            editionType: edition,
            publicationDate: date,
            documentUrl: url,
            rawCategories: rawCategories,
            warnings: Set(parsedWarnings)
        )
    }
}

struct FeedSyncStateRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "feed_sync_state"

    var feedId: String
    var bodyHash: String?
    var etag: String?
    var lastModified: String?
    var lastSuccessAt: Int64?
    var consecutiveFailures: Int

    enum CodingKeys: String, CodingKey {
        case feedId = "feed_id"
        case bodyHash = "body_hash"
        case etag
        case lastModified = "last_modified"
        case lastSuccessAt = "last_success_at"
        case consecutiveFailures = "consecutive_failures"
    }
}
