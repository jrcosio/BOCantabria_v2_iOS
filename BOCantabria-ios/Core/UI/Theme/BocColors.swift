//
//  BocColors.swift
//  The colour tokens of the application.
//
//  Los nombres describen el PAPEL, nunca la apariencia: `primary`, jamás `blue`. Un token
//  sobrevive a un cambio de tono; un nombre de color se convierte en mentira la primera vez que
//  se revisa la paleta.
//
//  Este es el ÚNICO fichero del proyecto que construye un color, y hay una regla de arquitectura
//  que falla la build si alguien lo hace fuera de aquí.
//
//  Valores transcritos de `docs/diseno/especificaciones-diseno.md` §4.1. Si algo no coincide,
//  manda el documento. Los cinco colores de sección del boletín quedan fuera a propósito
//  (research.md D-111): dependen de una clasificación del dominio que aún no existe.
//

import SwiftUI

struct BocColors: Sendable {
    // Identidad institucional
    let primary: Color
    let onPrimary: Color
    let primaryPressed: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondary: Color
    let secondaryPressed: Color
    let secondaryContainer: Color

    // Acentos
    let accentOfficial: Color
    let aiAccent: Color
    let aiContainer: Color

    // Superficies
    let background: Color
    let surface: Color
    let surfaceSoft: Color
    let surfaceStrong: Color
    let readerSurface: Color

    // Texto y trazos
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let outline: Color
    let divider: Color

    // Estados
    let success: Color
    let warning: Color
    let error: Color

    // Sobre el azul institucional
    let onPrimaryAccent: Color
    let onPrimaryMuted: Color
}

extension BocColors {
    static let boc = BocColors(
        primary: Color(hex: 0x063B5C),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryPressed: Color(hex: 0x042C45),
        primaryContainer: Color(hex: 0xDCEEF6),
        onPrimaryContainer: Color(hex: 0x082F45),
        secondary: Color(hex: 0x087EA4),
        secondaryPressed: Color(hex: 0x056686),
        secondaryContainer: Color(hex: 0xDDF3FA),

        accentOfficial: Color(hex: 0xC62828),
        aiAccent: Color(hex: 0x6650A4),
        aiContainer: Color(hex: 0xF1EDFA),

        background: Color(hex: 0xF6F8FA),
        surface: Color(hex: 0xFFFFFF),
        surfaceSoft: Color(hex: 0xF0F4F7),
        surfaceStrong: Color(hex: 0xE6EDF1),
        readerSurface: Color(hex: 0xD9DEE2),

        textPrimary: Color(hex: 0x122B3A),
        textSecondary: Color(hex: 0x536873),
        textMuted: Color(hex: 0x778993),
        outline: Color(hex: 0xB8C4CB),
        divider: Color(hex: 0xD9E0E4),

        success: Color(hex: 0x2E7D32),
        warning: Color(hex: 0xED6C02),
        error: Color(hex: 0xBA1A1A),

        onPrimaryAccent: Color(hex: 0x8FD3EE),
        // Blanco con alfa 0xB3 = 179/255 = 70,2 %.
        onPrimaryMuted: Color(hex: 0xFFFFFF, opacity: 179.0 / 255.0)
    )
}

extension Color {
    /// Construye un color desde su valor hexadecimal en sRGB.
    ///
    /// Es `fileprivate` a propósito: mantiene la construcción de colores encerrada en este
    /// fichero, que es lo que la regla de arquitectura protege.
    fileprivate init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
