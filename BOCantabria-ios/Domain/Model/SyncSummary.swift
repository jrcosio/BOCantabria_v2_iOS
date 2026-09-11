//
//  SyncSummary.swift
//  The outcome of one synchronisation.
//
//  `refresh()` **no devuelve publicaciones**: devuelve esto. Las publicaciones llegan a la
//  pantalla por la observación de lo guardado, que es lo que hace que no haya ningún camino por el
//  que un dato de red alcance una vista.
//

import Foundation

struct SyncSummary: Sendable, Hashable {
    let succeededFeeds: Int
    /// Las que la huella del cuerpo dejó fuera sin volver a analizar (FR-022).
    let unchangedFeeds: Int
    let failedFeeds: Int
    let inserted: Int
    let updated: Int
    let rejected: Int

    init(
        succeededFeeds: Int = 0,
        unchangedFeeds: Int = 0,
        failedFeeds: Int = 0,
        inserted: Int = 0,
        updated: Int = 0,
        rejected: Int = 0
    ) {
        self.succeededFeeds = succeededFeeds
        self.unchangedFeeds = unchangedFeeds
        self.failedFeeds = failedFeeds
        self.inserted = inserted
        self.updated = updated
        self.rejected = rejected
    }

    /// Ninguna fuente respondió. **No es un error por sí solo**: con contenido guardado es un
    /// resultado correcto que enciende el aviso de falta de conexión (D-331).
    var allFailed: Bool { succeededFeeds == 0 && unchangedFeeds == 0 && failedFeeds > 0 }

    /// Ninguna fuente falló.
    var isComplete: Bool { failedFeeds == 0 }

    /// El resumen de una sincronización que no llegó a lanzarse porque la caché estaba fresca.
    static let skipped = SyncSummary()
}
