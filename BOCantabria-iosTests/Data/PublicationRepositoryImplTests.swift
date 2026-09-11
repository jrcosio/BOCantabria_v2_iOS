//
//  PublicationRepositoryImplTests.swift
//
//  Las cinco filas de la política de `refresh(force:)`, una prueba por fila, y la caducidad, que
//  es lo único de este fichero que necesita un reloj controlable.
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

@Suite("Repositorio de publicaciones")
struct PublicationRepositoryImplTests {

    private func makeRepository(
        downloader: FeedDownloader,
        clock: AppClock = ImmediateClock(),
        catalog: [BocFeedDefinition] = Array(BocFeedCatalog.active.prefix(2)),
        seeded: [Publication] = [],
        seededAt: Date? = nil
    ) -> (PublicationRepositoryImpl, PublicationLocalDataSource) {
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        if !seeded.isEmpty || seededAt != nil {
            _ = local.store(
                seeded, bodyHash: "seed", feedId: "6802081", at: seededAt ?? clock.now()
            )
        }
        let coordinator = FeedSyncCoordinator(
            local: local, downloader: downloader, clock: clock,
            crashReporter: NoOpCrashReporter(), catalog: catalog
        )
        return (
            PublicationRepositoryImpl(local: local, coordinator: coordinator, clock: clock),
            local
        )
    }

    // MARK: - Las cinco filas

    @Test("Todas responden: éxito y ninguna fallida")
    func everySourceAnswers() async {
        let (repository, local) = makeRepository(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data)
        )
        let result = await repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.failedFeeds == 0)
        #expect(local.hasAnyPublication())
    }

    @Test("Algunas fallan: sigue siendo éxito, y se ve lo que sí respondió")
    func someSourcesFail() async {
        let (repository, local) = makeRepository(
            downloader: CountingFeedDownloader(
                body: Fixture.disposiciones.data, failing: ["6802081"]
            )
        )
        let result = await repository.refresh(force: true)
        guard case .success(let summary) = result else { Issue.record("Se esperaba éxito"); return }
        #expect(summary.failedFeeds == 1)
        #expect(!summary.allFailed, "Ningún mensaje de error: las demás sí respondieron")
        #expect(local.hasAnyPublication())
    }

    @Test("Todas fallan CON contenido guardado: éxito con la bandera, no un error")
    func everySourceFailsButThereIsContent() async {
        let (repository, local) = makeRepository(
            downloader: FailingFeedDownloader(), seeded: [publication()]
        )
        let result = await repository.refresh(force: true)
        guard case .success(let summary) = result else {
            Issue.record("Con contenido guardado esto NO es un error"); return
        }
        #expect(summary.allFailed)
        #expect(local.hasAnyPublication())
    }

    @Test("Todas fallan SIN nada guardado: fallo de red")
    func everySourceFailsAndThereIsNothing() async {
        let (repository, _) = makeRepository(downloader: FailingFeedDownloader())
        #expect(await repository.refresh(force: true) == .failure(.network))
    }

    @Test("Caché fresca y sin forzar: resumen vacío y SIN tocar la red")
    func aFreshCacheIsNotRefreshed() async {
        let downloader = CountingFeedDownloader(body: Fixture.disposiciones.data)
        let clock = ManualClock()
        let (repository, _) = makeRepository(
            downloader: downloader, clock: clock, seeded: [publication()], seededAt: clock.now()
        )

        let result = await repository.refresh(force: false)

        #expect(result == .success(.skipped))
        #expect(await downloader.calls.isEmpty, "No se pidió nada: la caché estaba fresca")
    }

    // MARK: - La caducidad

    @Test("A los veintinueve minutos no caduca; a los treinta y uno, sí (FR-023)")
    func theCacheExpiresAfterThirtyMinutes() async {
        let clock = ManualClock()
        let (repository, _) = makeRepository(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
            clock: clock, seeded: [publication()], seededAt: clock.now()
        )

        #expect(await !repository.isCacheStale())
        await clock.advance(by: 29 * 60)
        #expect(await !repository.isCacheStale())
        await clock.advance(by: 2 * 60)
        #expect(await repository.isCacheStale())
    }

    @Test("Una marca en el futuro cuenta como caducada, no como recién sincronizada")
    func aFutureMarkCountsAsStale() async {
        // Si alguien atrasa la hora del dispositivo, la marca queda por delante del reloj.
        // Tratarla como reciente congelaría la caché hasta que el reloj la alcanzara.
        let clock = ManualClock()
        let (repository, _) = makeRepository(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
            clock: clock, seeded: [publication()],
            seededAt: clock.now().addingTimeInterval(3600)
        )
        #expect(await repository.isCacheStale())
    }

    @Test("Sin ninguna sincronización previa, la caché está caducada")
    func nothingSyncedYetMeansStale() async {
        let (repository, _) = makeRepository(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data)
        )
        #expect(await repository.isCacheStale())
    }

    // MARK: - La observación

    @Test("La observación emite lo guardado y se desmonta al cancelarla")
    func theObservationStopsWhenCancelled() async {
        let (repository, local) = makeRepository(
            downloader: CountingFeedDownloader(body: Fixture.disposiciones.data),
            seeded: [publication(externalKey: "boc:1")]
        )

        // Se cuentan las emisiones **dentro del propio flujo**: tomar el primer valor no permite
        // ver que un flujo termina, porque lo toma y cancela.
        let received = Mutex(0)
        let task = Task {
            for await result in repository.observePublications(.todaysBulletin) {
                if case .success = result { received.withLock { $0 += 1 } }
            }
        }
        while received.withLock({ $0 }) == 0 { await Task.yield() }
        let afterFirst = received.withLock { $0 }

        task.cancel()
        _ = await task.value
        _ = local.store([publication(externalKey: "boc:2")], bodyHash: "b", feedId: "6802081", at: .now)
        try? await Task.sleep(for: .milliseconds(120))

        #expect(received.withLock { $0 } == afterFirst, "Cancelada, no puede llegar otro valor")
    }
}
