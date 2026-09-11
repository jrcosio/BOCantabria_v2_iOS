//
//  HomeStatesUITests.swift
//  The states of the listing.
//
//  Los identificadores son un contrato: están fijados en `contracts/internal-contracts.md` §5 y
//  se conservan literales del proyecto Android, para que las dos plataformas se prueben con los
//  mismos nombres. **Cambiarlos es romper un contrato.**
//
//  El escenario se elige por argumento de lanzamiento porque una prueba de interfaz corre en otro
//  proceso y no puede sustituir nada por dentro. Ver `LaunchConfiguration`.
//

import XCTest

final class HomeStatesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Busca por identificador **sin fijar el tipo de elemento**.
    ///
    /// Un contenedor de SwiftUI no aparece como `otherElements`: según lo que lleve dentro, se
    /// expone como un tipo u otro o no se expone. Atar la consulta a un tipo concreto hace que la
    /// prueba falle por el motivo equivocado.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=\(scenario)",
            // Idioma y región fijos: el texto que estas pruebas leen es español y el simulador
            // puede estar en cualquier idioma. **No toca una línea de producción**: las
            // preferencias leen el dominio de argumentos por su cuenta.
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            // Y la selección, siempre, para que la suite no dependa del orden: sin esto, una
            // prueba que elige una sección deja el valor puesto y la siguiente arranca
            // contaminada.
            "-home_selection", "",
        ]
        app.launch()
        return app
    }

    func testContentStateShowsThePublications() {
        let app = launch("today")

        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("publication_card_0", in: app).exists)
        XCTAssertTrue(element("home_header", in: app).exists)
    }

    func testTheHeaderDateAlwaysCarriesItsLabel() {
        let app = launch("today")
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        // La fecha sola no se sabe de qué es, y junto al recuento invita a inventarse la relación
        // entre los dos números.
        let date = element("home_header_date", in: app)
        XCTAssertTrue(date.exists)
        XCTAssertTrue(date.label.hasPrefix("Edición del"), "Con el boletín del día, «Edición del …»")
        XCTAssertTrue(element("home_header_count", in: app).exists)
    }

    func testEmptyStateIsNotAnError() {
        let app = launch("empty")

        XCTAssertTrue(element("home_empty", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(
            element("home_error", in: app).exists,
            "«Sin contenido» y «error» son estados distintos y no deben confundirse."
        )
    }

    func testErrorStateOffersRetry() {
        let app = launch("failing")

        XCTAssertTrue(element("home_error", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("home_retry", in: app).exists || app.buttons["Reintentar"].exists,
                      "Un error sin salida es una pantalla sin salida.")
    }

    func testOfflineShowsTheBannerWithoutHidingTheContent() {
        let app = launch("offline")

        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("home_offline_banner", in: app).exists)
        // El aviso no tapa el contenido: eso es lo que lo distingue de un estado.
        XCTAssertTrue(element("publication_card_0", in: app).exists)
    }

    func testLoadingStateIsShownWhileTheSourcesTakeTheirTime() {
        let app = launch("slow")

        // Espera **por existencia**, nunca por reposo: el esqueleto anima sin fin por diseño y una
        // espera de reposo se colgaría en lugar de fallar.
        XCTAssertTrue(element("home_skeleton", in: app).waitForExistence(timeout: 10))
    }
}
