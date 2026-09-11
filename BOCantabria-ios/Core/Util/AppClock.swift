//
//  AppClock.swift
//  The injectable clock.
//
//  Existe para que las pruebas sean deterministas. Referenciar el reloj del sistema dentro de un
//  repositorio hace imposible controlar el tiempo y produce pruebas que esperan de verdad, que es
//  la receta de una suite lenta e intermitente.
//
//  En Swift 6 no hace falta inyectar además un «despachador»: con el aislamiento por defecto en el
//  actor principal, lo que debe salir de él se marca a propósito. Lo único que queda por inyectar
//  es lo que hace no determinista una prueba, y aquí eso es el paso del tiempo.
//

import Foundation

protocol AppClock: Sendable {
    /// Suspende la tarea actual durante los segundos indicados.
    func sleep(seconds: Double) async throws
}

struct SystemClock: AppClock {
    func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
