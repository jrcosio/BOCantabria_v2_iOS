//
//  BocTypography.swift
//  The fourteen text styles of the application.
//
//  Una sola familia, la del sistema: el carácter editorial sale de la escala, el peso y el
//  espaciado, no de mezclar fuentes. Transcrito de
//  `docs/diseno/especificaciones-diseno.md` §6.2.
//
//  Dos conversiones que hay que hacer a conciencia, porque se pierden en silencio:
//
//  1. **El espaciado entre letras va a cero en los catorce.** El documento no lo declara y en
//     Android eso deja el valor sin especificar; aquí la fuente del sistema trae el suyo, así que
//     hay que anularlo explícitamente. Si no se hace, la tipografía se parece pero no es la misma
//     y nadie sabrá decir por qué.
//  2. **El interlineado del documento es la altura TOTAL de la línea**, mientras que SwiftUI pide
//     el espacio ADICIONAL entre líneas. La conversión necesita la altura natural de la fuente a
//     ese tamaño, que solo conoce UIFont. Transcribir la cifra de la tabla directamente a
//     `.lineSpacing()` deja los párrafos muy abiertos.
//

import SwiftUI
import UIKit

/// Un estilo de texto: tamaño, altura de línea y peso.
///
/// Se guarda la altura de línea **total**, como la expresa el documento de diseño, y la
/// conversión al espacio adicional que pide SwiftUI se hace aquí dentro.
struct BocTextStyle: Sendable, Equatable {
    let size: CGFloat
    /// Altura total de la línea, tal como la declara el documento de diseño.
    let lineHeight: CGFloat
    let weight: Font.Weight

    var font: Font { .system(size: size, weight: weight) }

    /// Espacio adicional entre líneas, que es lo que SwiftUI entiende por `lineSpacing`.
    var lineSpacing: CGFloat { max(0, lineHeight - uiFont.lineHeight) }

    /// Cero en los catorce estilos, a propósito. Ver la nota de cabecera.
    var tracking: CGFloat { 0 }

    private var uiFont: UIFont { .systemFont(ofSize: size, weight: weight.uiWeight) }
}

struct BocTypography: Sendable {
    /// 56/64 · Siglas BOC en portada.
    let displayLarge: BocTextStyle
    /// 40/48 · Título editorial excepcional.
    let displaySmall: BocTextStyle
    /// 30/38 · Título de publicación.
    let headlineLarge: BocTextStyle
    /// 26/34 · Título principal de pantalla.
    let headlineMedium: BocTextStyle
    /// 22/28 · Título de bloque.
    let headlineSmall: BocTextStyle
    /// 20/26 · Título de tarjeta destacada.
    let titleLarge: BocTextStyle
    /// 17/23 · Título de publicación en listado.
    let titleMedium: BocTextStyle
    /// 15/20 · Organismos y cabeceras pequeñas.
    let titleSmall: BocTextStyle
    /// 16/24 · Texto principal de lectura.
    let bodyLarge: BocTextStyle
    /// 14/21 · Descripciones y resúmenes.
    let bodyMedium: BocTextStyle
    /// 12/18 · Información auxiliar.
    let bodySmall: BocTextStyle
    /// 14/20 · Botones y pestañas.
    let labelLarge: BocTextStyle
    /// 12/17 · Chips y categorías.
    let labelMedium: BocTextStyle
    /// 11/15 · Metadatos muy breves.
    let labelSmall: BocTextStyle

    /// Los catorce, para poder recorrerlos en una prueba.
    var all: [BocTextStyle] {
        [displayLarge, displaySmall, headlineLarge, headlineMedium, headlineSmall,
         titleLarge, titleMedium, titleSmall,
         bodyLarge, bodyMedium, bodySmall,
         labelLarge, labelMedium, labelSmall]
    }
}

extension BocTypography {
    // Los pesos 650 del documento se implementan como `.semibold` (600), el peso real más
    // cercano: pedir 650 da o el 600 real o un engrosamiento sintético de peor calidad según el
    // dispositivo, y la diferencia es imperceptible en pantalla.
    static let boc = BocTypography(
        displayLarge: BocTextStyle(size: 56, lineHeight: 64, weight: .regular),
        displaySmall: BocTextStyle(size: 40, lineHeight: 48, weight: .regular),
        headlineLarge: BocTextStyle(size: 30, lineHeight: 38, weight: .semibold),
        headlineMedium: BocTextStyle(size: 26, lineHeight: 34, weight: .semibold),
        headlineSmall: BocTextStyle(size: 22, lineHeight: 28, weight: .semibold),
        titleLarge: BocTextStyle(size: 20, lineHeight: 26, weight: .semibold),
        titleMedium: BocTextStyle(size: 17, lineHeight: 23, weight: .semibold),
        titleSmall: BocTextStyle(size: 15, lineHeight: 20, weight: .semibold),
        bodyLarge: BocTextStyle(size: 16, lineHeight: 24, weight: .regular),
        bodyMedium: BocTextStyle(size: 14, lineHeight: 21, weight: .regular),
        bodySmall: BocTextStyle(size: 12, lineHeight: 18, weight: .regular),
        labelLarge: BocTextStyle(size: 14, lineHeight: 20, weight: .semibold),
        labelMedium: BocTextStyle(size: 12, lineHeight: 17, weight: .semibold),
        labelSmall: BocTextStyle(size: 11, lineHeight: 15, weight: .semibold)
    )
}

private extension Font.Weight {
    /// `Font.Weight` no expone su valor, así que la correspondencia se escribe a mano. Solo se
    /// necesitan los pesos que el sistema de diseño usa.
    var uiWeight: UIFont.Weight {
        switch self {
        case .semibold: .semibold
        default: .regular
        }
    }
}

extension View {
    /// Aplica un estilo del sistema de diseño: fuente, interlineado y espaciado entre letras.
    ///
    /// Se aplican los tres juntos a propósito. Poner solo la fuente deja el interlineado del
    /// sistema y el tracking de la fuente, que es exactamente el fallo silencioso que la nota de
    /// cabecera describe.
    func bocTextStyle(_ style: BocTextStyle) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
