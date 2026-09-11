//
//  AppVersion.swift
//  The application version, in the form a person recognises in the store.
//
//  Es un **valor**, no un servicio: quién lo lee del paquete es asunto del composition root
//  (`Core/Util/AppInfo`). Aquí no puede saberse que existe un paquete, porque este tipo es Swift
//  puro y así se prueba sin simulador.
//

import Foundation

struct AppVersion: Comparable, Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    /// «Todo permitido». Nunca es mayor que ninguna versión instalada real.
    static let zero = AppVersion(major: 0, minor: 0, patch: 0)

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Acepta «1», «1.0» y «1.0.0», completando con ceros lo que falte.
    ///
    /// **Devuelve `nil` ante cualquier otra cosa**, y esa nulidad es justamente la que la capa de
    /// datos traduce en «no bloquea» (FR-015): una versión mínima que no se entiende no puede
    /// dejar a nadie fuera de una publicación oficial.
    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }

        var numbers: [Int] = []
        for part in parts {
            // Solo dígitos ASCII. `Int(_:)` por sí solo acepta demasiado: «+1» vale 1 y «-1» vale
            // −1, así que «+1.0.0» pasaría por una versión. Y `Character.isNumber` daría por
            // bueno un dígito arábigo-índico, que aquí no es un número de versión sino un texto
            // que nadie ha publicado a propósito.
            guard part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part)
            else { return nil }
            numbers.append(number)
        }

        self.init(
            major: numbers[0],
            minor: numbers.count > 1 ? numbers[1] : 0,
            patch: numbers.count > 2 ? numbers[2] : 0
        )
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
