//
//  ScenarioStartupSources.swift
//  The startup sources a UI test asks for by launch argument.
//
//  **Es la otra punta de la costura de `LaunchConfiguration`** y, como ella, es código de
//  producción a sabiendas: una prueba de interfaz corre en otro proceso y no puede sustituir nada
//  por dentro. Sin esto, tres de los cuatro estados del arranque no serían alcanzables desde una
//  prueba automática (research.md D-212).
//
//  Sigue el patrón que la feature 001 estableció con `StubContentRemoteDataSource`: los escenarios
//  son un enumerado, viven en `Data` y solo se activan cuando el argumento llega.
//

struct ScenarioRemoteConfigDataSource: RemoteConfigDataSource {
    struct Failure: Error {}

    private let scenario: StartupScenario
    private let clock: AppClock

    init(scenario: StartupScenario, clock: AppClock) {
        self.scenario = scenario
        self.clock = clock
    }

    func fetchValues() async throws -> RemoteConfigValues {
        switch scenario {
        case .ready:
            return .empty
        case .offline:
            throw Failure()
        case .updateRequired:
            // Por encima de cualquier versión que se llegue a publicar.
            return RemoteConfigValues(minSupportedVersion: "99.0.0", maintenanceMessage: "")
        case .maintenance:
            return RemoteConfigValues(
                minSupportedVersion: "",
                maintenanceMessage: "Estamos actualizando el servicio. Vuelve en unos minutos."
            )
        case .slow:
            // No responde. El límite de espera del modelo de pantalla es quien corta, que es justo
            // lo que la prueba quiere ver.
            try await clock.sleep(seconds: 60)
            return .empty
        }
    }
}

struct FixedConnectivityDataSource: ConnectivityDataSource {
    let online: Bool

    func isOnline() async -> Bool { online }
}
