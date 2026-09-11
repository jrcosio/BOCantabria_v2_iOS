//
//  BocElevation.swift
//  Shadow elevation levels.
//
//  Sombras suaves, amplias y de baja opacidad. Se prefiere separar superficies por contraste de
//  fondo antes que apilar sombras, y por eso los niveles se quedan deliberadamente bajos.
//
//  Transcrito de `docs/diseno/especificaciones-diseno.md` §8.2.
//

import CoreGraphics

struct BocElevation: Sendable {
    /// 0 · Fondos y tarjetas delimitadas por borde.
    let level0: CGFloat
    /// 1 · Tarjetas estándar.
    let level1: CGFloat
    /// 3 · Barra inferior y elementos flotantes.
    let level2: CGFloat
    /// 6 · Hojas inferiores y menús.
    let level3: CGFloat
    /// 8 · Diálogos.
    let level4: CGFloat
}

extension BocElevation {
    static let boc = BocElevation(level0: 0, level1: 1, level2: 3, level3: 6, level4: 8)
}
