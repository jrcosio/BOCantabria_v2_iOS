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

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Contenedor de dependencias")
@MainActor
struct AppContainerTests {

    @Test("Resuelve el modelo de pantalla del arranque, y nace preparando")
    func resolvesTheSplashViewModel() {
        let container = AppContainer(
            telemetry: .noOp,
            clock: ImmediateClock(),
            connectivity: FixedConnectivityDataSource(online: true)
        )
        #expect(container.makeSplashViewModel().state == .preparing)
    }

    @Test("Cada pantalla recibe su propio modelo del arranque")
    func eachScreenGetsItsOwnSplashViewModel() {
        let container = AppContainer(
            telemetry: .noOp,
            clock: ImmediateClock(),
            connectivity: FixedConnectivityDataSource(online: true)
        )
        #expect(container.makeSplashViewModel() !== container.makeSplashViewModel())
    }

    @Test("Se construye entero y entrega todas las pantallas")
    func buildsAndDeliversEveryScreen() {
        let container = AppContainer(telemetry: .noOp, clock: ImmediateClock())

        let viewModel = container.makeHomeViewModel()

        // Arranca con marcadores, no con una pantalla en blanco.
        #expect(viewModel.state.content == .skeleton)
    }

    @Test("Entrega también el armazón, con su árbol de secciones")
    func itDeliversTheShell() {
        // **El almacén se inyecta.** Con el de producción, esta prueba lee las preferencias reales
        // del anfitrión y hereda la selección que dejó una ejecución anterior: la primera versión
        // falló por eso, con «2.2» guardado de una tanda de pruebas de interfaz. Es exactamente la
        // contaminación entre pruebas de la que avisa `UserDefaultsSelectionStore`.
        let store = UserDefaultsSelectionStore(
            defaults: UserDefaults(suiteName: "boc-container-\(UUID().uuidString)")!
        )
        let container = AppContainer(
            telemetry: .noOp, clock: ImmediateClock(), selectionStore: store
        )
        let shell = container.makeMainViewModel()
        #expect(shell.state.sections.count == 9)
        #expect(shell.state.selection == .todaysBulletin)
        #expect(container.makeMainViewModel() !== shell, "Un modelo por pantalla")
    }

    @Test("Construirlo no abre la base: eso es un paso del arranque, no un efecto del grafo")
    func buildingDoesNotOpenTheDatabase() async {
        // Si se abriera aquí, un fallo de migración no tendría dónde contarse: la portada es el
        // único sitio con indicador, límite de espera y reintento (research.md D-305).
        let crashReporter = RecordingCrashReporter()
        _ = AppContainer(
            telemetry: TelemetryBundle(
                analytics: NoOpAnalyticsTracker(), crashReporter: crashReporter
            ),
            clock: ImmediateClock()
        )
        #expect(crashReporter.messages.isEmpty)
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

    @Test("Cada pantalla recibe su propio modelo")
    func scopesAreTheExpectedOnes() async {
        let container = AppContainer(telemetry: .noOp, clock: ImmediateClock())

        let first = container.makeHomeViewModel()
        let second = container.makeHomeViewModel()

        // Modelos distintos: un modelo de pantalla tiene el ciclo de vida de su pantalla.
        #expect(first !== second)

        // Y los dos ven lo mismo, porque lo que comparten es el almacén.
        //
        // Se comparan el contenido y la selección, **no el estado entero**: la cabecera llega por
        // una observación propia y a su ritmo, así que compararla sería una carrera y la prueba
        // fallaría a veces por un motivo que no tiene nada que ver con lo que quiere comprobar.
        await first.apply(.todaysBulletin)
        await second.apply(.todaysBulletin)
        #expect(first.state.content == second.state.content)
        #expect(first.state.selection == second.state.selection)
        #expect(first.state.sectionChips == second.state.sectionChips)
    }
}
