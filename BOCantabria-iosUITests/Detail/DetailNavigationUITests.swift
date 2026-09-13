//
//  DetailNavigationUITests.swift
//  From the card to the document, and back to where you were.
//

import XCTest

final class DetailNavigationUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// SC-001: **un solo toque** desde el listado hasta el detalle.
    func testTappingACardOpensItsDetailInASingleTap() {
        let app = launchApp(scenario: "documentReady")

        XCTAssertTrue(element("publication_card_0", in: app).waitForExistence(timeout: 20))
        element("publication_card_0", in: app).tap()

        XCTAssertTrue(element("detail_root", in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element("detail_title", in: app).exists)
    }

    /// FR-006: el detalle **no** muestra la barra de pestañas de la aplicación.
    func testTheDetailHidesTheApplicationTabBar() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        XCTAssertFalse(app.tabBars.firstMatch.exists,
                       "El detalle tiene su propia barra de acciones, no la de la aplicación")
        XCTAssertTrue(element("detail_actions", in: app).exists)
    }

    /// FR-005: el retroceso devuelve al boletín, en su sitio.
    func testGoingBackReturnsToTheBulletin() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        element("detail_back", in: app).tap()

        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element("publication_card_0", in: app).exists)
    }

    /// FR-031 y FR-033: el documento se abre **dentro de la aplicación**, en su pantalla.
    func testOpeningTheOfficialDocumentReachesTheViewerAndBackReturns() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        element("detail_action_open", in: app).tap()
        XCTAssertTrue(element("pdf_viewer", in: app).waitForExistence(timeout: 30))

        // Dos retrocesos, y se vuelve al boletín.
        element("pdf_viewer_back", in: app).tap()
        XCTAssertTrue(element("detail_root", in: app).waitForExistence(timeout: 20))
        element("detail_back", in: app).tap()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 20))
    }

    /// FR-044: «Preguntar» abre una **pantalla propia**, con su sitio en la pila.
    func testAskingOpensItsOwnScreenWithItsOwnBackStack() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        element("detail_action_ask", in: app).tap()

        XCTAssertTrue(element("ask_root", in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element("coming_soon", in: app).exists,
                      "La pantalla existe y **dice** que la función llegará")

        element("ask_back", in: app).tap()
        XCTAssertTrue(element("detail_root", in: app).waitForExistence(timeout: 20))
    }
}
