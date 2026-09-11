//
//  AnalyticsEventTests.swift
//
//  **El filtro de datos personales vive en el modelo y por eso se puede probar aquí, sin tocar
//  ningún SDK.** Es lo que hace que cambiar de proveedor no pueda perderlo por el camino.
//

import Testing
@testable import BOCantabria_ios

@Suite("Evento de uso")
struct AnalyticsEventTests {

    @Test("Descarta las claves sensibles")
    func dropsSensitiveKeys() {
        let event = AnalyticsEvent(
            name: "boc_test",
            parameters: ["email": "a@b.c", "phone": "600", "section": "1"]
        )

        #expect(event.sanitizedParameters() == ["section": "1"])
    }

    @Test("Una clave que no es sensible sí viaja")
    func keepsHarmlessKeys() {
        let event = AnalyticsEvent(name: "boc_test", parameters: ["results": "12"])

        #expect(event.sanitizedParameters() == ["results": "12"])
    }

    @Test("La coincidencia es exacta y sin distinguir mayúsculas")
    func matchesExactKeysIgnoringCase() {
        let event = AnalyticsEvent(
            name: "boc_test",
            parameters: ["EMAIL": "a@b.c", "email_count": "3", "user_id": "x"]
        )

        // «EMAIL» y «user_id» se van; «email_count» NO, porque el filtro es por clave exacta y no
        // por subcadena: si fuera por subcadena descartaría recuentos inofensivos y la gente
        // acabaría rodeándolo.
        #expect(event.sanitizedParameters() == ["email_count": "3"])
    }

    @Test("Las quince claves sensibles están cubiertas")
    func coversEveryDeclaredSensitiveKey() {
        let parameters = Dictionary(uniqueKeysWithValues: AnalyticsEvent.sensitiveKeys.map { ($0, "x") })
        let event = AnalyticsEvent(name: "boc_test", parameters: parameters)

        #expect(AnalyticsEvent.sensitiveKeys.count == 15)
        #expect(event.sanitizedParameters().isEmpty)
    }

    @Test("Un nombre válido cumple el patrón y uno inválido no")
    func validatesTheName() {
        #expect("boc_search".wholeMatch(of: AnalyticsEvent.namePattern) != nil)
        #expect("screen_view".wholeMatch(of: AnalyticsEvent.namePattern) != nil)
        #expect("Boc_Search".wholeMatch(of: AnalyticsEvent.namePattern) == nil, "Una mayúscula no vale.")
        #expect("1boc".wholeMatch(of: AnalyticsEvent.namePattern) == nil, "No puede empezar por dígito.")
        #expect("boc-search".wholeMatch(of: AnalyticsEvent.namePattern) == nil, "El guion no vale.")
        #expect(String(repeating: "a", count: 41).wholeMatch(of: AnalyticsEvent.namePattern) == nil, "Máximo 40.")
    }
}
