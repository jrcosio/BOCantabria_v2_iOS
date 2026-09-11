//
//  SectionsDrawerUITests.swift
//  The sections panel.
//

import XCTest

final class SectionsDrawerUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()
        return app
    }

    func testAClosedDrawerIsNotInTheAccessibilityTree() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        // **Antes de abrir nada.** La aserción es sobre **existencia**, no sobre pulsabilidad:
        // `allowsHitTesting(false)` a secas deja el elemento en el árbol, y comprobar lo segundo
        // sería comprobar la mitad equivocada.
        XCTAssertFalse(element("section_row_1", in: app).exists)
        XCTAssertFalse(element("sections_drawer_dismiss", in: app).exists)
    }

    func testTheDrawerOpensFromTheMenuButton() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        element("home_menu", in: app).tap()

        XCTAssertTrue(element("sections_drawer", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("section_row_1", in: app).exists)
        XCTAssertTrue(element("section_row_9", in: app).exists)
        // Sin campo de filtro: sobre nueve filas no aportaba, y una lupa dentro de un panel de
        // secciones se lee como «buscar publicaciones».
        XCTAssertEqual(app.searchFields.count, 0)
    }

    func testTheArrowCollapsesThePanelWithoutChangingAnything() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))
        element("home_menu", in: app).tap()
        XCTAssertTrue(element("sections_drawer_dismiss", in: app).waitForExistence(timeout: 5))

        element("sections_drawer_dismiss", in: app).tap()

        XCTAssertFalse(element("section_row_1", in: app).waitForExistence(timeout: 2))
        // No navega y no cambia la selección: se vuelve exactamente a donde se estaba.
        XCTAssertTrue(element("home_content", in: app).exists)
    }

    func testTappingOutsideClosesTheDrawer() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))
        element("home_menu", in: app).tap()
        XCTAssertTrue(element("sections_drawer", in: app).waitForExistence(timeout: 5))

        element("sections_drawer_scrim", in: app).tap()

        XCTAssertFalse(element("section_row_1", in: app).waitForExistence(timeout: 2))
    }

    func testChoosingASubsectionAppliesItAndClosesThePanel() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))
        element("home_menu", in: app).tap()
        XCTAssertTrue(element("section_toggle_2", in: app).waitForExistence(timeout: 5))

        element("section_toggle_2", in: app).tap()
        XCTAssertTrue(element("section_row_2.2", in: app).waitForExistence(timeout: 5))
        element("section_row_2.2", in: app).tap()

        // El panel se retira y la segunda fila aparece: llegar desde el panel da el mismo
        // resultado que llegar desde los chips.
        XCTAssertFalse(element("section_row_1", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(element("home_subsection_chips", in: app).waitForExistence(timeout: 5))
    }
}
