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

    @Test("Ninguno de los catorce estilos del §6.2 lleva espaciado entre letras")
    func noScaleTextStyleHasTracking() {
        // Es la trampa número uno del port: SwiftUI aplica el tracking de la fuente del sistema, y
        // si no se anula la tipografía se parece pero no es la misma. Nadie sabría decir por qué.
        //
        // La afirmación es ahora sobre la escala del §6.2, no sobre todos los estilos: el §13.2
        // declara espaciado para la denominación de la portada, y esa excepción se comprueba
        // abajo. Debilitar esta prueba a «casi ninguno» habría dejado pasar el caso contrario.
        for style in BocTheme.typography.all {
            #expect(style.tracking == 0)
        }
    }

    @Test("La denominación de la portada es el único estilo con espaciado, y el §13.2 lo pide")
    func onlyTheSplashSubtitleHasTracking() {
        let splash = BocTheme.typography.splash
        #expect(splash.subtitle.tracking > 0, "El §13.2 pide espaciado amplio en la denominación.")
        #expect(splash.authorshipLabel.tracking == 0)
        #expect(splash.authorshipName.tracking == 0)
    }

    @Test("Los tres estilos de la portada son los del §13.2")
    func splashStylesMatchTheDesignDocument() {
        let splash = BocTheme.typography.splash
        #expect(splash.all.count == 3)
        #expect(splash.subtitle.size == 20)
        #expect(splash.subtitle.weight == .medium)
        #expect(splash.authorshipLabel.size == 13)
        #expect(splash.authorshipLabel.weight == .regular)
        #expect(splash.authorshipName.size == 15)
        #expect(splash.authorshipName.weight == .semibold)
    }

    @Test("Los estilos de la portada no entran en la escala de catorce")
    func splashStylesAreNotPartOfTheScale() {
        // Si alguien los añadiera a `all`, la prueba de los catorce y la de los pesos empezarían
        // a hablar de una tabla que el documento no tiene.
        //
        // No vale comprobarlo por identidad de valores: el nombre del autor es 15/20 semibold,
        // exactamente igual que `titleSmall`, y `BocTextStyle` compara por valor. Lo que sí
        // distingue a la escala es que **ningún** estilo suyo lleva espaciado, y que son catorce.
        #expect(BocTheme.typography.all.count == 14)
        #expect(BocTheme.typography.all.allSatisfy { $0.tracking == 0 })
        #expect(!BocTheme.typography.all.contains(BocTheme.typography.splash.subtitle))
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

    @Test("Los cinco colores de sección son los del §4.4, y el velo es nuestro")
    func sectionColoursMatchTheDocument() {
        let environment = EnvironmentValues()
        let expected: [(Color, UInt32)] = [
            (BocTheme.colors.sectionGeneral, 0x1565C0),
            (BocTheme.colors.sectionPersonnel, 0x6A4C93),
            (BocTheme.colors.sectionContracting, 0x00838F),
            (BocTheme.colors.sectionEconomy, 0x2E7D32),
            (BocTheme.colors.sectionAnnouncements, 0xAD5B00),
        ]
        for (token, hex) in expected {
            let resolved = token.resolve(in: environment)
            let actual = (UInt32(round(resolved.red * 255)) << 16)
                | (UInt32(round(resolved.green * 255)) << 8)
                | UInt32(round(resolved.blue * 255))
            #expect(actual == hex)
        }

        // El velo no está en el documento: allí el panel lo pintaba un componente del sistema.
        // Aquí se construye a mano, así que el velo es una decisión nuestra (D-319).
        #expect(BocTheme.colors.scrim.resolve(in: environment).opacity < 1)
    }

    @Test("Ningún token tiene variante oscura: la aplicación tiene un solo aspecto")
    func noTokenHasADarkVariant() {
        // FR-080. La regla 8 impide que alguien lea el ajuste del sistema; esto comprueba la otra
        // mitad: que el valor resuelto no dependa del esquema en el que se resuelva.
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        let light = EnvironmentValues()
        for token in [BocTheme.colors.primary, BocTheme.colors.background, BocTheme.colors.surface,
                      BocTheme.colors.textPrimary, BocTheme.colors.sectionGeneral] {
            #expect(token.resolve(in: light) == token.resolve(in: dark))
        }
    }

    @Test("El color de acento del catálogo sigue siendo el institucional")
    func accentColourStaysInSync() {
        // `AccentColor` lo consume el sistema antes de que exista BocTheme, así que es una copia
        // del mismo valor y hay que vigilar que no se separen.
        #expect(Color("AccentColor", bundle: .main).resolve(in: .init()) == BocTheme.colors.primary.resolve(in: .init()))
    }
}
