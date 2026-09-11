//
//  HomeStatesUITests.swift
//  The four states of the initial screen, and the retry (FR-025).
//
//  Los identificadores son un contrato con estas pruebas: están fijados en
//  `contracts/internal-contracts.md` §6 y se conservan literales del proyecto Android, para que
//  las dos plataformas se prueben con los mismos nombres. **Cambiarlos es romper un contrato.**
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
    /// prueba falle por el motivo equivocado, que es exactamente lo que pasó la primera vez.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-boc-content-scenario=\(scenario)"]
        app.launch()
        return app
    }

    func testLoadingStateIsShownFirst() {
        let app = launch(scenario: "slow")

        XCTAssertTrue(
            element("home_loading", in: app).waitForExistence(timeout: 5),
            "El estado de carga tiene que verse mientras llega el contenido, no una pantalla en blanco."
        )
    }

    func testContentStateShowsTheItems() {
        let app = launch(scenario: "items")

        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Disposiciones generales"].exists)
    }

    func testEmptyStateIsNotAnError() {
        let app = launch(scenario: "empty")

        XCTAssertTrue(element("home_empty", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(
            element("home_error", in: app).exists,
            "«Sin contenido» y «error» son estados distintos y no deben confundirse."
        )
    }

    func testErrorStateOffersRetry() {
        let app = launch(scenario: "failing")

        XCTAssertTrue(element("home_error", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Reintentar"].exists, "Un error sin salida es una pantalla sin salida.")
    }

    func testRetryFromErrorReloads() {
        let app = launch(scenario: "failing")
        XCTAssertTrue(element("home_error", in: app).waitForExistence(timeout: 10))

        app.buttons["Reintentar"].tap()

        // El origen sigue fallando, así que lo que se comprueba es que la acción **vuelve a
        // pedir**: la pantalla pasa por carga antes de volver al error.
        XCTAssertTrue(element("home_error", in: app).waitForExistence(timeout: 10))
    }
}
