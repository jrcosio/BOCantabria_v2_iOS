//
//  SplashViewModelTests.swift
//  The four states, and the timing that no real clock could verify.
//
//  Todas usan `ManualClock`: con un reloj que devuelve al instante, la carrera contra el límite de
//  espera la ganaría siempre el límite y estas pruebas afirmarían lo contrario de lo que creen.
//

import Testing

@testable import BOCantabria_ios

@Suite("Modelo de pantalla: arranque")
@MainActor
struct SplashViewModelTests {

    private func makeViewModel(
        _ behaviour: FakeAppConfigRepository.Behaviour,
        clock: ManualClock,
        online: Bool = true,
        installed: String? = "1.0.0",
        analytics: AnalyticsTracker = NoOpAnalyticsTracker(),
        crashReporter: CrashReporter = NoOpCrashReporter()
    ) -> SplashViewModel {
        SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: FakeAppConfigRepository(behaviour),
                connectivity: FakeConnectivityRepository(online: online),
                storage: FakeStorage(),
                installedVersion: installed.flatMap { AppVersion($0) }
            ),
            analytics: analytics,
            crashReporter: crashReporter,
            clock: clock
        )
    }

    // MARK: - US1 · Camino feliz y tiempo mínimo

    @Test("El estado inicial es preparando, siempre")
    func startsPreparing() {
        #expect(makeViewModel(.responds(.default), clock: ManualClock()).state == .preparing)
    }

    @Test("Con todo en orden, llega a listo")
    func happyPathReachesReady() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(.responds(.default), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        #expect(viewModel.state == .ready)
    }

    @Test("El trabajo termina enseguida y aun así la portada se queda el mínimo")
    func readyWaitsForTheMinimumDisplayTime() async {
        // FR-005 y SC-002. El trabajo del doble es instantáneo: si el mínimo no se respetara, el
        // estado ya sería `ready` antes de adelantar el reloj, y un parpadeo se percibe como un
        // error de la aplicación, no como velocidad.
        let clock = ManualClock()
        let viewModel = makeViewModel(.responds(.default), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.1)
        #expect(viewModel.state == .preparing, "A 1,1 s todavía no se ha cumplido el mínimo.")

        await clock.advance(by: 0.1)
        await appeared
        #expect(viewModel.state == .ready)
    }

    @Test("El mínimo se solapa con el trabajo, no se le suma")
    func theMinimumRunsInParallelWithTheWork() async {
        // Si la espera fuese en serie habría que adelantar 1,2 s **más** de lo que tarda el
        // trabajo. Aquí el trabajo tarda 2 s de reloj virtual y con ese mismo adelanto ya está
        // listo: 2 s, no 3,2 s.
        let clock = ManualClock()
        let viewModel = makeViewModel(.responds(.default), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 2.0)
        await appeared

        #expect(viewModel.state == .ready)
        let sleeps = clock.requestedSleeps
        #expect(sleeps.contains(1.2), "El mínimo se pide como una espera propia.")
        #expect(sleeps.contains(8.0), "Y el límite también, en la misma tanda.")
    }

    @Test("Volver a aparecer no vuelve a preparar")
    func preparesOnlyOncePerInstance() async {
        let clock = ManualClock()
        let repository = FakeAppConfigRepository(.responds(.default))
        let viewModel = SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: repository,
                connectivity: FakeConnectivityRepository(),
                storage: FakeStorage(),
                installedVersion: AppVersion("1.0.0")
            ),
            analytics: NoOpAnalyticsTracker(),
            crashReporter: NoOpCrashReporter(),
            clock: clock
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared
        await viewModel.onAppear()

        let calls = await repository.callCount
        #expect(calls == 1, "El estado sobrevive: volver a aparecer no recarga (FR-008).")
    }

    // MARK: - US2 · Error recuperable, límite de espera y reintento

    @Test("Si la preparación falla, se publica el error recuperable")
    func failurePublishesARecoverableError() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(.fails(.network), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        #expect(viewModel.state == .error(.network))
    }

    @Test("Si el trabajo no responde, a los ocho segundos se corta y es error")
    func theTimeoutTurnsAHungPreparationIntoAnError() async {
        // FR-006. Sin esto, una red que acepta la conexión y no responde deja la portada girando
        // para siempre, que es el escenario exacto que la historia 2 quiere evitar. Con un reloj
        // inmediato esta prueba pasaría en verde aunque el límite estuviera mal escrito.
        let clock = ManualClock()
        let viewModel = makeViewModel(.neverReturns, clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 7.9)
        #expect(viewModel.state == .preparing, "A 7,9 s todavía se está esperando.")

        await clock.advance(by: 0.1)
        await appeared
        #expect(viewModel.state == .error(.network))
    }

    @Test("Reintentar mientras hay una preparación en curso no lanza una segunda")
    func retryDuringPreparationDoesNotStartASecondOne() async {
        // FR-011. Se cuenta en el doble: «no hace nada visible» y «no lanza una segunda» son
        // cosas distintas, y la que importa es la segunda.
        let clock = ManualClock()
        let repository = FakeAppConfigRepository(.responds(.default))
        let viewModel = SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: repository,
                connectivity: FakeConnectivityRepository(),
                storage: FakeStorage(),
                installedVersion: AppVersion("1.0.0")
            ),
            analytics: NoOpAnalyticsTracker(),
            crashReporter: NoOpCrashReporter(),
            clock: clock
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await viewModel.onRetry()
        await viewModel.onRetry()
        await clock.advance(by: 1.2)
        await appeared

        let calls = await repository.callCount
        #expect(calls == 1, "Los dos reintentos caen dentro de la preparación en curso.")
    }

    @Test("Reintentar desde el error, ya con conexión, llega a listo")
    func retryFromErrorRecovers() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(.failsThenResponds(.default), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared
        #expect(viewModel.state == .error(.network))

        async let retried: Void = viewModel.onRetry()
        await clock.waitUntilSleeping(count: 4)
        await clock.advance(by: 1.2)
        await retried

        #expect(viewModel.state == .ready)
    }

    @Test("Continuar sin conexión desde el error entra al contenido principal")
    func continueOfflineFromErrorReachesReady() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(.fails(.network), clock: clock)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        viewModel.onContinueOffline()
        #expect(viewModel.state == .ready)
    }

    @Test("El fallo deja constancia del motivo en el registro")
    func failuresAreLogged() async {
        // FR-018: la pantalla no dice códigos, así que si esto no se registra, un fallo en un
        // dispositivo de verdad es indistinguible de otro.
        let clock = ManualClock()
        let crashReporter = RecordingCrashReporter()
        let viewModel = makeViewModel(.fails(.unknown), clock: clock, crashReporter: crashReporter)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        #expect(crashReporter.messages.contains { $0.hasPrefix("startup:") })
    }

    // MARK: - US3 · Acceso bloqueado

    @Test("Versión por debajo de la mínima: acceso bloqueado, no error")
    func outdatedVersionIsBlockedAndNotAnError() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(
            .responds(appConfig(minimum: "9.0.0")),
            clock: clock,
            installed: "1.0.0"
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        #expect(viewModel.state == .blocked(.updateRequired))
    }

    @Test("Mantenimiento: se lleva el mensaje que publica el servicio")
    func maintenanceCarriesTheServiceMessage() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(
            .responds(appConfig(maintenance: "Volvemos a las 18:00.")),
            clock: clock
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        #expect(viewModel.state == .blocked(.maintenance("Volvemos a las 18:00.")))
    }

    @Test("Desde el acceso bloqueado, continuar sin conexión NO cuela")
    func continueOfflineIsIgnoredWhenBlocked() async {
        // **Es la prueba que impide colarse**, y la razón de que `blocked` sea un caso propio y no
        // una bandera dentro de `error`: con una bandera, esto dependería de un condicional dentro
        // de la vista, que es donde estas cosas se olvidan.
        let clock = ManualClock()
        let viewModel = makeViewModel(
            .responds(appConfig(minimum: "9.0.0")),
            clock: clock,
            installed: "1.0.0"
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        viewModel.onContinueOffline()
        #expect(viewModel.state == .blocked(.updateRequired), "El bloqueo no tiene salida (FR-012).")
    }

    @Test("Desde el acceso bloqueado, reintentar sí vuelve a preparar")
    func retryWorksFromBlocked() async {
        // Reintentar no es colarse: si la consola cambia, la persona tiene que poder salir del
        // bloqueo sin reinstalar.
        let clock = ManualClock()
        let repository = FakeAppConfigRepository(.responds(appConfig(minimum: "9.0.0")))
        let viewModel = SplashViewModel(
            prepareStartup: PrepareStartupUseCase(
                appConfig: repository,
                connectivity: FakeConnectivityRepository(),
                storage: FakeStorage(),
                installedVersion: AppVersion("1.0.0")
            ),
            analytics: NoOpAnalyticsTracker(),
            crashReporter: NoOpCrashReporter(),
            clock: clock
        )

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared

        async let retried: Void = viewModel.onRetry()
        await clock.waitUntilSleeping(count: 4)
        await clock.advance(by: 1.2)
        await retried

        let calls = await repository.callCount
        #expect(calls == 2)
        #expect(viewModel.state == .blocked(.updateRequired))
    }

    @Test("La pantalla vista se registra una sola vez por instancia")
    func screenViewIsTrackedOncePerInstance() async {
        let clock = ManualClock()
        let analytics = RecordingAnalyticsTracker()
        let viewModel = makeViewModel(.responds(.default), clock: clock, analytics: analytics)

        async let appeared: Void = viewModel.onAppear()
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 1.2)
        await appeared
        await viewModel.onAppear()

        #expect(analytics.screenViews == ["splash"])
    }
}
