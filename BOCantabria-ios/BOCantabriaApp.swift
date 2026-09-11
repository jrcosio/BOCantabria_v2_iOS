//
//  BOCantabriaApp.swift
//  The entry point.
//
//  Construye el contenedor y monta la raíz de navegación. **No conoce ninguna dependencia
//  individual**: el grafo entero está en `AppContainer`.
//

import SwiftUI

@main
struct BOCantabriaApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}

private extension AppContainer {
    /// El contenedor de producción.
    ///
    /// El proveedor se resuelve **una sola vez** y de ahí salen las dos cosas que dependen de que
    /// esté configurado: la telemetría y la configuración remota (research.md D-209).
    static func live() -> AppContainer {
        let provider = ProviderBundle.resolved()
        return AppContainer(
            telemetry: provider.telemetry,
            remoteConfig: provider.remoteConfig,
            startupScenario: LaunchConfiguration.startupScenario
        )
    }
}
