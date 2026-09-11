//
//  SyncFlowIntegrationTests.swift
//  The whole chain over an in-memory database, with a double only at the network boundary.
//
//  Los nueve casos de FR-083 se nombran uno a uno. No es exhaustividad por gusto: cada uno es una
//  forma distinta de que la sincronización se equivoque sin que nada falle a la vista.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Recorrido de la sincronización")
struct SyncFlowIntegrationTests {

    private struct Graph {
        let repository: PublicationRepositoryImpl
        let local: PublicationLocalDataSource
        let coordinator: FeedSyncCoordinator
    }

    private func makeGraph(
        downloader: FeedDownloader,
        catalog: [BocFeedDefinition] = Array(BocFeedCatalog.active.prefix(1)),
        clock: AppClock = ImmediateClock()
    ) -> Graph {
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        let coordinator = FeedSyncCoordinator(
            local: local, downloader: downloader, clock: clock,
            crashReporter: NoOpCrashReporter(), catalog: catalog
        )
        return Graph(
            repository: PublicationRepositoryImpl(
                local: local, coordinator: coordinator, clock: clock
            ),
            local: local,
            coordinator: coordinator
        )
    }

    // MARK: - Los nueve casos de FR-083

    @Test("1 · Primera obtención: se guarda lo que traen las fuentes")
    func firstFetchStoresWhatArrives() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data))
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.inserted == 5)
        #expect(graph.local.publications(for: .section(code: "1", subsectionCode: nil)).count == 5)
    }

    @Test("2 · Segunda sin cambios: la huella coincide y no se reescribe nada")
    func aSecondQuietSyncWritesNothing() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data))
        _ = await graph.repository.refresh(force: true)

        let second = await graph.repository.refresh(force: true)
        guard case .success(let summary) = second else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.unchangedFeeds == 1)
        #expect(summary.inserted == 0)
        #expect(summary.updated == 0)
    }

    @Test("3 · Una publicación nueva se inserta")
    func aNewPublicationIsInserted() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.oposiciones.data),
                              catalog: [BocFeedCatalog.named("6802085")!])
        _ = await graph.repository.refresh(force: true)
        let before = graph.local.publications(for: .section(code: "2", subsectionCode: "2.2")).count

        _ = graph.local.store(
            [publication(externalKey: "boc:777", sectionCode: "2", subsectionCode: "2.2")],
            bodyHash: "x", feedId: "6802085", at: .now
        )
        let after = graph.local.publications(for: .section(code: "2", subsectionCode: "2.2")).count
        #expect(after == before + 1)
    }

    @Test("4 · Una publicación conocida se actualiza y conserva su primera observación")
    func aKnownPublicationIsUpdated() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data))
        _ = await graph.repository.refresh(force: true)

        // La misma clave con otro título: se actualiza, no se duplica.
        let existing = graph.local.publications(for: .section(code: "1", subsectionCode: nil)).first!
        let counts = graph.local.store(
            [publication(externalKey: existing.externalKey, title: "Título corregido")],
            bodyHash: "y", feedId: "6802081", at: .now
        )
        #expect(counts.updated == 1)
        #expect(counts.inserted == 0)
    }

    @Test("5 · Una publicación que sale de la ventana de cien NO se borra (FR-021, SC-005)")
    func aPublicationOutOfTheWindowSurvives() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data))
        _ = graph.local.store(
            [publication(externalKey: "boc:999", date: "2019-01-02")],
            bodyHash: "viejo", feedId: "6802081", at: .now
        )

        _ = await graph.repository.refresh(force: true)

        let keys = graph.local.publications(for: .section(code: "1", subsectionCode: nil))
            .map(\.externalKey)
        #expect(keys.contains("boc:999"))
        #expect(keys.count == 6)
    }

    @Test("6 · Una fuente que falla no impide las demás (FR-004)")
    func oneFailingSourceDoesNotStopTheRest() async {
        let graph = makeGraph(
            downloader: CountingFeedDownloader(
                body: Fixture.disposiciones.data, failing: ["6802081"]
            ),
            catalog: Array(BocFeedCatalog.active.prefix(3))
        )
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.failedFeeds == 1)
        #expect(summary.succeededFeeds == 2)
        #expect(graph.local.hasAnyPublication())
    }

    @Test("7 · Todas fallan CON contenido guardado: no es un error")
    func everySourceFailsWithStoredContent() async {
        let graph = makeGraph(downloader: FailingFeedDownloader())
        _ = graph.local.store([publication()], bodyHash: "s", feedId: "6802081", at: .now)

        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else {
            Issue.record("Con contenido guardado esto NO es un error"); return
        }
        #expect(summary.allFailed)
    }

    @Test("8 · Todas fallan SIN nada guardado: fallo de red")
    func everySourceFailsWithNothingStored() async {
        let graph = makeGraph(downloader: FailingFeedDownloader())
        #expect(await graph.repository.refresh(force: true) == .failure(.network))
    }

    @Test("9 · La misma publicación en dos fuentes es UN registro, no dos tarjetas iguales")
    func theSamePublicationInTwoSourcesIsOneRow() async {
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
                              catalog: Array(BocFeedCatalog.active.prefix(2)))

        // Las dos fuentes devuelven el mismo cuerpo, así que traen las mismas cinco claves.
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.inserted == 5)
        #expect(summary.updated == 5, "La segunda fuente actualiza, no inserta")

        let all = graph.local.publications(for: .todaysBulletin)
        #expect(Set(all.map(\.externalKey)).count == all.count, "Ninguna clave repetida")
    }

    // MARK: - Las anomalías del servicio (SC-007)

    @Test("La 8.1 responde bien y no trae nada: estado vacío, ningún error")
    func theEmptySourceIsNotAnError() async {
        let graph = makeGraph(
            downloader: CountingFeedDownloader(body: Fixture.vacio.data),
            catalog: [BocFeedCatalog.named("7479572")!]
        )
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("No es un error"); return }
        #expect(summary.succeededFeeds == 1)
        #expect(summary.inserted == 0)
        #expect(summary.rejected == 0)
        #expect(graph.local.publications(for: .section(code: "8", subsectionCode: "8.1")).isEmpty)
    }

    @Test("La 4.3 trae sus nueve, con su aviso y ninguna descartada")
    func theAnomalousSourceKeepsEverything() async {
        let graph = makeGraph(
            downloader: CountingFeedDownloader(body: Fixture.anomalo.data),
            catalog: [BocFeedCatalog.named("6802091")!]
        )
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("No es un error"); return }
        #expect(summary.inserted == 9)
        #expect(summary.rejected == 0)

        let stored = graph.local.publications(for: .section(code: "4", subsectionCode: "4.3"))
        #expect(stored.count == 9)
        let flagged = stored.filter { $0.warnings.contains(.categoryOrderUnreliable) }
        #expect(flagged.count == 7)
    }

    @Test("Una sección sin publicar desde hace años se ve con su fecha real (FR-038)")
    func anOldSectionShowsItsRealDate() async {
        let graph = makeGraph(
            downloader: CountingFeedDownloader(body: Fixture.anomalo.data),
            catalog: [BocFeedCatalog.named("6802091")!]
        )
        _ = await graph.repository.refresh(force: true)

        var header: BulletinHeader?
        for await result in graph.repository.observeHeader(
            .section(code: "4", subsectionCode: "4.3")
        ) {
            if case .success(let value) = result { header = value }
            break
        }

        #expect(header?.count == 9)
        #expect(header?.date?.iso == "2021-03-26")
        // El rótulo es el que evita que una fecha de hace años se lea como un fallo.
        #expect(header?.dateMeaning == .latestInSection)
        let labelled = BocDateFormatting.labelled(header?.date, meaning: .latestInSection)
        #expect(labelled == "Última publicación: 26 de marzo de 2021")
    }

    @Test("Una fecha ilegible se rechaza sola, con su motivo, sin detener la fuente (FR-010)")
    func anUnreadableDateRejectsOnlyItsOwnItem() async {
        let graph = makeGraph(
            downloader: CountingFeedDownloader(body: Fixture.fechaInvalida.data)
        )
        let result = await graph.repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.rejected > 0, "Alguna se rechaza")
        #expect(summary.succeededFeeds == 1, "Y la fuente sigue contando como respondida")
    }

    @Test("Cinco sincronizaciones seguidas no duplican y el recuento no baja (SC-004, SC-005)")
    func fiveSynchronisationsInARowAreStable() async {
        var counts: [Int] = []
        let graph = makeGraph(downloader: CountingFeedDownloader(body: Fixture.disposiciones.data))
        for _ in 0..<5 {
            _ = await graph.repository.refresh(force: true)
            counts.append(graph.local.publications(for: .todaysBulletin).count)
        }
        #expect(counts == [2, 2, 2, 2, 2], "Dos publicaciones comparten la fecha más reciente")
        let all = graph.local.publications(for: .section(code: "1", subsectionCode: nil))
        #expect(Set(all.map(\.externalKey)).count == all.count)
    }
}
