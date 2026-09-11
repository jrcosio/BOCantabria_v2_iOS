//
//  BocDateFormatting.swift
//  Long Spanish dates, composed by hand.
//
//  **Por qué no el formateador del sistema.** Usa el idioma del dispositivo: en un simulador en
//  inglés «26 de agosto de 2026» sale «August 26, 2026», y la prueba que afirma la cadena pasa o
//  falla según la máquina. FR-087 lo prohíbe expresamente. Fijar el idioma en el formateador
//  tampoco vale: obligaría a construir un instante desde un `BocDate` —reintroduciendo la zona que
//  el tipo existe para quitar— y ataría el texto a unos datos de internacionalización que cambian
//  entre versiones del sistema.
//
//  Componerlo a mano cuesta doce claves en el catálogo y hace la función pura. La aplicación es
//  monolingüe y los textos vienen del Android, así que no se pierde nada.
//

import Foundation

enum BocDateFormatting {
    /// «26 de agosto de 2026».
    static func long(_ date: BocDate) -> String {
        let month = String(localized: Strings.Dates.month(date.month))
        return String(localized: Strings.Dates.long(day: date.day, month: month, year: date.year))
    }

    /// La fecha **con su rótulo**, que son dos porque significa dos cosas distintas (FR-034).
    ///
    /// Devuelve `nil` cuando no hay fecha: sin fecha no se pinta rótulo (FR-035), y un «Edición
    /// del» huérfano en la primera ejecución sería peor que la fecha desnuda que sustituye.
    static func labelled(_ date: BocDate?, meaning: BulletinHeader.DateMeaning) -> String? {
        guard let date else { return nil }
        let text = long(date)
        return switch meaning {
        case .edition: String(localized: Strings.Home.editionDate(text))
        case .latestInSection: String(localized: Strings.Home.latestPublicationDate(text))
        }
    }

    /// El recuento de anuncios, con su plural.
    static func publicationCount(_ count: Int) -> String {
        String(localized: Strings.Home.publicationCount(count))
    }
}

// MARK: - Qué día es hoy

extension BocDate {
    /// La zona del boletín. **Fija, no la del dispositivo**: el BOC publica en España, y con la
    /// zona del dispositivo alguien de viaje vería otro «hoy».
    static let bulletinTimeZone = TimeZone(identifier: "Europe/Madrid") ?? .gmt

    /// El día de hoy según el reloj inyectado. Vive en `Core/Util` porque es lo único de este
    /// fichero que necesita un calendario, y la regla 11 encierra los calendarios aquí.
    static func today(_ clock: AppClock) -> BocDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bulletinTimeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: clock.now())
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let date = BocDate(year: year, month: month, day: day)
        else {
            // Inalcanzable con un calendario gregoriano y una fecha real. Si llegara aquí, la
            // fecha más antigua que el tipo admite es menos dañina que un cierre inesperado.
            return BocDate(year: 1583, month: 1, day: 1)!
        }
        return date
    }
}
