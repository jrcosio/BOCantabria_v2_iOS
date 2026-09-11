//
//  BocMigrations.swift
//  The schema, versioned from day one.
//
//  Todavía no hay ninguna migración que aplicar: la v1 es el punto de partida. El esquema se
//  versiona desde el primer día precisamente para poder escribir la prueba de migración cuando
//  llegue la v2 —que será, casi seguro, la columna de texto normalizado de la feature de Buscar—.
//
//  **La regla de oro de este esquema**: no existe ninguna operación de borrado sobre
//  `publications`. Que una publicación salga de la ventana de cien de su fuente **no la elimina**,
//  porque una fuente solo publica sus últimos cien anuncios y el archivo es lo único que queda.
//

import Foundation
import GRDB

enum BocMigrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // **Se queda en `false`, y merece esta línea.** Es la bandera que uno enciende en
        // desarrollo para no pelearse con una migración y se deja puesta; encendida, un cambio de
        // esquema borraría el archivo entero sin avisar.
        migrator.eraseDatabaseOnSchemaChange = false

        migrator.registerMigration("v1") { database in
            try database.create(table: "publications") { table in
                table.primaryKey("external_key", .text)
                table.column("blob_id", .text).unique()
                table.column("id_source", .text).notNull()
                table.column("feed_id", .text).notNull()
                table.column("section_code", .text).notNull()
                table.column("subsection_code", .text)
                table.column("title", .text).notNull()
                table.column("issuer", .text)
                table.column("organization_path", .text).notNull()
                table.column("edition_type", .text).notNull()
                table.column("publication_date", .text).notNull()
                table.column("document_url", .text).notNull()
                table.column("raw_categories", .text)
                table.column("warnings", .text).notNull()
                // Se fija al insertar y **no se toca al actualizar**: no está en la lista blanca
                // del upsert, y hay una prueba que lo demuestra recogiendo las sentencias.
                table.column("first_seen_at", .integer).notNull()
                table.column("last_seen_at", .integer).notNull()
            }
            try database.create(
                index: "index_publications_on_date",
                on: "publications", columns: ["publication_date"]
            )
            try database.create(
                index: "index_publications_on_section",
                on: "publications", columns: ["section_code"]
            )
            try database.create(
                index: "index_publications_on_subsection",
                on: "publications", columns: ["subsection_code"]
            )
            try database.create(
                index: "index_publications_on_feed_and_date",
                on: "publications", columns: ["feed_id", "publication_date"]
            )

            try database.create(table: "feed_sync_state") { table in
                table.primaryKey("feed_id", .text)
                // La huella del último cuerpo procesado. Es lo que evita reanalizar cien anuncios
                // idénticos diecinueve veces al día (FR-022).
                table.column("body_hash", .text)
                table.column("etag", .text)
                table.column("last_modified", .text)
                table.column("last_success_at", .integer)
                table.column("consecutive_failures", .integer).notNull().defaults(to: 0)
            }
        }
        return migrator
    }
}
