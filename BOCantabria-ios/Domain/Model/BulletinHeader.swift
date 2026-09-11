//
//  BulletinHeader.swift
//  Exactly what the editorial header needs, and nothing else.
//

import Foundation

struct BulletinHeader: Sendable, Hashable {
    /// «Boletín de hoy», o el nombre de la sección o subsección elegida.
    let title: String

    /// **Opcional a propósito**: sin fecha no se pinta rótulo (FR-035). Un «Edición del» huérfano
    /// en la primera ejecución sería peor que la fecha desnuda que sustituye.
    let date: BocDate?

    /// El número de publicaciones de la selección. Ocupa el sitio donde el diseño original ponía
    /// un número de boletín, que el servicio **no publica** (FR-036).
    let count: Int

    /// Qué significa la fecha. Son dos cosas distintas y llevan rótulos distintos (FR-034).
    let dateMeaning: DateMeaning

    enum DateMeaning: Sendable, Hashable {
        /// La fecha de la edición publicada.
        case edition
        /// La de la publicación más reciente de la sección, que puede ser de hace años.
        case latestInSection
    }

    static let empty = BulletinHeader(title: "", date: nil, count: 0, dateMeaning: .edition)
}
