//
//  AppClock.swift
//  The injectable clock: both waiting and «now».
//
//  Existe para que las pruebas sean deterministas. Referenciar el reloj del sistema dentro de un
//  repositorio hace imposible controlar el tiempo y produce pruebas que esperan de verdad, que es
//  la receta de una suite lenta e intermitente.
//
//  En Swift 6 no hace falta inyectar además un «despachador»: lo que debe salir del actor
//  principal se marca a propósito. Lo único que queda por inyectar es lo que hace no determinista
//  una prueba, y aquí eso es el paso del tiempo.
//
//  **`now()` es síncrono y `nonisolated`, y tiene que serlo.** Comparar dos fechas para decidir si
//  la caché ha caducado no puede contagiar `await` a media aplicación. La consecuencia la paga el
//  doble de prueba, que por eso deja de ser un `actor` (research.md D-317).
//

import Foundation

protocol AppClock: Sendable {
    /// Suspende la tarea actual durante los segundos indicados.
    func sleep(seconds: Double) async throws

    /// El instante actual. Es **reloj de pared**, y tiene que serlo: la marca de la última
    /// sincronización sobrevive a la muerte del proceso, así que no puede medirse contra un reloj
    /// monótono que se reinicia con ella.
    ///
    /// Su contrapartida, decidida a conciencia: si alguien atrasa la hora del dispositivo, el
    /// transcurrido sale negativo. Quien lo consume trata un transcurrido negativo **como
    /// caducado**, no como recién sincronizado; si no, la caché se congelaría hasta que el reloj
    /// alcanzara el valor guardado.
    func now() -> Date
}

struct SystemClock: AppClock {
    func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    func now() -> Date { Date() }
}
