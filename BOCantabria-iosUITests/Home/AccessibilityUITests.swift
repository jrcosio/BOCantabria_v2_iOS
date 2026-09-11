//
//  AccessibilityUITests.swift
//  What the screen has to keep doing when the text grows.
//
//  **Se mira la pantalla, no el código.** Así se descubrió en la feature anterior que el botón
//  principal era invisible sobre la portada: leyendo el código no se veía.
//

import XCTest

final class AccessibilityUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(textSize: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        if let textSize {
            arguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// SC-010: con el tamaño de letra del sistema al 200 %, la tarjeta crece y **no recorta** el
    /// organismo, el título ni la fecha.
    func testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes() {
        let normal = launch(textSize: nil)
        XCTAssertTrue(element("home_content", in: normal).waitForExistence(timeout: 15))
        let normalHeight = element("publication_card_0", in: normal).frame.height
        let normalLabel = element("publication_card_0", in: normal).label
        normal.terminate()

        let large = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(element("home_content", in: large).waitForExistence(timeout: 15))
        let card = element("publication_card_0", in: large)
        XCTAssertTrue(card.exists)

        // **Crece**: si en vez de crecer recortara, la altura sería la misma o menor.
        XCTAssertGreaterThan(
            card.frame.height, normalHeight,
            "Con el texto al 200 % la tarjeta tiene que crecer, no recortar"
        )

        // Y dice lo mismo: el organismo, el título y la fecha siguen enteros. Si se hubiera
        // recortado el texto, la etiqueta combinada sería más corta.
        XCTAssertEqual(
            card.label, normalLabel,
            "El organismo, el título y la fecha siguen enteros"
        )
    }

    /// La cabecera editorial también crece, y su rótulo de fecha no desaparece.
    func testTheHeaderKeepsItsLabelledDateAtLargeTextSizes() {
        let app = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(element("home_header", in: app).waitForExistence(timeout: 15))

        let date = element("home_header_date", in: app)
        XCTAssertTrue(date.exists, "Sin rótulo, la fecha no se sabe de qué es")
        XCTAssertTrue(date.label.hasPrefix("Edición del"))
        XCTAssertTrue(element("home_header_count", in: app).exists)
    }

    /// El organismo aparece **una sola vez** en la tarjeta.
    ///
    /// Es una de las tres cosas que en la aplicación de origen solo se vieron al ejecutar en un
    /// dispositivo: el organismo salía dos veces, porque está en el campo de clasificación **y**
    /// como prefijo del título, y las dos se pintaban.
    func testTheIssuerIsNotPaintedTwice() {
        let app = launch(textSize: nil)
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        let label = element("publication_card_0", in: app).label
        let issuer = "Consejería de Salud"
        let occurrences = label.components(separatedBy: issuer).count - 1
        XCTAssertEqual(occurrences, 1, "El organismo se pinta una vez: «\(label)»")
    }
}
