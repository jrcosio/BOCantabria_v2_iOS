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
    /// Espaciado adicional entre letras.
    ///
    /// **Cero en los catorce estilos del §6.2, a propósito** — ver la nota 1 de la cabecera—. Deja
    /// de ser una constante porque el §13.2 sí declara espaciado para la denominación de la
    /// portada, que es el único estilo del proyecto que lo lleva.
    let tracking: CGFloat

    /// El estilo del sistema al que este token **se ancla para escalar**.
    ///
    /// Hace falta porque `Font.system(size:)` da un tamaño **fijo**: no responde al ajuste de
    /// tamaño de letra del dispositivo. En Android no había que decidir nada —`sp` escala por su
    /// cuenta— y al portar la tabla tal cual el texto dejó de crecer sin que nada fallara. Lo cazó
    /// la prueba de interfaz que mide la altura de la tarjeta al 200 %: era **exactamente la
    /// misma** que al 100 %.
    let relativeTo: Font.TextStyle

    init(
        size: CGFloat,
        lineHeight: CGFloat,
        weight: Font.Weight,
        tracking: CGFloat = 0,
        relativeTo: Font.TextStyle = .body
    ) {
        self.size = size
        self.lineHeight = lineHeight
        self.weight = weight
        self.tracking = tracking
        self.relativeTo = relativeTo
    }

    /// La fuente **escalable**. `Font.custom` con el nombre vacío usa la del sistema y, con
    /// `relativeTo:`, escala con el ajuste del dispositivo; `Font.system(size:)` no.
    var font: Font { .custom("", size: size, relativeTo: relativeTo).weight(weight) }

    /// La fuente de tamaño fijo, para lo que no debe crecer.
    var fixedFont: Font { .system(size: size, weight: weight) }

    /// Espacio adicional entre líneas, que es lo que SwiftUI entiende por `lineSpacing`.
    ///
    /// Se declara sobre el tamaño nominal: al crecer la letra, SwiftUI ya reparte el suyo, y
    /// escalar además este valor separaría las líneas el doble.
    var lineSpacing: CGFloat { max(0, lineHeight - uiFont.lineHeight) }

    private var uiFont: UIFont { .systemFont(ofSize: size, weight: weight.uiWeight) }
}

/// Los tres estilos que el apartado 13.2 del documento de diseño define **solo** para la portada.
///
/// Viven aparte de los catorce del apartado 6.2 y no entran en su escala: aquel apartado es una
/// tabla cerrada y este fichero dice en su cabecera que la transcribe. Meterlos dentro haría que
/// esa afirmación dejara de ser cierta. Están aquí, y no escritos en la vista, porque la
/// convención del proyecto es que ningún tamaño ni ningún espaciado se escriba a mano fuera del
/// tema.
struct BocSplashTypography: Sendable {
    /// 20/26 · `BOLETÍN OFICIAL` y `DE CANTABRIA`, con espaciado amplio.
    let subtitle: BocTextStyle
    /// 13/18 · «Diseñada y desarrollada por».
    let authorshipLabel: BocTextStyle
    /// 15/20 · «José Ramón Blanco Gutiérrez».
    let authorshipName: BocTextStyle

    /// Los tres, para poder recorrerlos en una prueba.
    var all: [BocTextStyle] { [subtitle, authorshipLabel, authorshipName] }
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

    /// Los tres estilos propios de la portada (§13.2). **No entran en `all`.**
    let splash: BocSplashTypography

    /// Los catorce del §6.2, para poder recorrerlos en una prueba.
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
        displayLarge: BocTextStyle(size: 56, lineHeight: 64, weight: .regular, relativeTo: .largeTitle),
        displaySmall: BocTextStyle(size: 40, lineHeight: 48, weight: .regular, relativeTo: .largeTitle),
        headlineLarge: BocTextStyle(size: 30, lineHeight: 38, weight: .semibold, relativeTo: .title),
        headlineMedium: BocTextStyle(size: 26, lineHeight: 34, weight: .semibold, relativeTo: .title2),
        headlineSmall: BocTextStyle(size: 22, lineHeight: 28, weight: .semibold, relativeTo: .title3),
        titleLarge: BocTextStyle(size: 20, lineHeight: 26, weight: .semibold, relativeTo: .title3),
        titleMedium: BocTextStyle(size: 17, lineHeight: 23, weight: .semibold, relativeTo: .headline),
        titleSmall: BocTextStyle(size: 15, lineHeight: 20, weight: .semibold, relativeTo: .subheadline),
        bodyLarge: BocTextStyle(size: 16, lineHeight: 24, weight: .regular, relativeTo: .body),
        bodyMedium: BocTextStyle(size: 14, lineHeight: 21, weight: .regular, relativeTo: .body),
        bodySmall: BocTextStyle(size: 12, lineHeight: 18, weight: .regular, relativeTo: .footnote),
        labelLarge: BocTextStyle(size: 14, lineHeight: 20, weight: .semibold, relativeTo: .subheadline),
        labelMedium: BocTextStyle(size: 12, lineHeight: 17, weight: .semibold, relativeTo: .caption),
        labelSmall: BocTextStyle(size: 11, lineHeight: 15, weight: .semibold, relativeTo: .caption2),
        splash: BocSplashTypography(
            // El documento pide «tracking amplio» sin dar una cifra. Dos puntos sobre veinte es
            // un diez por ciento del cuerpo, que es lo que se ve en la imagen de referencia. Se
            // comprueba comparando la captura con ella (quickstart, paso 8a), no de memoria.
            subtitle: BocTextStyle(size: 20, lineHeight: 26, weight: .medium, tracking: 2),
            authorshipLabel: BocTextStyle(size: 13, lineHeight: 18, weight: .regular),
            authorshipName: BocTextStyle(size: 15, lineHeight: 20, weight: .semibold)
        )
    )
}

private extension Font.Weight {
    /// `Font.Weight` no expone su valor, así que la correspondencia se escribe a mano. Solo se
    /// necesitan los pesos que el sistema de diseño usa.
    var uiWeight: UIFont.Weight {
        switch self {
        case .semibold: .semibold
        case .medium: .medium
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
    /// - Parameter scales: si el texto crece con el ajuste de tamaño de letra del dispositivo.
    ///   **Cierto salvo en la portada**, que es una composición fija verificada contra una imagen
    ///   de referencia: si su denominación creciera, dejaría de ser esa imagen.
    func bocTextStyle(_ style: BocTextStyle, scales: Bool = true) -> some View {
        self
            .font(scales ? style.font : style.fixedFont)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
