//
//  UserDefaultsSelectionStoreTests.swift
//
//  El caso que importa es el que nadie recorre a mano: volver de la muerte del proceso con un
//  código guardado que ya no existe.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Almacén de la selección")
struct UserDefaultsSelectionStoreTests {

    private func makeStore() -> (UserDefaultsSelectionStore, UserDefaults) {
        let suite = "boc-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (UserDefaultsSelectionStore(defaults: defaults), defaults)
    }

    @Test("Sin nada guardado, el boletín del día")
    func nothingStoredMeansTodaysBulletin() {
        let (store, _) = makeStore()
        #expect(store.load() == .todaysBulletin)
    }

    @Test("Guarda y recupera una sección, y una subsección con su madre")
    func savesAndRestores() {
        let (store, _) = makeStore()

        store.save(.section(code: "7", subsectionCode: nil))
        #expect(store.load() == .section(code: "7", subsectionCode: nil))

        store.save(.section(code: "2", subsectionCode: "2.2"))
        #expect(store.load() == .section(code: "2", subsectionCode: "2.2"))
    }

    @Test("Volver al boletín del día borra lo guardado")
    func todaysBulletinClearsTheStoredValue() {
        let (store, defaults) = makeStore()
        store.save(.section(code: "1", subsectionCode: nil))
        store.save(.todaysBulletin)
        #expect(defaults.string(forKey: UserDefaultsSelectionStore.key) == nil)
        #expect(store.load() == .todaysBulletin)
    }

    @Test("Un código guardado que ya no existe cae a «Boletín de hoy», en silencio", arguments: [
        "2.9", "42", "", "todo", "0",
    ])
    func anUnknownCodeFallsBackQuietly(stored: String) {
        // Es literalmente el caso de «Preguntar fue pestaña y hoy es pantalla»: restaurar por
        // índice, o con un `init(rawValue:)` sin comprobar, tumbaría Inicio al volver de la muerte
        // del proceso, en el único camino que nadie recorre a mano.
        let (store, defaults) = makeStore()
        defaults.set(stored, forKey: UserDefaultsSelectionStore.key)
        #expect(store.load() == .todaysBulletin)
    }

    @Test("Las preferencias leen el dominio de argumentos, y eso no es costura de producción")
    func theArgumentDomainIsReadableWithoutASeam() {
        // Es lo que permite a una prueba de interfaz sembrar la selección al lanzar sin tocar una
        // línea de la aplicación, y hace la suite independiente del orden.
        let defaults = UserDefaults(suiteName: "boc-args-\(UUID().uuidString)")!
        defaults.set("4.3", forKey: UserDefaultsSelectionStore.key)
        let store = UserDefaultsSelectionStore(defaults: defaults)
        #expect(store.load() == .section(code: "4", subsectionCode: "4.3"))
    }
}
