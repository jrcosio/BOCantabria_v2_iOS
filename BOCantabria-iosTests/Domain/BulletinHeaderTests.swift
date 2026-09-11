//
//  BulletinHeaderTests.swift
//
//  La cabecera lleva una regla que parece un detalle y no lo es: la fecha es **opcional**, y de
//  eso depende que no aparezca un «Edición del» huérfano en la primera ejecución.
//

import Testing
@testable import BOCantabria_ios

@Suite("Cabecera editorial")
struct BulletinHeaderTests {

    @Test("Sin fecha es un estado legítimo, no un error")
    func aHeaderWithoutADateIsLegitimate() {
        let header = BulletinHeader(title: "Boletín de hoy", date: nil, count: 0, dateMeaning: .edition)
        #expect(header.date == nil)
        #expect(BocDateFormatting.labelled(header.date, meaning: header.dateMeaning) == nil)
    }

    @Test("El significado de la fecha decide el rótulo, y son dos")
    func theMeaningPicksTheLabel() {
        let date = BocDate(iso: "2026-09-04")!
        let bulletin = BulletinHeader(title: "Boletín de hoy", date: date, count: 48, dateMeaning: .edition)
        let section = BulletinHeader(title: "Personal", date: date, count: 336, dateMeaning: .latestInSection)
        #expect(BocDateFormatting.labelled(bulletin.date, meaning: bulletin.dateMeaning)?.hasPrefix("Edición del") == true)
        #expect(BocDateFormatting.labelled(section.date, meaning: section.dateMeaning)?.hasPrefix("Última publicación:") == true)
    }

    @Test("La cabecera vacía no dice nada y no cuenta nada")
    func theEmptyHeaderIsQuiet() {
        #expect(BulletinHeader.empty.title.isEmpty)
        #expect(BulletinHeader.empty.count == 0)
        #expect(BulletinHeader.empty.date == nil)
    }
}
