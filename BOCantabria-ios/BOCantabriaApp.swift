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
    // Sin telemetría por ahora: la historia 3 sustituye esto por la resolución que decide entre
    // el proveedor y la no operación según exista su fichero de configuración.
    @State private var container = AppContainer(
        telemetry: .noOp,
        contentScenario: LaunchConfiguration.contentScenario
    )

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
