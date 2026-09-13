//
//  DetailStatesUITests.swift
//  When the document does not arrive.
//
//  **Es SC-006 visto desde fuera**: ninguna pantalla se queda cargando. En la aplicación de origen,
//  un fallo devuelto y no publicado dejaba el detalle en «obteniéndose» para siempre, sin error y
//  sin reintento. Estas tres pruebas son la regresión.
//

import XCTest

final class DetailStatesUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// Lo que el servicio devuelve no es el documento. **Y no se presenta como si lo fuera.**
    func testARejectedDocumentShowsAnErrorWithRetry() {
        assertTerminalState(scenario: "documentRejected")
    }

    /// Un documento desmesurado se detiene y se informa.
    func testATooLargeDocumentShowsAnErrorWithRetry() {
        assertTerminalState(scenario: "documentTooLarge")
    }

    /// Sin conexión y sin copia: se explica y se ofrece reintentar.
    func testAnUnavailableDocumentShowsAnErrorWithRetry() {
        assertTerminalState(scenario: "documentUnavailable")
    }

    /// El invariante, en un solo sitio: **error con reintento, y NUNCA la carga perpetua**.
    private func assertTerminalState(scenario: String) {
        let app = launchApp(scenario: scenario)
        openFirstDetail(in: app)

        let error = element("detail_preview_error", in: app)
        XCTAssertTrue(
            error.waitForExistence(timeout: 30),
            "«\(scenario)» ha dejado la pantalla sin desenlace. Es el defecto que FR-029 prohíbe."
        )
        XCTAssertTrue(element("detail_retry", in: app).exists,
                      "Un error sin salida es una pantalla sin salida")

        // Y lo que **no** puede quedar: el estado de carga.
        XCTAssertFalse(element("detail_preview_loading", in: app).exists,
                       "«\(scenario)» se ha quedado cargando")

        // La acción de abrir sigue estando: la persona puede insistir por el otro camino.
        XCTAssertTrue(element("detail_action_open", in: app).exists)
    }
}
