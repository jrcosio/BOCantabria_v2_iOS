//
//  PrepareStartupUseCaseTests.swift
//  The startup precedence, one test per row of the table in data-model.md.
//

import Testing

@testable import BOCantabria_ios

@Suite("Preparación del arranque")
struct PrepareStartupUseCaseTests {

    private func makeUseCase(
        config: FakeAppConfigRepository.Behaviour,
        online: Bool = true,
        installed: String? = "1.0.0"
    ) -> PrepareStartupUseCase {
        PrepareStartupUseCase(
            appConfig: FakeAppConfigRepository(config),
            connectivity: FakeConnectivityRepository(online: online),
            storage: FakeStorage(),
            installedVersion: installed.flatMap { AppVersion($0) }
        )
    }

    @Test("Sin nada publicado y con conexión, se puede continuar")
    func defaultsLetYouIn() async {
        let result = await makeUseCase(config: .responds(.default))()
        #expect(result == .success(.ready))
    }

    @Test("Si la configuración no se pudo obtener, el fallo manda")
    func aFailedConfigIsAFailure() async {
        let result = await makeUseCase(config: .fails(.network))()
        #expect(result == .failure(.network))
    }

    @Test("Versión por debajo de la mínima: hay que actualizar")
    func olderThanMinimumRequiresUpdate() async {
        let result = await makeUseCase(
            config: .responds(appConfig(minimum: "2.0.0")),
            installed: "1.9.9"
        )()
        #expect(result == .success(.updateRequired))
    }

    @Test("Versión igual a la mínima: se puede continuar")
    func equalToMinimumIsAllowed() async {
        // El límite es «inferior a», no «distinta de»: publicar la versión actual como mínima no
        // puede dejar fuera a quien la tiene instalada.
        let result = await makeUseCase(
            config: .responds(appConfig(minimum: "1.0.0")),
            installed: "1.0.0"
        )()
        #expect(result == .success(.ready))
    }

    @Test("Mensaje de mantenimiento: se muestra el que publica el servicio")
    func maintenanceCarriesTheServiceMessage() async {
        let result = await makeUseCase(
            config: .responds(appConfig(maintenance: "Volvemos a las 18:00."))
        )()
        #expect(result == .success(.maintenance("Volvemos a las 18:00.")))
    }

    @Test("Versión obsoleta y mantenimiento a la vez: manda la versión obsoleta")
    func updateRequiredWinsOverMaintenance() async {
        // De nada sirve informar de una incidencia temporal a quien no va a poder usar la
        // aplicación de todos modos.
        let result = await makeUseCase(
            config: .responds(appConfig(minimum: "2.0.0", maintenance: "Volvemos pronto.")),
            installed: "1.0.0"
        )()
        #expect(result == .success(.updateRequired))
    }

    @Test("Versión obsoleta y sin conexión a la vez: manda la falta de conexión")
    func offlineWinsOverEverything() async {
        // FR-016. El cliente del proveedor puede servir valores de su caché estando sin conexión,
        // y esos valores no dicen lo que hay publicado hoy: bloquear a alguien por una versión
        // mínima de hace una semana, sin forma de comprobarla, es lo que este caso impide.
        let result = await makeUseCase(
            config: .responds(appConfig(minimum: "2.0.0")),
            online: false,
            installed: "1.0.0"
        )()
        #expect(result == .failure(.network))
    }

    @Test("Mantenimiento y sin conexión a la vez: manda la falta de conexión")
    func offlineWinsOverMaintenanceToo() async {
        let result = await makeUseCase(
            config: .responds(appConfig(maintenance: "Volvemos pronto.")),
            online: false
        )()
        #expect(result == .failure(.network))
    }

    @Test("Si no se puede saber la versión instalada, no se bloquea")
    func unknownInstalledVersionNeverBlocks() async {
        // Es la otra mitad de la defensa de FR-015: ante la duda, no dejar a nadie fuera.
        let result = await makeUseCase(
            config: .responds(appConfig(minimum: "99.0.0")),
            installed: nil
        )()
        #expect(result == .success(.ready))
    }
}
