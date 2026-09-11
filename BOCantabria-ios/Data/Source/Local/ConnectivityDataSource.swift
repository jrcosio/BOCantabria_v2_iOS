//
//  ConnectivityDataSource.swift
//  Whether the device currently has a usable network path.
//
//  Es una fuente **local** porque no viaja por la red: es información que el dispositivo provee,
//  igual que lo era en la aplicación equivalente de la otra plataforma.
//
//  **Lo que este tipo no puede decir.** Aquella plataforma distinguía una red *con acceso validado
//  a internet* de una interfaz simplemente levantada. El monitor de ésta no expone esa diferencia:
//  dice si hay camino, y un portal cautivo lo tiene. Por eso su resultado solo clasifica el error
//  del arranque —elige cuál de los dos mensajes se muestra— y la comprobación que manda es que la
//  configuración remota se obtenga (research.md D-205).
//

import Foundation
import Network
import Synchronization

protocol ConnectivityDataSource: Sendable {
    func isOnline() async -> Bool
}

/// Caja para el último valor conocido.
///
/// El cerrojo de la biblioteca estándar no es copiable, así que no puede capturarse en el
/// manejador del monitor: se envuelve en una referencia, que sí.
private final class OnlineBox: Sendable {
    private let value = Mutex<Bool?>(nil)

    var current: Bool? { value.withLock { $0 } }

    func set(_ online: Bool) { value.withLock { $0 = online } }
}

final class PathMonitorConnectivityDataSource: ConnectivityDataSource, Sendable {
    private let monitor = NWPathMonitor()
    private let known = OnlineBox()

    init() {
        // **El primer valor llega por el manejador, no está disponible al arrancar el monitor.**
        // Leer `currentPath` justo después de `start` devuelve el estado inicial, que en un
        // dispositivo conectado dice que no hay red. Es un fallo que parece funcionar, porque solo
        // se ve en la primera consulta.
        monitor.pathUpdateHandler = { [known] path in
            known.set(path.status == .satisfied)
        }
        // El monitor del sistema exige una cola de despacho: no hay variante con `async/await`.
        // Es la única de todo el proyecto, y está aquí porque la pide el marco, no porque se
        // use para ordenar trabajo propio.
        monitor.start(queue: DispatchQueue(label: "com.jrblanco.BOCantabria.connectivity"))
    }

    deinit { monitor.cancel() }

    func isOnline() async -> Bool {
        if let current = known.current { return current }
        // Todavía no ha llegado ninguna actualización. En el arranque no ocurre —esto se consulta
        // **después** de que la petición de configuración haya fallado, y para entonces el
        // manejador ya ha corrido—, pero si ocurriera, equivocarse hacia «hay red» solo cambia el
        // mensaje de error. Nunca deja a nadie fuera.
        return monitor.currentPath.status != .unsatisfied
    }
}
