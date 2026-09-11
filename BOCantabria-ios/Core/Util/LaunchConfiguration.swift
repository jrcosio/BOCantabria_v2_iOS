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
//  La costura está **acotada a propósito**. Hoy tiene dos argumentos y no son lo mismo:
//
//  - `-boc-content-scenario=` elige entre escenarios del origen de ejemplo de la feature 001, que
//    es material desechable. **Ese se sustituye, no se amplía**, cuando la feature del boletín
//    traiga el origen real.
//  - `-boc-startup-scenario=` elige el desenlace del arranque (feature 002). Se añadió a sabiendas
//    de la frase anterior, porque FR-028 exige probar los cuatro estados del arranque y tres de
//    ellos no son alcanzables de ninguna otra forma. La desviación está declarada en el
//    *Complexity Tracking* de `specs/002-pantalla-arranque/plan.md`, no escondida aquí.
//
//  Los dos son enumerados y no cadenas, y los dos respaldan en silencio al valor de producción
//  cuando el argumento falta o no casa.
//

import Foundation

enum LaunchConfiguration {
    static let argumentPrefix = "-boc-content-scenario="
    static let startupArgumentPrefix = "-boc-startup-scenario="

    /// El escenario de arranque que pide la prueba de interfaz.
    ///
    /// **Esto amplía la costura que la cabecera de arriba dice que no se amplía, y se hace a
    /// sabiendas.** Aquella frase se escribió pensando en el origen de contenido, y sigue valiendo
    /// para él: ese escenario no se toca y desaparecerá con la feature del boletín. El arranque es
    /// otra cosa —FR-028 exige probar sus cuatro estados y no hay otro mecanismo—, así que la
    /// desviación está declarada en el *Complexity Tracking* del plan de la feature 002 en vez de
    /// colarse sin que nadie la vea.
    static var startupScenario: StartupScenario {
        value(for: startupArgumentPrefix)
            .flatMap { StartupScenario(rawValue: $0) } ?? .ready
    }

    private static func value(for prefix: String) -> String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    static var contentScenario: StubContentRemoteDataSource.Scenario {
        let argument = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix(argumentPrefix) }?
            .dropFirst(argumentPrefix.count)
        return argument
            .flatMap { StubContentRemoteDataSource.Scenario(rawValue: String($0)) }
            ?? .items
    }
}
