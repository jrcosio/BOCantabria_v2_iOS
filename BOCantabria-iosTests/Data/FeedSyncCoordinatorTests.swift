//
//  FeedSyncCoordinatorTests.swift
//
//  Dos invariantes que no se ven en el código y que solo una prueba con retención puede demostrar:
//  que nunca hay más de cuatro descargas en vuelo, y que dos llamadas concurrentes producen una
//  sola sincronización.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Coordinador de sincronización")
struct FeedSyncCoordinatorTests {

    private func makeCoordinator(
        downloader: FeedDownloader,
        catalog: [BocFeedDefinition] = BocFeedCatalog.active,
        clock: AppClock = ImmediateClock()
    ) -> (FeedSyncCoordinator, PublicationLocalDataSource) {
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        let coordinator = FeedSyncCoordinator(
            local: local, downloader: downloader, clock: clock,
            crashReporter: NoOpCrashReporter(), catalog: catalog
        )
        return (coordinator, local)
    }

    @Test("Nunca hay más de cuatro fuentes en vuelo (FR-005)")
    func neverMoreThanFourFeedsInFlight() async {
        // Cortesía con el servicio oficial: diecinueve peticiones a la vez desde cada teléfono no
        // es aceptable. El doble se queda suspendido hasta que la prueba lo libera; sin eso, esto
        // mediría la velocidad de la máquina.
        let downloader = CountingFeedDownloader(body: Fixture.disposiciones.data, holdUntilReleased: true)
        let (coordinator, _) = makeCoordinator(downloader: downloader)

        let task = Task { await coordinator.sync() }
        await downloader.waitUntilInFlight(FeedSyncCoordinator.maxConcurrentFeeds)
        await downloader.release()
        _ = await task.value

        #expect(await downloader.maxInFlight == FeedSyncCoordinator.maxConcurrentFeeds)
        #expect(await downloader.calls.count == 19)
    }

    @Test("Dos llamadas concurrentes producen UNA sincronización y el mismo resumen (FR-025)")
    func twoConcurrentCallsShareOneSynchronisation() async {
        // Ignorar la segunda haría que el indicador de refresco desapareciera antes que la
        // sincronización, que es la forma más barata de que alguien refresque tres veces.
        let downloader = CountingFeedDownloader(body: Fixture.disposiciones.data, holdUntilReleased: true)
        let (coordinator, _) = makeCoordinator(downloader: downloader)

        async let first = coordinator.sync()
        async let second = coordinator.sync()
        await downloader.waitUntilInFlight(1)
        await downloader.release()
        let summaries = await (first, second)

        #expect(await downloader.calls.count == 19, "Diecinueve, no treinta y ocho")
        #expect(summaries.0 == summaries.1)
    }

    @Test("El fallo de una fuente no impide las demás (FR-004)")
    func oneFailingFeedDoesNotStopTheRest() async {
        let downloader = CountingFeedDownloader(
            body: Fixture.disposiciones.data, failing: ["6802081", "6802085"]
        )
        let (coordinator, local) = makeCoordinator(downloader: downloader)

        let summary = await coordinator.sync()

        #expect(summary.failedFeeds == 2)
        #expect(summary.succeededFeeds == 17)
        #expect(!summary.allFailed)
        #expect(local.hasAnyPublication())
    }

    @Test("Si ninguna responde, el resumen lo dice y no se guarda nada")
    func whenEverySourceFailsTheSummarySaysSo() async {
        let (coordinator, local) = makeCoordinator(downloader: FailingFeedDownloader())

        let summary = await coordinator.sync()

        #expect(summary.allFailed)
        #expect(summary.failedFeeds == 19)
        #expect(!local.hasAnyPublication())
    }

    @Test("Una fuente cuya huella no ha cambiado no se vuelve a analizar (FR-022)")
    func anUnchangedFeedIsNotProcessedAgain() async {
        let catalog = Array(BocFeedCatalog.active.prefix(2))
        let downloader = CountingFeedDownloader(body: Fixture.disposiciones.data)
        let (coordinator, _) = makeCoordinator(downloader: downloader, catalog: catalog)

        let first = await coordinator.sync()
        let second = await coordinator.sync()

        #expect(first.succeededFeeds == 2)
        #expect(first.unchangedFeeds == 0)
        // La segunda vuelta ve la misma huella: no hay nada que volver a analizar ni que escribir.
        #expect(second.succeededFeeds == 0)
        #expect(second.unchangedFeeds == 2)
        #expect(second.inserted == 0)
    }

    @Test("La segunda sincronización actualiza lo conocido, no lo duplica (SC-004)")
    func repeatedSynchronisationsDoNotDuplicate() async {
        let catalog = Array(BocFeedCatalog.active.prefix(1))
        // Un descargador nuevo cada vez, para que la huella no corte el camino y se ejercite el
        // upsert de verdad.
        let (coordinator, local) = makeCoordinator(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data), catalog: catalog
        )

        var counts: [Int] = []
        for _ in 0..<5 {
            _ = await coordinator.sync()
            counts.append(local.publications(for: .section(code: "1", subsectionCode: nil)).count)
        }
        #expect(counts == [5, 5, 5, 5, 5])
    }
}
