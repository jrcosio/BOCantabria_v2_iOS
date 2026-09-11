//
//  StartupFlowIntegrationTests.swift
//  The whole startup, from the screen model down to the sources.
//
//  Los dobles están **solo en la frontera externa** —el servicio de configuración y el monitor de
//  red—. Todo lo de en medio es el código de producción. Es la prueba que se pone roja si alguien
//  desenchufa una capa de la siguiente sin romper ninguna prueba unitaria.
//

import Testing

@testable import BOCantabria_ios

@Suite("Integración: arranque")
@MainActor
struct StartupFlowIntegrationTests {

    private func makeViewModel(
        values: RemoteConfigValues?,
        online: Bool = true,
        installed: String = "1.0.0",
        clock: ManualClock
    ) -> SplashViewModel {
        let connectivity = ConnectivityRepositoryImpl(
            dataSource: FakeConnectivityDataSource(online: online)
        )
        return SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: AppConfigRepositoryImpl(
                    remote: FakeRemoteConfigDataSource(values: values),
                    connectivity: connectivity,
                    crashReporter: NoOpCrashReporter()
                ),
                connectivity: connectivity,
                storage: FakeStorage(),
                installedVersion: AppVersion(installed)
            ),
            analytics: NoOpAnalyticsTracker(),
            crashReporter: NoOpCrashReporter(),
            clock: clock
        )
    }

    private func run(_ viewModel: SplashViewModel, clock: ManualClock, advance: Double = 1.2) async {
        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: advance)
        await appeared
    }

    @Test("Sin nada publicado, el arranque completo llega al contenido principal")
    func nothingPublishedReachesReady() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(values: .empty, clock: clock)
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .ready)
    }

    @Test("Sin fuente de configuración del proveedor, el arranque también llega")
    func withoutTheProviderItStillReachesReady() async {
        // SC-010, recorrido entero: es el estado de un puesto recién clonado.
        let clock = ManualClock()
        let connectivity = ConnectivityRepositoryImpl(
            dataSource: FakeConnectivityDataSource(online: true)
        )
        let viewModel = SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: AppConfigRepositoryImpl(
                    remote: UnavailableRemoteConfigDataSource(),
                    connectivity: connectivity,
                    crashReporter: NoOpCrashReporter()
                ),
                connectivity: connectivity,
                storage: FakeStorage(),
                installedVersion: AppVersion("1.0.0")
            ),
            analytics: NoOpAnalyticsTracker(),
            crashReporter: NoOpCrashReporter(),
            clock: clock
        )
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .ready)
    }

    @Test("Con una versión mínima publicada por encima, el recorrido entero bloquea")
    func aPublishedMinimumVersionBlocksEndToEnd() async {
        // Desde la fuente de datos, no desde un doble del repositorio: es el único modo de
        // comprobar que la traducción del valor publicado y la comparación encajan.
        let clock = ManualClock()
        let viewModel = makeViewModel(
            values: RemoteConfigValues(minSupportedVersion: "9.0.0", maintenanceMessage: ""),
            installed: "1.0.0",
            clock: clock
        )
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .blocked(.updateRequired))
    }

    @Test("Con mensaje de mantenimiento publicado, el recorrido entero lo muestra")
    func aPublishedMaintenanceMessageBlocksEndToEnd() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(
            values: RemoteConfigValues(
                minSupportedVersion: "",
                maintenanceMessage: "Estamos actualizando el servicio."
            ),
            clock: clock
        )
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .blocked(.maintenance("Estamos actualizando el servicio.")))
    }

    @Test("Una versión mínima ilegible publicada no bloquea a nadie")
    func anUnreadablePublishedMinimumBlocksNobody() async {
        // SC-006, recorrido entero. Es el fallo más caro posible de esta feature.
        let clock = ManualClock()
        let viewModel = makeViewModel(
            values: RemoteConfigValues(minSupportedVersion: "latest", maintenanceMessage: ""),
            clock: clock
        )
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .ready)
    }

    @Test("El servicio no responde y no hay red: error recuperable de conexión")
    func serviceFailureWithoutNetworkIsRecoverable() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(values: nil, online: false, clock: clock)
        await run(viewModel, clock: clock)
        #expect(viewModel.state == .error(.network))
    }
}
