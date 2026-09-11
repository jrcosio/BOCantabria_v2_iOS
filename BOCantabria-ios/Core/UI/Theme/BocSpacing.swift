//
//  BocSpacing.swift
//  The spacing scale. Base unit: 4 points; every value is a multiple of it.
//
//  Valores con nombre en lugar de literales, para que un layout se lea como intención
//  —«separación de sección»— y para que revisar la retícula sea una edición aquí y no una
//  cacería por cada pantalla.
//
//  Transcrito de `docs/diseno/especificaciones-diseno.md` §7.
//

import CoreGraphics

struct BocSpacing: Sendable {
    /// 4 · Ajustes mínimos.
    let xxs: CGFloat
    /// 8 · Separación entre icono y texto.
    let xs: CGFloat
    /// 12 · Espaciado interno compacto.
    let sm: CGFloat
    /// 16 · Margen estándar y relleno de tarjetas.
    let md: CGFloat
    /// 20 · Separación de bloques relacionados.
    let ml: CGFloat
    /// 24 · Separación de secciones.
    let lg: CGFloat
    /// 32 · Separación grande.
    let xl: CGFloat
    /// 40 · Áreas editoriales.
    let xxl: CGFloat
    /// 48 · Grandes zonas de respiración.
    let xxxl: CGFloat

    /// Margen lateral de pantalla. El documento define además 20 para teléfono grande y 32 para
    /// tableta; no se implementan porque la aplicación es solo iPhone.
    var screenMargin: CGFloat { md }
}

extension BocSpacing {
    static let boc = BocSpacing(
        xxs: 4, xs: 8, sm: 12, md: 16, ml: 20, lg: 24, xl: 32, xxl: 40, xxxl: 48
    )
}
