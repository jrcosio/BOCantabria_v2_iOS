//
//  BocShape.swift
//  Corner radii and the shapes that have a name of their own.
//
//  Transcrito de `docs/diseno/especificaciones-diseno.md` §8.1.
//

import CoreGraphics
import SwiftUI

struct BocShape: Sendable {
    /// 8 pt.
    let extraSmall: CGFloat
    /// 12 pt · Botón.
    let small: CGFloat
    /// 14 pt · Tarjeta estándar y campo de texto.
    let medium: CGFloat
    /// 18 pt · Tarjeta destacada.
    let large: CGFloat
    /// 28 pt.
    let extraLarge: CGFloat

    /// 24 pt · Diálogo.
    let dialog: CGFloat
    /// 12 pt · Banner.
    let banner: CGFloat
    /// 28 pt, **solo en las esquinas superiores** · Hoja inferior.
    let bottomSheet: CGFloat

    /// Un chip va a radio completo. El documento lo pide así y en SwiftUI eso es una cápsula.
    var chip: Capsule { Capsule() }

    /// La hoja inferior redondea solo por arriba, de ahí que no baste con un radio.
    var bottomSheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: bottomSheet, topTrailingRadius: bottomSheet)
    }
}

extension BocShape {
    static let boc = BocShape(
        extraSmall: 8,
        small: 12,
        medium: 14,
        large: 18,
        extraLarge: 28,
        dialog: 24,
        banner: 12,
        bottomSheet: 28
    )
}
