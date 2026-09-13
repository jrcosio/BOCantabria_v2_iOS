//
//  PdfViewerUITests.swift
//  The viewer's three states.
//

import XCTest

final class PdfViewerUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// FR-031: el documento se lee **dentro de la aplicación**.
    func testTheDocumentOpensInsideTheApplication() {
        let app = launchApp(scenario: "documentReady")
        openViewer(in: app)

        XCTAssertTrue(element("pdf_viewer", in: app).exists)
        // Y con sus tres controles, ni uno más (§24.1, enmendado).
        XCTAssertTrue(element("pdf_viewer_back", in: app).exists)
        XCTAssertTrue(element("pdf_viewer_title", in: app).exists)
        XCTAssertTrue(element("pdf_viewer_share", in: app).exists)
    }

    /// El título abreviado es el del anuncio **sin el organismo**.
    func testTheTitleIsAbbreviatedWithoutTheIssuer() {
        let app = launchApp(scenario: "documentReady")
        openViewer(in: app)

        let titulo = element("pdf_viewer_title", in: app)
        XCTAssertTrue(titulo.waitForExistence(timeout: 20))
        XCTAssertFalse(
            titulo.label.uppercased().hasPrefix("CONSEJERÍA")
                || titulo.label.uppercased().hasPrefix("AYUNTAMIENTO"),
            "El título del visor lleva el organismo, y ya va implícito en el documento: \(titulo.label)"
        )
        XCTAssertFalse(titulo.label.isEmpty)
    }

    /// FR-035: un documento que no se puede traer **no deja una pantalla en blanco**.
    func testADocumentThatCannotBeFetchedShowsAMessageAndAWayOut() {
        let app = launchApp(scenario: "documentUnavailable")
        XCTAssertTrue(element("publication_card_0", in: app).waitForExistence(timeout: 20))
        element("publication_card_0", in: app).tap()
        XCTAssertTrue(element("detail_root", in: app).waitForExistence(timeout: 20))
        element("detail_action_open", in: app).tap()

        XCTAssertTrue(element("pdf_viewer_error", in: app).waitForExistence(timeout: 30),
                      "El visor se ha quedado en blanco, que es lo que FR-035 prohíbe")
        // Éste sí ofrece reintento: un fallo de red se arregla reintentando.
        XCTAssertTrue(element("pdf_viewer_retry", in: app).exists)
        XCTAssertFalse(element("pdf_viewer_loading", in: app).exists,
                       "El visor se ha quedado cargando")
    }

    private func openViewer(in app: XCUIApplication) {
        openFirstDetail(in: app)
        element("detail_action_open", in: app).tap()
        XCTAssertTrue(element("pdf_viewer", in: app).waitForExistence(timeout: 30))
    }
}
