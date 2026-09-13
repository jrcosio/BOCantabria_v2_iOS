//
//  DetailTabTests.swift
//
//  **El caso que importa es `"ask"`.** Fue pestaña y hoy es pantalla propia. Un valor guardado que
//  ya no existe tumbaría el detalle al volver de la muerte del proceso, en el único camino que
//  nadie recorre a mano.
//

import Testing
@testable import BOCantabria_ios

@Suite("Pestaña del detalle")
struct DetailTabTests {

    @Test("Son dos, no tres")
    func thereAreTwoOfThem() {
        #expect(DetailTab.allCases.count == 2)
        #expect(DetailTab.allCases == [.document, .aiSummary])
    }

    @Test("Una pestaña guardada se restaura por su nombre")
    func aStoredTabIsRestoredByName() {
        #expect(DetailTab.restored(from: "document") == .document)
        #expect(DetailTab.restored(from: "aiSummary") == .aiSummary)
    }

    @Test(
        "Un valor que ya no existe cae en el respaldo en vez de tumbar la pantalla",
        arguments: ["ask", "", "AISUMMARY", "documento", "0", "1"]
    )
    func aRetiredValueFallsBackInsteadOfCrashing(_ raw: String) {
        // `"ask"` no es un valor inventado: **fue** la tercera pestaña. Es exactamente el caso que
        // se da al actualizar la aplicación con el detalle abierto.
        #expect(DetailTab.restored(from: raw) == .document)
    }
}
