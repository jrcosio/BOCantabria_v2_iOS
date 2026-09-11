//
//  HomeSelectionTests.swift
//
//  Lo que importa aquí es la restauración: es el único camino que nadie recorre a mano, y el que
//  tumbaría Inicio si un código guardado dejara de existir.
//

import Testing
@testable import BOCantabria_ios

@Suite("Selección de Inicio")
struct HomeSelectionTests {

    @Test("El boletín del día no marca ninguna sección y no guarda código")
    func todaysBulletinMarksNothing() {
        let selection = HomeSelection.todaysBulletin
        #expect(selection.topLevelCode == nil)
        #expect(selection.subsectionCode == nil)
        #expect(selection.storedCode == nil)
    }

    @Test("Una sección marca su chip; una subsección marca el suyo y el de su madre")
    func aSubsectionAlsoMarksItsParent() {
        // FR-051: estar en 2.2 es estar en 2, y si la fila de arriba se apagara la segunda
        // parecería no depender de nada.
        let section = HomeSelection.section(code: "2", subsectionCode: nil)
        #expect(section.topLevelCode == "2")
        #expect(section.subsectionCode == nil)

        let subsection = HomeSelection.section(code: "2", subsectionCode: "2.2")
        #expect(subsection.topLevelCode == "2")
        #expect(subsection.subsectionCode == "2.2")
    }

    @Test("Se guarda el código más específico, nunca un índice")
    func storesTheMostSpecificCode() {
        #expect(HomeSelection.section(code: "2", subsectionCode: "2.2").storedCode == "2.2")
        #expect(HomeSelection.section(code: "1", subsectionCode: nil).storedCode == "1")
    }

    @Test("Restaurar resuelve contra el catálogo y reconstruye la madre")
    func restoringResolvesAgainstTheCatalogue() {
        #expect(HomeSelection.restored(from: "2.2") == .section(code: "2", subsectionCode: "2.2"))
        #expect(HomeSelection.restored(from: "7") == .section(code: "7", subsectionCode: nil))
    }

    @Test("Un código guardado que ya no existe cae a «Boletín de hoy», en silencio", arguments: [
        "2.9", "42", "", "todo", "0",
    ])
    func anUnknownStoredCodeFallsBackQuietly(stored: String) {
        // Las subsecciones del BOC pueden cambiar. Restaurar por índice, o con un
        // `init(rawValue:)` sin comprobar, tumbaría Inicio al volver de la muerte del proceso.
        #expect(HomeSelection.restored(from: stored) == .todaysBulletin)
    }

    @Test("Sin nada guardado, el boletín del día")
    func nothingStoredMeansTodaysBulletin() {
        #expect(HomeSelection.restored(from: nil) == .todaysBulletin)
    }
}
