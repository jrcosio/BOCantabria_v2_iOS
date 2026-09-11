//
//  BocDate.swift
//  A calendar date with no time and no zone, which is what the bulletin publishes.
//
//  Swift no tiene `LocalDate`, y `Date` **no sirve**: es un instante, así que «2026-08-26» se
//  convertiría en un punto de la línea del tiempo y formatearlo con otra zona mostraría otro día.
//  Es el error clásico del día de más o de menos, y llegaría hasta la cabecera editorial.
//
//  Tampoco sabe formatearse: eso vive en `Core/Util/BocDateFormatting`, y es deliberado. El dato
//  y su presentación no viven juntos, entre otras cosas porque el texto es español fijo y el dato
//  no tiene idioma.
//

import Foundation

struct BocDate: Sendable, Hashable, Comparable, Codable {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard (1583...9999).contains(year), (1...12).contains(month) else { return nil }
        guard (1...Self.daysIn(month: month, year: year)).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Acepta **exactamente** `AAAA-MM-DD`: diez caracteres, tres tramos, todos dígitos ASCII.
    ///
    /// La comprobación de dígitos no es adorno. `Int("+1")` vale 1 y `Int("-1")` vale −1, así que
    /// un parseo ingenuo daría por buena «+2026-08-26». Es la misma trampa que ya cazó
    /// `AppVersion`, y las dos veces la cazó una prueba y no una revisión.
    init?(iso: String) {
        guard iso.count == 10 else { return nil }
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2
        else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part)
            else { return nil }
            numbers.append(number)
        }
        self.init(year: numbers[0], month: numbers[1], day: numbers[2])
    }

    /// La representación que se guarda. Inversa de `init?(iso:)`, y **ordena igual que el
    /// calendario**: por eso la columna es texto y no un entero de días desde una época.
    var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func < (lhs: BocDate, rhs: BocDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: 31
        case 4, 6, 9, 11: 30
        default: isLeap(year) ? 29 : 28
        }
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
