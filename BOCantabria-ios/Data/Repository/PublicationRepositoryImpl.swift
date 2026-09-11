//
//  PublicationRepositoryImpl.swift
//  The five-row policy, and the only door between the database and the screen.
//
//  `refresh` **no devuelve publicaciones**: escribe y devuelve un resumen. Las publicaciones
//  llegan por la observación. Es lo que hace que no exista ningún camino por el que un dato recién
//  traído de la red alcance una vista sin pasar por lo guardado.
//

import Foundation

struct PublicationRepositoryImpl: PublicationRepository {
    /// La ventana de caducidad. Valor de partida razonable para un boletín que se publica una vez
    /// al día, elegido por prudencia con el servicio oficial (FR-023).
    static let staleAfter: TimeInterval = 30 * 60

    private let local: PublicationLocalDataSource
    private let coordinator: FeedSyncCoordinator
    private let clock: AppClock

    init(
        local: PublicationLocalDataSource,
        coordinator: FeedSyncCoordinator,
        clock: AppClock
    ) {
        self.local = local
        self.coordinator = coordinator
        self.clock = clock
    }

    // MARK: - Observación

    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>> {
        local.observePublications(selection)
    }

    func observeHeader(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>> {
        local.observeHeader(selection, title: Self.title(for: selection))
    }

    // MARK: - Sincronización

    func isCacheStale() async -> Bool {
        guard let last = local.lastSuccess() else { return true }
        let elapsed = clock.now().timeIntervalSince(last)
        // **Un transcurrido negativo cuenta como caducado.** Si alguien atrasa la hora del
        // dispositivo, la marca queda en el futuro; tratarla como recién sincronizada congelaría
        // la caché hasta que el reloj alcanzara ese valor.
        return elapsed < 0 || elapsed > Self.staleAfter
    }

    func refresh(force: Bool) async -> AppResult<SyncSummary> {
        if !force, await !isCacheStale() {
            // Caché fresca: resumen vacío y **sin tocar la red**.
            return .success(.skipped)
        }

        let summary = await coordinator.sync()

        guard summary.allFailed else { return .success(summary) }

        // Todas fallaron. Si hay algo guardado, esto **no es un error**: es un resultado correcto
        // que la pantalla convierte en el aviso de falta de conexión.
        return local.hasAnyPublication() ? .success(summary) : .failure(.network)
    }

    private static func title(for selection: HomeSelection) -> String {
        switch selection {
        case .todaysBulletin:
            String(localized: Strings.Home.bulletinToday)
        case .section(let code, let subsection):
            BocSection.named(subsection ?? code)?.name ?? ""
        }
    }
}
