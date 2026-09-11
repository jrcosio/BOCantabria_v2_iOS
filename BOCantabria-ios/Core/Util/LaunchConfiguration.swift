//
//  LaunchConfiguration.swift
//  Launch-time configuration read from the process arguments.
//
//  **Existe porque en iOS las pruebas de interfaz corren en otro proceso.** En el proyecto Android
//  bastaba con sustituir módulos del grafo desde el propio test; aquí no hay forma de inyectar
//  nada en la aplicación bajo prueba, así que el único mecanismo es pasarle argumentos al
//  lanzarla. FR-025 exige comprobar los cuatro estados, y sin esta costura solo sería alcanzable
//  uno.
//
//  La costura está **acotada a propósito**: solo elige entre escenarios del origen de ejemplo de
//  esta feature, que es material desechable. Cuando la feature del boletín traiga el origen real,
//  esto se sustituye por lo que decida su plan, no se amplía.
//

import Foundation

enum LaunchConfiguration {
    static let argumentPrefix = "-boc-content-scenario="

    static var contentScenario: StubContentRemoteDataSource.Scenario {
        let argument = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix(argumentPrefix) }?
            .dropFirst(argumentPrefix.count)
        return argument
            .flatMap { StubContentRemoteDataSource.Scenario(rawValue: String($0)) }
            ?? .items
    }
}
