//
//  BocThemeTests.swift
//
//  El sistema de diseño es una transcripción del documento, así que lo que hay que proteger es
//  que **siga siendo esa transcripción**. Las dos afirmaciones que de verdad importan son las dos
//  que se pierden en silencio: el espaciado entre letras y la escala de espaciado.
//

import SwiftUI
import Testing
@testable import BOCantabria_ios

@Suite("Sistema de diseño")
struct BocThemeTests {

    @Test("Ningún estilo tipográfico lleva espaciado entre letras")
    func noTextStyleHasTracking() {
        // Es la trampa número uno del port: SwiftUI aplica el tracking de la fuente del sistema, y
        // si no se anula la tipografía se parece pero no es la misma. Nadie sabría decir por qué.
        for style in BocTheme.typography.all {
            #expect(style.tracking == 0)
        }
    }

    @Test("Son catorce estilos, con los tamaños del documento")
    func hasTheFourteenStyles() {
        #expect(BocTheme.typography.all.count == 14)
        #expect(BocTheme.typography.displayLarge.size == 56)
        #expect(BocTheme.typography.titleMedium.size == 17)
        #expect(BocTheme.typography.labelSmall.size == 11)
    }

    @Test("El interlineado se convierte a espacio adicional, nunca se copia tal cual")
    func lineSpacingIsAdditive() {
        // El documento da la altura TOTAL de línea y SwiftUI pide el espacio ENTRE líneas.
        // Copiarla tal cual dejaría los párrafos muy abiertos.
        let style = BocTheme.typography.bodyLarge
        #expect(style.lineHeight == 24)
        #expect(style.lineSpacing < style.lineHeight)
        #expect(style.lineSpacing >= 0)
    }

    @Test("Los pesos son regular o semibold, nunca un 650 sintético")
    func weightsAreRealOnes() {
        for style in BocTheme.typography.all {
            #expect(style.weight == .regular || style.weight == .semibold)
        }
    }

    @Test("La escala de espaciado es la del documento, toda múltiplo de cuatro")
    func spacingScaleMatchesTheDocument() {
        let spacing = BocTheme.spacing
        let values = [spacing.xxs, spacing.xs, spacing.sm, spacing.md,
                      spacing.ml, spacing.lg, spacing.xl, spacing.xxl, spacing.xxxl]

        #expect(values == [4, 8, 12, 16, 20, 24, 32, 40, 48])
        #expect(values.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
        #expect(spacing.screenMargin == spacing.md)
    }

    @Test("Los radios y las elevaciones son los del documento")
    func shapesAndElevationsMatchTheDocument() {
        #expect([BocTheme.shape.extraSmall, BocTheme.shape.small, BocTheme.shape.medium,
                 BocTheme.shape.large, BocTheme.shape.extraLarge] == [8, 12, 14, 18, 28])
        #expect([BocTheme.shape.dialog, BocTheme.shape.banner, BocTheme.shape.bottomSheet] == [24, 12, 28])
        #expect([BocTheme.elevation.level0, BocTheme.elevation.level1, BocTheme.elevation.level2,
                 BocTheme.elevation.level3, BocTheme.elevation.level4] == [0, 1, 3, 6, 8])
    }

    @Test("El color de acento del catálogo sigue siendo el institucional")
    func accentColourStaysInSync() {
        // `AccentColor` lo consume el sistema antes de que exista BocTheme, así que es una copia
        // del mismo valor y hay que vigilar que no se separen.
        #expect(Color("AccentColor", bundle: .main).resolve(in: .init()) == BocTheme.colors.primary.resolve(in: .init()))
    }
}
