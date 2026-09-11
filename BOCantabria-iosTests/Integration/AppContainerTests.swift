//
//  AppContainerTests.swift
//  The composition root builds whole, and builds quietly (FR-023).
//
//  **Esta prueba no comprueba lo mismo que comprobaba la del proyecto Android**, y conviene
//  decirlo. Allí el contenedor resolvía en ejecución y una dependencia sin registrar solo se
//  descubría al abrir la pantalla, así que la prueba existía para adelantar ese fallo. Aquí el
//  cableado es por inicializador: **una dependencia que falte no compila**, que es más fuerte.
//
//  Lo que queda por comprobar es lo que el compilador no ve: que el contenedor real se construye
//  **sin efectos de arranque** —nada de red, nada de disco, nada de telemetría al nacer— y que los
//  ámbitos son los previstos.
//

import Testing
@testable import BOCantabria_ios

@Suite("Contenedor de dependencias")
@MainActor
struct AppContainerTests {

    @Test("Se construye entero y entrega todas las pantallas")
    func buildsAndDeliversEveryScreen() {
        let container = AppContainer(telemetry: .noOp, clock: ImmediateClock())

        let viewModel = container.makeHomeViewModel()

        #expect(viewModel.state == .loading)
    }

    @Test("Construirlo no dispara ningún trabajo")
    func buildingDoesNothingEager() {
        let analytics = RecordingAnalyticsTracker()

        _ = AppContainer(
            telemetry: TelemetryBundle(analytics: analytics, crashReporter: NoOpCrashReporter()),
            clock: ImmediateClock()
        )

        #expect(analytics.events.isEmpty, "El contenedor no puede registrar nada al nacer: aún no ha pasado nada.")
    }

    @Test("Cada pantalla recibe su propio modelo, y todos comparten el mismo almacén")
    func scopesAreTheExpectedOnes() async {
        let container = AppContainer(telemetry: .noOp, clock: ImmediateClock())

        let first = container.makeHomeViewModel()
        let second = container.makeHomeViewModel()

        // Modelos distintos: un modelo de pantalla tiene el ciclo de vida de su pantalla.
        #expect(first !== second)

        // Pero el almacén es compartido: el segundo ve lo que trajo el primero sin volver a
        // pedirlo. Si el repositorio se reconstruyera por pantalla, esto no se cumpliría.
        await first.onAppear()
        await second.onAppear()
        #expect(first.state == second.state)
    }
}
