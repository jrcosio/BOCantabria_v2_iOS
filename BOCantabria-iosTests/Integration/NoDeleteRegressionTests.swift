//
//  NoDeleteRegressionTests.swift
//  The guarantee that a publication is never deleted, demonstrated by executing.
//
//  **La regla de texto no basta, y ésta es la razón.** GRDB borra con métodos de registro
//  —`deleteAll()`, `record.delete(db)`— sin que la palabra aparezca en ninguna cadena del fuente.
//  Una regla que mire el código, por bien escrita que esté, no ve ese borrado.
//
//  Lo que sí lo ve es recoger **cada sentencia que se ejecuta** durante una sincronización
//  completa. Esa misma traza es la infraestructura que la feature de Guardados va a necesitar para
//  demostrar que desmarcar no borra, y la de Avisos para demostrar que borrar una regla deja
//  `publications` con las mismas filas.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Nunca se borra una publicación")
struct NoDeleteRegressionTests {

    private func makeGraph() -> (FeedSyncCoordinator, PublicationLocalDataSource) {
        let provider = BocDatabaseProvider.inMemory(
            crashReporter: NoOpCrashReporter(), tracingStatements: true
        )
        _ = provider.database()
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        let coordinator = FeedSyncCoordinator(
            local: local,
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
            clock: ImmediateClock(),
            crashReporter: NoOpCrashReporter(),
            catalog: Array(BocFeedCatalog.active.prefix(3))
        )
        return (coordinator, local)
    }

    @Test("Una sincronización completa no ejecuta ni un borrado sobre publications (FR-021)")
    func noStatementDeletesAPublication() async {
        let (coordinator, local) = makeGraph()

        _ = await coordinator.sync()

        let statements = local.executedStatements
        #expect(!statements.isEmpty, "Sin sentencias recogidas, esta prueba no comprobaría nada")

        let deletions = statements.filter { statement in
            let upper = statement.uppercased()
            return upper.contains("DELETE") && upper.contains("PUBLICATIONS")
        }
        #expect(deletions.isEmpty, "Se ejecutó un borrado: \(deletions)")
    }

    @Test("El UPDATE de la sincronización es una lista blanca de columnas")
    func theSyncUpdateIsAWhitelist() async {
        let (coordinator, local) = makeGraph()

        // Dos vueltas: la segunda es la que actualiza lo ya conocido.
        _ = await coordinator.sync()
        _ = await coordinator.sync()

        let updates = local.executedStatements.filter {
            $0.uppercased().contains("UPDATE PUBLICATIONS")
        }
        #expect(!updates.isEmpty)

        // Hoy la única columna protegida es la de la primera observación. Cuando lleguen la marca
        // de guardado y la de evaluación pendiente tampoco estarán en la lista, y no hará falta
        // acordarse de protegerlas: esta prueba se pondrá roja si alguien las añade.
        for protectedColumn in ["first_seen_at", "saved_at", "pending_alert_evaluation"] {
            let touched = updates.contains { $0.contains(protectedColumn) }
            #expect(!touched, "El UPDATE toca «\(protectedColumn)», que no está en la lista blanca")
        }
    }

    @Test("Una publicación que sale de la ventana de cien sigue guardada (SC-005)")
    func aPublicationThatLeavesTheFeedWindowSurvives() async {
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )

        // Lo que ya estaba guardado de una sincronización anterior.
        _ = local.store(
            [publication(externalKey: "boc:999", date: "2020-01-02")],
            bodyHash: "viejo", feedId: "6802081", at: .now
        )
        #expect(local.publications(for: .section(code: "1", subsectionCode: nil)).count == 1)

        // Y una sincronización nueva en la que esa publicación **ya no viene**: la fuente solo
        // publica sus últimos cien anuncios.
        let coordinator = FeedSyncCoordinator(
            local: local,
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
            clock: ImmediateClock(),
            crashReporter: NoOpCrashReporter(),
            catalog: Array(BocFeedCatalog.active.prefix(1))
        )
        _ = await coordinator.sync()

        let stored = local.publications(for: .section(code: "1", subsectionCode: nil))
        #expect(stored.count == 6, "Las cinco nuevas y la vieja, que no se borra")
        let keys = stored.map(\.externalKey)
        #expect(keys.contains("boc:999"))
    }
}
