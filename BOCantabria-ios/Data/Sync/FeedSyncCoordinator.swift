//
//  FeedSyncCoordinator.swift
//  Runs one synchronisation, and only one.
//
//  **Escribe el padre, no los hijos.** Los hijos descargan, analizan y normalizan —trabajo puro,
//  sin estado compartido— y devuelven valores; quien toca la base es siempre la misma tarea. Un
//  solo escritor hace que las diecinueve transacciones salgan ordenadas, que la observación emita
//  hasta diecinueve veces en lugar de solaparse, y que el invariante de «nunca se borra» tenga un
//  único sitio donde comprobarse.
//
//  **La segunda llamada espera y comparte el resultado**, no se ignora. Ignorarla haría que el
//  indicador de refresco desapareciera antes que la sincronización, que es la forma más barata de
//  que alguien refresque tres veces seguidas.
//

import Foundation

actor FeedSyncCoordinator {
    /// Tope de fuentes simultáneas. Es cortesía con el servicio oficial: diecinueve peticiones a
    /// la vez desde cada teléfono no es aceptable (FR-005).
    static let maxConcurrentFeeds = 4

    private let local: PublicationLocalDataSource
    private let downloader: FeedDownloader
    private let clock: AppClock
    private let catalog: [BocFeedDefinition]
    private let crashReporter: CrashReporter

    /// La sincronización en curso. **Tiene dueño**: este actor la guarda, la limpia al terminar y
    /// puede cancelarla. Hereda la prioridad del llamante pero no su cancelación, que es lo que se
    /// quiere: que una pantalla se cierre no debe matar la sincronización que otra está esperando.
    private var running: Task<SyncSummary, Never>?

    init(
        local: PublicationLocalDataSource,
        downloader: FeedDownloader,
        clock: AppClock,
        crashReporter: CrashReporter,
        catalog: [BocFeedDefinition] = BocFeedCatalog.active
    ) {
        self.local = local
        self.downloader = downloader
        self.clock = clock
        self.crashReporter = crashReporter
        self.catalog = catalog
    }

    func sync() async -> SyncSummary {
        if let running { return await running.value }
        let task = Task<SyncSummary, Never> { await self.run() }
        running = task
        let summary = await task.value
        running = nil
        return summary
    }

    func cancel() {
        running?.cancel()
        running = nil
    }

    // MARK: - El recorrido

    private func run() async -> SyncSummary {
        var succeeded = 0, unchanged = 0, failed = 0, inserted = 0, updated = 0, rejected = 0

        await withTaskGroup(of: FeedOutcome.self) { group in
            var next = catalog.startIndex

            // Ventana explícita: se ceban cuatro y, por cada resultado que llega, entra la
            // siguiente. Limitar conexiones por host no serviría: limita conexiones, no tareas, no
            // cubre ni el analizado ni la escritura, y **no es observable desde una prueba**, que
            // para este proyecto es descalificante.
            while next < catalog.endIndex, next < Self.maxConcurrentFeeds {
                let definition = catalog[next]
                group.addTask { await self.fetchAndNormalise(definition) }
                next += 1
            }

            while let outcome = await group.next() {
                // **Aquí escribe el padre**, en cuanto la fuente termina: el contenido aparece
                // conforme llega, que es lo que hace posible el objetivo de los quince segundos.
                switch outcome {
                case .unchanged:
                    unchanged += 1
                case .failed(let definition, let failure):
                    failed += 1
                    record(failure: failure, for: definition)
                case .fetched(let definition, let publications, let rejectedCount, let hash):
                    succeeded += 1
                    rejected += rejectedCount
                    let counts = write(publications, hash: hash, for: definition)
                    inserted += counts.inserted
                    updated += counts.updated
                }

                if next < catalog.endIndex {
                    let definition = catalog[next]
                    group.addTask { await self.fetchAndNormalise(definition) }
                    next += 1
                }
            }
        }

        return SyncSummary(
            succeededFeeds: succeeded, unchangedFeeds: unchanged, failedFeeds: failed,
            inserted: inserted, updated: updated, rejected: rejected
        )
    }

    private enum FeedOutcome: Sendable {
        case fetched(BocFeedDefinition, [Publication], rejected: Int, hash: String)
        case unchanged
        case failed(BocFeedDefinition, FeedFailure)
    }

    /// Todo lo que hace un hijo: pedir, analizar y normalizar. **No escribe en la base.**
    ///
    /// Es `nonisolated` **a propósito y es imprescindible**: si fuera un método aislado del actor,
    /// las diecinueve tareas del grupo se serializarían sobre él y el tope de cuatro dejaría de
    /// significar nada. Puede serlo porque no toca estado mutable del actor: todo lo que usa son
    /// constantes `Sendable`.
    private nonisolated func fetchAndNormalise(
        _ definition: BocFeedDefinition
    ) async -> FeedOutcome {
        let knownHash = local.knownBodyHash(feedId: definition.feedId)

        switch await downloader.fetch(definition, knownBodyHash: knownHash) {
        case .notModified:
            return .unchanged
        case .failed(let failure):
            return .failed(definition, failure)
        case .fetched(let body, let hash):
            do {
                let channel = try await BocRssParser.parseFeed(body)
                var publications: [Publication] = []
                var rejected = 0
                for item in channel.items {
                    switch PublicationNormalizer.normalize(item, from: definition) {
                    case .accepted(let publication): publications.append(publication)
                    case .rejected(let reason):
                        rejected += 1
                        // Un descarte sin motivo es un misterio. Nunca el título, que es contenido.
                        crashReporter.log("sync: rejected item in \(definition.feedId): \(reason.rawValue)")
                    }
                }
                return .fetched(definition, publications, rejected: rejected, hash: hash)
            } catch {
                crashReporter.log("sync: parse failed for \(definition.feedId): \(error)")
                return .failed(definition, .untrusted)
            }
        }
    }

    private func write(
        _ publications: [Publication],
        hash: String,
        for definition: BocFeedDefinition
    ) -> (inserted: Int, updated: Int) {
        local.store(
            publications, bodyHash: hash, feedId: definition.feedId, at: clock.now()
        )
    }

    private func record(failure: FeedFailure, for definition: BocFeedDefinition) {
        crashReporter.log("sync: feed \(definition.feedId) failed with \(failure.rawValue)")
        local.recordFailure(feedId: definition.feedId)
    }
}
