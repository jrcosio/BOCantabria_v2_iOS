//
//  PublicationCardTypographyTests.swift
//  The card's four steps are four different sizes, and none of them was written by hand.
//
//  **Esta prueba es FR-018, y es unitaria a propósito.** La tarjeta se combina en un solo elemento
//  de accesibilidad, de modo que sus cuatro textos no aparecen en el árbol y ninguna prueba de
//  interfaz puede medir sus alturas. Medir aquí comprueba además dos cosas que allí no se verían:
//  el **orden** de la jerarquía y que los cuatro peldaños **pertenecen a la escala** (FR-008).
//
//  Lo que esto impide, y es el motivo de escribirla: igualar dos tokens es un cambio de una línea
//  que nadie ve en una revisión, y dejaría la tarjeta como estaba antes de esta feature.
//

import SwiftUI
import Testing

@testable import BOCantabria_ios

@Suite("Tipografía de la tarjeta")
struct PublicationCardTypographyTests {

    private typealias Card = PublicationCard.Typography

    @Test("Los cuatro peldaños tienen tamaños distintos dos a dos")
    func theFourStepsAreDistinct() {
        let sizes = Card.all.map(\.size)
        let distinct = Set(sizes)
        #expect(
            distinct.count == sizes.count,
            "Los cuatro datos de la tarjeta tienen que distinguirse por tamaño: \(sizes)"
        )
    }

    @Test("La jerarquía va en orden de peso creciente: sección, organismo, título")
    func theHierarchyGrows() {
        let sizes = Card.hierarchy.map(\.size)
        let isAscending = zip(sizes, sizes.dropFirst()).allSatisfy { $0 < $1 }
        #expect(
            isAscending,
            "El orden de lectura tiene que ser visible, no solo estar escrito: \(sizes)"
        )
    }

    @Test("La fecha no baja de doce puntos")
    func theDateStaysReadable() {
        // El apartado 6.3 del documento de diseño: «No usar cuerpos inferiores a 12 sp».
        #expect(Card.date.size >= 12)
    }

    @Test("Los cuatro peldaños salen de la escala de catorce, ninguno se escribe a mano")
    func theFourStepsComeFromTheScale() {
        let scale = BocTheme.typography.all
        let allFromTheScale = Card.all.allSatisfy { style in scale.contains(style) }
        #expect(
            allFromTheScale,
            "FR-008: los tamaños salen de la escala del sistema de diseño, no del punto de uso"
        )
    }

    @Test("El organismo pesa menos que el título, aunque vaya en mayúsculas")
    func theIssuerDoesNotOutweighTheTitle() {
        // Sube de cuerpo y de caja, así que si además subiera de peso taparía al título, que es
        // el dato. `bodyLarge` es regular; `titleLarge`, semibold.
        #expect(Card.organisation.weight == .regular)
        #expect(Card.title.weight == .semibold)
    }
}
