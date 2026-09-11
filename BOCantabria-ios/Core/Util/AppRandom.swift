//
//  AppRandom.swift
//  The injectable source of randomness.
//
//  La constitución pide que la aleatoriedad se inyecte, por el mismo motivo que el reloj: una
//  espera con jitter que no se puede predecir es una prueba que no se puede afirmar.
//
//  **Por qué no un `RandomNumberGenerator`.** Su `next()` es `mutating` y el protocolo no es
//  `Sendable`, así que compartir uno entre las tareas de un grupo exigiría un actor o un cerrojo
//  **para producir un número**. Sería un cerrojo global en el camino caliente para decidir un
//  retardo. Una función sin estado es trivialmente `Sendable`, y el doble de prueba es un `struct`
//  de una línea.
//

import Foundation

protocol AppRandom: Sendable {
    /// Un valor en `0..<1`.
    func fraction() -> Double
}

struct SystemRandom: AppRandom {
    func fraction() -> Double {
        // `Double.random(in:)` usa el generador del sistema, que es seguro entre hilos.
        Double.random(in: 0..<1)
    }
}

extension AppRandom {
    /// Aplica jitter a una espera: el valor devuelto está en `±factor` alrededor de `seconds`.
    ///
    /// Sirve para que diecinueve reintentos no vuelvan a caer todos en el mismo instante sobre el
    /// servicio oficial, que es de lo que el jitter protege.
    func jittered(_ seconds: Double, factor: Double = 0.2) -> Double {
        let spread = seconds * factor
        return seconds - spread + fraction() * 2 * spread
    }
}
