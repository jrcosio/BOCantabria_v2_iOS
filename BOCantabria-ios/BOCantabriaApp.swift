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
    @State private var container = AppContainer(
        telemetry: .resolved(),
        contentScenario: LaunchConfiguration.contentScenario
    )

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
