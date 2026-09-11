//
//  SplashViewModel.swift
//  The cover's screen model: four states, and the timing that makes it readable.
//
//  **`onAppear()` no retorna hasta haber publicado el estado final.** No es estilo: es lo que
//  permite que una prueba haga `await viewModel.onAppear()` y afirme sobre el estado en la línea
//  siguiente. Una tarea sin dueño dentro de este tipo dejaría a las pruebas sin ninguna forma de
//  esperar, y de paso sobreviviría a la pantalla.
//

import Foundation

@MainActor
@Observable
final class SplashViewModel {
    static let screenName = "splash"

    private(set) var state: SplashUiState = .preparing

    private let prepareStartup: PrepareStartupUseCase
    private let analytics: AnalyticsTracker
    private let crashReporter: CrashReporter
    private let clock: AppClock
    private let minimumDisplaySeconds: Double
    private let timeoutSeconds: Double

    private var hasPrepared = false
    private var isPreparing = false

    init(
        prepareStartup: PrepareStartupUseCase,
        analytics: AnalyticsTracker,
        crashReporter: CrashReporter,
        clock: AppClock,
        minimumDisplaySeconds: Double = 1.2,
        timeoutSeconds: Double = 8.0
    ) {
        self.prepareStartup = prepareStartup
        self.analytics = analytics
        self.crashReporter = crashReporter
        self.clock = clock
        self.minimumDisplaySeconds = minimumDisplaySeconds
        self.timeoutSeconds = timeoutSeconds
        // Una vez por instancia, como en `HomeViewModel`: la pantalla vista es la visita, no cada
        // aparición.
        analytics.trackScreenView(Self.screenName)
    }

    func onAppear() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        await prepare()
    }

    func onRetry() async {
        // FR-011: no es que no haga nada visible, es que **no lanza una segunda preparación**.
        guard !isPreparing else { return }
        await prepare()
    }

    func onContinueOffline() {
        // FR-012 y FR-013: solo desde el error recuperable. Desde el acceso bloqueado se ignora, y
        // que el estado sea un caso propio es lo que hace que esto no se pueda escribir mal.
        guard case .error = state else { return }
        state = .ready
    }

    private func prepare() async {
        guard !isPreparing else { return }
        isPreparing = true
        state = .preparing
        defer { isPreparing = false }

        // **El mínimo corre en paralelo con el trabajo, no antes ni después** (FR-005). En serie
        // sumaría los dos tiempos y haría el arranque artificialmente lento para todo el mundo,
        // cuando el parpadeo solo lo sufren los dispositivos rápidos.
        async let minimumElapsed: Void? = try? clock.sleep(seconds: minimumDisplaySeconds)

        let outcome = await preparationOrTimeout()
        _ = await minimumElapsed

        // La cancelación no se traduce a un error: si la pantalla ya no está, no hay nada que
        // publicar. Es la política que fijó la feature 001.
        guard !Task.isCancelled else { return }

        publish(outcome)
    }

    /// El trabajo contra el límite de espera. Gana el primero que termine; `nil` significa que se
    /// agotó el tiempo.
    private func preparationOrTimeout() async -> AppResult<StartupStatus>? {
        let useCase = prepareStartup
        let clock = clock
        let timeout = timeoutSeconds

        return await withTaskGroup(of: AppResult<StartupStatus>?.self) { group in
            group.addTask { await useCase() }
            group.addTask {
                try? await clock.sleep(seconds: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func publish(_ outcome: AppResult<StartupStatus>?) {
        guard let outcome else {
            // FR-006. Se trata como fallo de red y no como inesperado a propósito: lo que produce
            // este caso es una red que acepta la conexión y no responde, y «comprueba tu conexión»
            // es lo único accionable que se le puede decir a quien lo sufre.
            crashReporter.log("startup: preparation timed out after \(timeoutSeconds)s")
            state = .error(.network)
            return
        }

        switch outcome {
        case let .success(.maintenance(message)):
            state = .blocked(.maintenance(message))
        case .success(.updateRequired):
            state = .blocked(.updateRequired)
        case .success(.ready):
            state = .ready
        case let .failure(error):
            crashReporter.log("startup: preparation failed (\(error))")
            state = .error(error)
        }
    }
}
