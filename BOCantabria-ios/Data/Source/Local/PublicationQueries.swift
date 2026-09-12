//
//  PublicationQueries.swift
//  Every read and write over `publications`. **Ni un borrado.**
//
//  Dos invariantes viven aquí y los dos tienen prueba que los demuestra ejecutando, no leyendo:
//
//  - **Nunca se borra una publicación** (FR-021). Que salga de la ventana de cien de su fuente no
//    la elimina.
//  - **La actualización es una lista blanca de columnas**, y `first_seen_at` no está en ella. El
//    día que existan la marca de guardado y la de evaluación pendiente tampoco lo estarán, y no
//    hará falta acordarse de protegerlas.
//

import Foundation
import GRDB

enum PublicationQueries {

    /// El orden, en todas las consultas.
    ///
    /// El tercer criterio es el desempate determinista que FR-028 exige: sin él, dos ejecuciones
    /// pueden dar órdenes distintos porque las diecinueve fuentes responden en orden distinto, y
    /// eso **se ve**: la lista cambia sola al refrescar.
    static let orderClause = """
        ORDER BY publication_date DESC, CAST(blob_id AS INTEGER) DESC, external_key DESC
        """

    // MARK: - Escritura

    /// Inserta lo que no está y actualiza lo que sí, **sin tocar `first_seen_at`** (FR-020).
    /// - Returns: cuántas se insertaron y cuántas se actualizaron.
    @discardableResult
    static func upsert(
        _ publications: [Publication],
        seenAt: Date,
        in database: Database
    ) throws -> (inserted: Int, updated: Int) {
        var inserted = 0
        var updated = 0
        let timestamp = Int64(seenAt.timeIntervalSince1970)

        for publication in publications {
            let record = PublicationRecord(publication, seenAt: seenAt)
            let exists = try Bool.fetchOne(
                database,
                sql: "SELECT EXISTS(SELECT 1 FROM publications WHERE external_key = ?)",
                arguments: [publication.externalKey]
            ) ?? false

            if exists {
                // **Lista blanca.** Lo que no está aquí no se toca, y eso es la protección: no
                // depende de que nadie se acuerde.
                try database.execute(
                    sql: """
                        UPDATE publications SET
                            blob_id = :blobId, id_source = :idSource, feed_id = :feedId,
                            section_code = :sectionCode, subsection_code = :subsectionCode,
                            title = :title, issuer = :issuer,
                            organization_path = :organizationPath, edition_type = :editionType,
                            publication_date = :publicationDate, document_url = :documentUrl,
                            raw_categories = :rawCategories, warnings = :warnings,
                            last_seen_at = :lastSeenAt
                        WHERE external_key = :externalKey
                        """,
                    arguments: [
                        "blobId": record.blobId, "idSource": record.idSource,
                        "feedId": record.feedId, "sectionCode": record.sectionCode,
                        "subsectionCode": record.subsectionCode, "title": record.title,
                        "issuer": record.issuer, "organizationPath": record.organizationPath,
                        "editionType": record.editionType,
                        "publicationDate": record.publicationDate,
                        "documentUrl": record.documentUrl,
                        "rawCategories": record.rawCategories, "warnings": record.warnings,
                        "lastSeenAt": timestamp, "externalKey": record.externalKey,
                    ]
                )
                updated += 1
            } else {
                try record.insert(database)
                inserted += 1
            }
        }
        return (inserted, updated)
    }

    static func markSuccess(
        feedId: String,
        bodyHash: String?,
        at instant: Date,
        in database: Database
    ) throws {
        try FeedSyncStateRecord(
            feedId: feedId, bodyHash: bodyHash, etag: nil, lastModified: nil,
            lastSuccessAt: Int64(instant.timeIntervalSince1970), consecutiveFailures: 0
        ).save(database)
    }

    static func markFailure(feedId: String, in database: Database) throws {
        let previous = try FeedSyncStateRecord
            .filter(Column("feed_id") == feedId).fetchOne(database)
        try FeedSyncStateRecord(
            feedId: feedId,
            bodyHash: previous?.bodyHash,
            etag: previous?.etag,
            lastModified: previous?.lastModified,
            lastSuccessAt: previous?.lastSuccessAt,
            consecutiveFailures: (previous?.consecutiveFailures ?? 0) + 1
        ).save(database)
    }

    static func knownBodyHash(feedId: String, in database: Database) throws -> String? {
        try FeedSyncStateRecord.filter(Column("feed_id") == feedId).fetchOne(database)?.bodyHash
    }

    /// El instante de la última sincronización con éxito de **cualquier** fuente.
    static func lastSuccess(in database: Database) throws -> Date? {
        let value = try Int64.fetchOne(
            database, sql: "SELECT MAX(last_success_at) FROM feed_sync_state"
        )
        return value.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    // MARK: - Lectura

    static func publications(
        for selection: HomeSelection,
        in database: Database
    ) throws -> [Publication] {
        let (clause, arguments) = filter(for: selection, in: database)
        let sql = "SELECT * FROM publications WHERE \(clause) \(orderClause)"
        return try PublicationRecord.fetchAll(database, sql: sql, arguments: arguments)
            .compactMap { $0.toDomain() }
    }

    /// Una publicación concreta, o `nil` si ya no está guardada.
    ///
    /// **Es una consulta de LECTURA y nada más.** Si algún día aparece aquí una escritura, algo se
    /// ha desviado: nada de esta feature toca `publications`, y la regla 13 y la prueba de
    /// regresión del borrado siguen valiendo tal cual.
    ///
    /// El `nil` **no es un fallo** (FR-004): es lo que el detalle necesita para explicar que la
    /// publicación se retiró y ofrecer volver.
    static func publication(externalKey: String, in database: Database) throws -> Publication? {
        try PublicationRecord.fetchOne(
            database,
            sql: "SELECT * FROM publications WHERE external_key = ?",
            arguments: [externalKey]
        )?.toDomain()
    }

    static func count(for selection: HomeSelection, in database: Database) throws -> Int {
        let (clause, arguments) = filter(for: selection, in: database)
        return try Int.fetchOne(
            database, sql: "SELECT COUNT(*) FROM publications WHERE \(clause)", arguments: arguments
        ) ?? 0
    }

    /// La fecha más reciente de la selección. Con el boletín del día es la de la edición; con una
    /// sección, la de su publicación más reciente (FR-034).
    static func latestDate(for selection: HomeSelection, in database: Database) throws -> BocDate? {
        let (clause, arguments) = filter(for: selection, in: database)
        let iso = try String.fetchOne(
            database,
            sql: "SELECT MAX(publication_date) FROM publications WHERE \(clause)",
            arguments: arguments
        )
        return iso.flatMap { BocDate(iso: $0) }
    }

    /// El filtro de cada selección.
    ///
    /// Con una sección principal se filtra por `section_code`, **no** por igualdad con el código
    /// más específico: las secciones 2, 4, 7 y 8 no tienen fuente propia y su contenido es la
    /// unión del de sus subsecciones.
    private static func filter(
        for selection: HomeSelection,
        in database: Database
    ) -> (String, StatementArguments) {
        switch selection {
        case .todaysBulletin:
            (
                "publication_date = (SELECT MAX(publication_date) FROM publications)",
                StatementArguments()
            )
        case .section(let code, nil):
            ("section_code = ?", StatementArguments([code]))
        case .section(_, .some(let subsection)):
            ("subsection_code = ?", StatementArguments([subsection]))
        }
    }
}
