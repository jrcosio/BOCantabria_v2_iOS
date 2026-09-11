//
//  AppConfigRepositoryImplTests.swift
//  One test per row of the policy table in contracts/internal-contracts.md §2.
//

import Testing

@testable import BOCantabria_ios

@Suite("Repositorio de configuración")
struct AppConfigRepositoryImplTests {

    private func makeRepository(
        values: RemoteConfigValues? = .empty,
        online: Bool = true,
        crashReporter: CrashReporter = NoOpCrashReporter()
    ) -> AppConfigRepositoryImpl {
        AppConfigRepositoryImpl(
            remote: FakeRemoteConfigDataSource(values: values),
            connectivity: FakeConnectivityRepository(online: online),
            crashReporter: crashReporter
        )
    }

    @Test("El servicio responde: se traduce al dominio")
    func translatesWhatTheServiceReturns() async {
        let repository = makeRepository(values: RemoteConfigValues(
            minSupportedVersion: "1.2.0",
            maintenanceMessage: "Volvemos a las 18:00."
        ))
        let result = await repository.loadConfig()
        #expect(result == .success(AppConfig(
            minSupportedVersion: AppVersion(major: 1, minor: 2, patch: 0),
            maintenanceMessage: "Volvemos a las 18:00."
        )))
    }

    @Test("El servicio falla y no hay camino de red: error de conexión")
    func failureWithoutNetworkIsANetworkError() async {
        let result = await makeRepository(values: nil, online: false).loadConfig()
        #expect(result == .failure(.network))
    }

    @Test("El servicio falla y sí hay camino de red: error inesperado")
    func failureWithNetworkIsUnknown() async {
        // Es la única decisión que toma la conectividad: cuál de los dos mensajes se muestra.
        let result = await makeRepository(values: nil, online: true).loadConfig()
        #expect(result == .failure(.unknown))
    }

    @Test("Sin valores publicados: los valores por defecto, no un fallo")
    func nothingPublishedIsNotAFailure() async {
        let result = await makeRepository(values: .empty).loadConfig()
        #expect(result == .success(AppConfig.default))
    }

    @Test("Una versión mínima ilegible no bloquea, y queda registrada")
    func unreadableMinimumVersionFallsBackToZero() async {
        // FR-015. Es el fallo más caro posible de esta feature —dejar fuera a todo el mundo por
        // una errata en la consola— así que además de no bloquear, se cuenta.
        let crashReporter = RecordingCrashReporter()
        let repository = makeRepository(
            values: RemoteConfigValues(minSupportedVersion: "latest", maintenanceMessage: ""),
            crashReporter: crashReporter
        )
        let result = await repository.loadConfig()
        #expect(result == .success(AppConfig.default))
        #expect(crashReporter.messages.contains { $0.contains("unreadable minimum version") })
    }

    @Test("Un mensaje de mantenimiento vacío es «sin mantenimiento»")
    func emptyMaintenanceMessageBecomesNil() async {
        let repository = makeRepository(values: RemoteConfigValues(
            minSupportedVersion: "1.0.0",
            maintenanceMessage: "   "
        ))
        let result = await repository.loadConfig()
        #expect(try! result.get().maintenanceMessage == nil)
    }

    @Test("Sin fichero de configuración del proveedor: los valores por defecto")
    func withoutTheProviderFileItStillSucceeds() async {
        // SC-010. Si esto fallara, la pantalla de error sería lo normal en desarrollo, que es la
        // forma más rápida de que una pantalla de error deje de mirarse.
        let repository = AppConfigRepositoryImpl(
            remote: UnavailableRemoteConfigDataSource(),
            connectivity: FakeConnectivityRepository(online: false),
            crashReporter: NoOpCrashReporter()
        )
        let result = await repository.loadConfig()
        #expect(result == .success(AppConfig.default))
    }

    @Test("Ninguna excepción escapa de la capa de datos")
    func noExceptionEscapes() async {
        // El doble lanza siempre. Si algo escapara, esta prueba no llegaría a la aserción.
        let result = await makeRepository(values: nil).loadConfig()
        switch result {
        case .success: Issue.record("Un fallo del servicio no puede llegar como éxito.")
        case .failure: break
        }
    }

    @Test("Todo camino de fallo deja constancia del motivo")
    func everyFailurePathIsLogged() async {
        // FR-018: la pantalla no dice códigos a propósito, así que el registro es el único sitio
        // donde se distingue qué pasó.
        let crashReporter = RecordingCrashReporter()
        _ = await makeRepository(values: nil, online: false, crashReporter: crashReporter)
            .loadConfig()
        #expect(crashReporter.messages.contains { $0.hasPrefix("startup:") })
    }
}
