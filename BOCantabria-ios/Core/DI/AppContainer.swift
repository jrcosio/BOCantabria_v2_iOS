//
//  AppContainer.swift
//  The composition root: the whole dependency graph, declared in one place.
//
//  Todo se recibe **por inicializador** y detrás de un protocolo. La consecuencia es la garantía
//  que el proyecto Android tenía que comprobar en ejecución: aquí **un cableado incompleto no
//  compila**. La prueba que construye este contenedor cubre lo que el compilador no ve —que se
//  construye sin efectos de arranque y que los ámbitos son los previstos—.
//
//  **Este fichero no importa ningún SDK de terceros**, y no es casualidad: la decisión de qué
//  telemetría se usa la toma `TelemetryBundle`, en la capa de datos.
//

import Foundation

@MainActor
final class AppContainer {
    private let telemetry: TelemetryBundle
    private let clock: AppClock

    private let appConfigRepository: AppConfigRepository
    private let connectivityRepository: ConnectivityRepository
    private let installedVersion: AppVersion?

    /// Compartidos en todo el proceso. **Construirlos no abre nada**: el proveedor de la base solo
    /// guarda cómo abrirla, y quien la abre es la comprobación previa de la portada (D-305).
    private let databaseProvider: BocDatabaseProvider
    private let publicationRepository: PublicationRepository
    private let sectionRepository: BocSectionRepository
    private let selectionStore: HomeSelectionStore

    init(
        telemetry: TelemetryBundle,
        clock: AppClock = SystemClock(),
        random: AppRandom = SystemRandom(),
        databaseProvider: BocDatabaseProvider? = nil,
        downloader: FeedDownloader? = nil,
        selectionStore: HomeSelectionStore? = nil,
        dataScenario: DataScenario = .live,
        remoteConfig: RemoteConfigDataSource = UnavailableRemoteConfigDataSource(),
        connectivity: ConnectivityDataSource = PathMonitorConnectivityDataSource(),
        startupScenario: StartupScenario = .ready,
        installedVersion: AppVersion? = AppInfo.installedVersion
    ) {
        self.telemetry = telemetry
        self.clock = clock
        self.installedVersion = installedVersion

        // El escenario de datos sustituye a la costura de la 001, y solo cambia **de dónde salen
        // los datos**: todo lo que hay por encima —fuente local, repositorio, casos de uso, modelo
        // de pantalla— es exactamente el de producción, que es lo que hace que la prueba de
        // interfaz pruebe algo.
        let provider = databaseProvider
            ?? (dataScenario == .live
                ? BocDatabaseProvider(crashReporter: telemetry.crashReporter)
                : BocDatabaseProvider.inMemory(crashReporter: telemetry.crashReporter))
        self.databaseProvider = provider
        let local = PublicationLocalDataSource(
            provider: provider, crashReporter: telemetry.crashReporter
        )
        if dataScenario.seedsContent {
            _ = provider.database()
            // **La antigüedad de la siembra es parte del escenario.** Sembrar «ahora» deja la
            // caché fresca y la sincronización ni se intenta: con eso, el escenario «sin conexión»
            // enseñaba el contenido y **nunca encendía el aviso**, porque no llegaba a fallar
            // nada. Para que falle, lo sembrado tiene que estar caducado.
            let seededAt = dataScenario == .offline
                ? clock.now().addingTimeInterval(-3600)
                : clock.now()
            ScenarioDatabaseSeeder.seed(local, at: seededAt)
        }
        self.sectionRepository = BocSectionRepositoryImpl()
        self.selectionStore = selectionStore ?? UserDefaultsSelectionStore()
        self.publicationRepository = PublicationRepositoryImpl(
            local: local,
            coordinator: FeedSyncCoordinator(
                local: local,
                downloader: downloader
                    ?? (dataScenario == .live
                        ? HttpFeedDownloader(clock: clock, random: random)
                        : ScenarioFeedDownloader(scenario: dataScenario, clock: clock)),
                clock: clock,
                crashReporter: telemetry.crashReporter
            ),
            clock: clock
        )

        // **Un solo punto de sustitución.** El escenario del arranque solo cambia de dónde salen
        // los datos; todo lo que hay por encima —repositorio, caso de uso, modelo de pantalla— es
        // exactamente el de producción, que es lo que hace que la prueba de interfaz pruebe algo.
        let startupRemote: RemoteConfigDataSource
        let startupConnectivity: ConnectivityDataSource
        switch startupScenario {
        case .ready:
            startupRemote = remoteConfig
            startupConnectivity = connectivity
        case .offline:
            startupRemote = ScenarioRemoteConfigDataSource(scenario: .offline, clock: clock)
            startupConnectivity = FixedConnectivityDataSource(online: false)
        case .updateRequired, .maintenance, .slow:
            startupRemote = ScenarioRemoteConfigDataSource(scenario: startupScenario, clock: clock)
            startupConnectivity = FixedConnectivityDataSource(online: true)
        }

        self.connectivityRepository = ConnectivityRepositoryImpl(dataSource: startupConnectivity)
        self.appConfigRepository = AppConfigRepositoryImpl(
            remote: startupRemote,
            connectivity: connectivityRepository,
            crashReporter: telemetry.crashReporter
        )
    }

    /// Nuevo en cada llamada, como el de inicio. Lo posee la raíz de navegación, y por eso el
    /// estado del arranque sobrevive al ciclo de segundo plano (FR-008).
    func makeSplashViewModel() -> SplashViewModel {
        SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: appConfigRepository,
                connectivity: connectivityRepository,
                storage: databaseProvider,
                installedVersion: installedVersion
            ),
            analytics: telemetry.analytics,
            crashReporter: telemetry.crashReporter,
            clock: clock
        )
    }

    /// Nuevo en cada llamada: un modelo de pantalla tiene el ciclo de vida de su pantalla.
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            observePublications: ObservePublicationsUseCase(repository: publicationRepository),
            observeHeader: ObserveBulletinHeaderUseCase(repository: publicationRepository),
            refreshPublications: RefreshPublicationsUseCase(repository: publicationRepository),
            analytics: telemetry.analytics
        )
    }

    /// Nuevo en cada llamada, como los demás. El armazón lo posee la raíz de navegación, así que
    /// la selección sobrevive al ciclo de segundo plano.
    func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            store: selectionStore,
            sections: GetBocSectionsUseCase(repository: sectionRepository)()
        )
    }
}
