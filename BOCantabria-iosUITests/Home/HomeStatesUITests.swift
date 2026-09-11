//
//  HomeStatesUITests.swift
//  The states of the listing.
//
//  Los identificadores son un contrato con estas pruebas: están fijados en
//  `contracts/internal-contracts.md` §5 y se conservan literales del proyecto Android, para que
//  las dos plataformas se prueben con los mismos nombres. **Cambiarlos es romper un contrato.**
//
//  **Nota de la fase en curso.** La costura de contenido de la feature 001 se ha retirado y la
//  cadena real llega con la historia 1, así que ahora mismo Inicio llega siempre al estado vacío.
//  Lo que estas pruebas afirman entretanto es lo que ya es cierto; los cinco escenarios vuelven
//  con `-boc-data-scenario=`.
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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // Idioma y región fijos: el texto que estas pruebas leen es español, y el simulador puede
        // estar en cualquier idioma. No toca una línea de producción — las preferencias leen el
        // dominio de argumentos por su cuenta (research.md D-316).
        app.launchArguments = ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        return app
    }

    func testEmptyStateIsNotAnError() {
        let app = launch()

        XCTAssertTrue(element("home_empty", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(
            element("home_error", in: app).exists,
            "«Sin contenido» y «error» son estados distintos y no deben confundirse."
        )
    }

    func testTheListingIsReachedFromTheSplash() {
        let app = launch()

        // La portada es un conmutador y no entra en la pila: al terminar, lo que queda es Inicio.
        XCTAssertTrue(element("home_empty", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("splash_root", in: app).exists)
    }
}
