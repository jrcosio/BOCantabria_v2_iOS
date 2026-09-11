//
//  LaunchConfiguration.swift
//  Launch-time configuration read from the process arguments.
//
//  **Existe porque en iOS las pruebas de interfaz corren en otro proceso.** En el proyecto Android
//  bastaba con sustituir módulos del grafo desde el propio test; aquí no hay forma de inyectar
//  nada en la aplicación bajo prueba, así que el único mecanismo es pasarle argumentos al
//  lanzarla.
//
//  **La costura está acotada, y la promesa se ha cumplido.** La feature 001 escribió que
//  `-boc-content-scenario=` —el que elegía entre escenarios del origen de ejemplo— «se sustituye,
//  no se amplía, cuando la feature del boletín traiga el origen real». La feature 003 es ésa, y
//  ese argumento **ha desaparecido**: su sitio lo ocupa `-boc-data-scenario=`, que siembra la base
//  con un conjunto determinista. Siguen siendo dos argumentos, los mismos que había.
//
//  Los dos son enumerados y no cadenas, y los dos respaldan en silencio al valor de producción
//  cuando el argumento falta o no casa.
//
import Foundation

enum LaunchConfiguration {
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

}
