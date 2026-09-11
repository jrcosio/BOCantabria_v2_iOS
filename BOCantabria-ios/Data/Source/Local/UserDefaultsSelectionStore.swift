//
//  UserDefaultsSelectionStore.swift
//  Where the current selection survives the process being killed.
//
//  **Se guarda el código, nunca un índice.** Y al restaurar se resuelve **contra el catálogo**: si
//  no casa, se cae a «Boletín de hoy» en silencio. Las subsecciones del BOC pueden cambiar, y un
//  código guardado que ya no exista tumbaría Inicio en el único camino que nadie recorre a mano.
//
//  Regalo colateral: las preferencias leen el dominio de argumentos por su cuenta, así que una
//  prueba de interfaz puede sembrar la selección al lanzar **sin una línea de costura en
//  producción**. Y resuelve el riesgo contrario: sin ello, una prueba que elige una sección deja
//  el valor puesto y la siguiente arranca contaminada.
//

import Foundation

/// `@unchecked Sendable` con motivo: `UserDefaults` es seguro entre hilos —lo documenta Apple— y
/// sin embargo no está anotado como `Sendable`. Envolverlo en un actor obligaría a que `load()`
/// fuera asíncrona, y entonces restaurar la selección contagiaría `await` al nacimiento del modelo
/// de pantalla.
struct UserDefaultsSelectionStore: HomeSelectionStore, @unchecked Sendable {
    static let key = "home_selection"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HomeSelection {
        HomeSelection.restored(from: defaults.string(forKey: Self.key))
    }

    func save(_ selection: HomeSelection) {
        if let code = selection.storedCode {
            defaults.set(code, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
