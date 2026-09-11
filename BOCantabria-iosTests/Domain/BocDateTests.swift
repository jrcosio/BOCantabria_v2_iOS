//
//  BocDateTests.swift
//
//  Lo que de verdad hay que proteger aquí es el rechazo, no la aceptación: un parseo ingenuo
//  acepta demasiado y el resultado no se ve hasta que una publicación aparece con la fecha
//  equivocada, que es justo lo que nadie mira.
//

import Testing
@testable import BOCantabria_ios

@Suite("Fecha del boletín")
struct BocDateTests {

    @Test("Acepta el formato del servicio y va y vuelve")
    func parsesTheServiceFormat() {
        let date = BocDate(iso: "2026-08-26")
        #expect(date?.year == 2026)
        #expect(date?.month == 8)
        #expect(date?.day == 26)
        #expect(date?.iso == "2026-08-26")
    }

    @Test("Rechaza todo lo que no es exactamente AAAA-MM-DD", arguments: [
        "+2026-08-26",   // `Int("+1")` vale 1: sin comprobar dígitos, esto pasaría
        "-2026-08-26",
        "2026-8-26",     // sin relleno
        "26-08-26",      // año de dos cifras
        "2026-13-01",    // mes trece
        "2026-00-10",    // mes cero
        "2026-02-30",    // treinta de febrero
        "2026-02-29",    // 2026 no es bisiesto
        "2026/08/26",
        "26 de agosto de 2026",
        "2026-08-2 ",
        "",
    ])
    func rejectsEverythingElse(text: String) {
        #expect(BocDate(iso: text) == nil, "«\(text)» no debería interpretarse como fecha")
    }

    @Test("Los años bisiestos son los del calendario, no los del módulo cuatro")
    func leapYearsFollowTheCalendar() {
        #expect(BocDate(iso: "2024-02-29") != nil)
        #expect(BocDate(iso: "2000-02-29") != nil)   // divisible por 400
        #expect(BocDate(iso: "1900-02-29") == nil)   // divisible por 100 y no por 400
    }

    @Test("Ordena como el calendario, que es lo que hace válida la columna de texto")
    func ordersLikeTheCalendar() {
        let dates = ["2026-08-26", "2021-03-26", "2026-08-02", "2025-12-31"]
            .compactMap { BocDate(iso: $0) }
        #expect(dates.count == 4)
        #expect(dates.sorted().map(\.iso) == ["2021-03-26", "2025-12-31", "2026-08-02", "2026-08-26"])
        // Y el orden lexicográfico de `iso` coincide, que es de lo que depende `ORDER BY`.
        #expect(dates.sorted().map(\.iso) == dates.map(\.iso).sorted())
    }
}
