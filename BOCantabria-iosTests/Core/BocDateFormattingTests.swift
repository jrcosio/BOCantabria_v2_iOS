//
//  BocDateFormattingTests.swift
//
//  Afirma cadenas exactas, y eso solo es honesto si el texto no depende del idioma del
//  dispositivo. Por eso se compone a mano: con el formateador del sistema esta suite pasaría en
//  una máquina y fallaría en otra, que es la peor clase de prueba.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Formato largo en español")
struct BocDateFormattingTests {

    @Test("Los doce meses, con su cadena exacta", arguments: [
        ("2026-01-01", "1 de enero de 2026"),
        ("2026-02-14", "14 de febrero de 2026"),
        ("2026-03-31", "31 de marzo de 2026"),
        ("2026-04-02", "2 de abril de 2026"),
        ("2026-05-09", "9 de mayo de 2026"),
        ("2026-06-30", "30 de junio de 2026"),
        ("2026-07-04", "4 de julio de 2026"),
        ("2026-08-26", "26 de agosto de 2026"),
        ("2026-09-11", "11 de septiembre de 2026"),
        ("2026-10-12", "12 de octubre de 2026"),
        ("2026-11-01", "1 de noviembre de 2026"),
        ("2026-12-25", "25 de diciembre de 2026"),
    ])
    func formatsEveryMonth(iso: String, expected: String) {
        let date = BocDate(iso: iso)
        #expect(date != nil)
        #expect(BocDateFormatting.long(date!) == expected)
    }

    @Test("El día no se rellena con ceros: se lee «1 de enero», no «01 de enero»")
    func theDayIsNotPadded() {
        #expect(BocDateFormatting.long(BocDate(iso: "2026-01-01")!).hasPrefix("1 de"))
    }

    @Test("Son DOS rótulos, porque la fecha significa dos cosas distintas (FR-034)")
    func theTwoLabelsSayDifferentThings() {
        let date = BocDate(iso: "2026-09-04")!
        let edition = BocDateFormatting.labelled(date, meaning: .edition)
        let section = BocDateFormatting.labelled(date, meaning: .latestInSection)
        #expect(edition == "Edición del 4 de septiembre de 2026")
        #expect(section == "Última publicación: 4 de septiembre de 2026")
        #expect(edition != section)
    }

    @Test("Sin fecha no se compone ningún rótulo (FR-035)")
    func noDateMeansNoLabel() {
        // Un «Edición del» huérfano en la primera ejecución sería peor que la fecha desnuda que
        // este rótulo vino a sustituir.
        #expect(BocDateFormatting.labelled(nil, meaning: .edition) == nil)
        #expect(BocDateFormatting.labelled(nil, meaning: .latestInSection) == nil)
    }

    @Test("El recuento estrena el plural del catálogo", arguments: [
        (0, "0 anuncios"), (1, "1 anuncio"), (2, "2 anuncios"), (48, "48 anuncios"),
    ])
    func theCountIsPluralised(count: Int, expected: String) {
        #expect(BocDateFormatting.publicationCount(count) == expected)
    }

    @Test("«Hoy» es el de Madrid, no el del dispositivo")
    func todayFollowsTheBulletinTimeZone() {
        // El BOC publica en España. Con la zona del dispositivo, alguien de viaje vería otro
        // «hoy» y el boletín del día cambiaría de fecha al cruzar un meridiano.
        #expect(BocDate.bulletinTimeZone.identifier == "Europe/Madrid")

        // 26 de agosto de 2026, 23:30 en Madrid. En Auckland ya son las 09:30 del día 27, así
        // que un «hoy» tomado de la zona del dispositivo daría otra fecha y otro boletín.
        let lateInMadrid = Date(timeIntervalSince1970: 1_787_779_800)
        #expect(BocDate.today(ImmediateClock(now: lateInMadrid)).iso == "2026-08-26")

        // Y treinta y un minutos después ya es el 27 en Madrid, que es donde la frontera está.
        let justAfterMidnight = Date(timeIntervalSince1970: 1_787_781_660)
        #expect(BocDate.today(ImmediateClock(now: justAfterMidnight)).iso == "2026-08-27")
    }
}
