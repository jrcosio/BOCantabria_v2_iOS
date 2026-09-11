//
//  HomeFiltersUITests.swift
//  The two rows of quick filters.
//

import XCTest

final class HomeFiltersUITests: XCTestCase {

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

    func testTheSecondRowDoesNotExistForTodaysBulletin() {
        let app = launch()
        XCTAssertTrue(element("home_section_chips", in: app).waitForExistence(timeout: 15))

        // **No existe**, no está oculta: con el boletín del día no hay subsecciones que ofrecer.
        XCTAssertFalse(element("home_subsection_chips", in: app).exists)
    }

    func testASectionWithSubsectionsOpensBothThingsInOneTap() {
        let app = launch()
        XCTAssertTrue(element("home_section_chips", in: app).waitForExistence(timeout: 15))

        // Un solo toque hace las dos cosas: la lista pasa a la sección completa y la segunda fila
        // se despliega. Cobrar dos toques por el caso común sería el reparto equivocado.
        element("chip_2", in: app).tap()

        XCTAssertTrue(element("home_subsection_chips", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("chip_2.2", in: app).exists)
    }

    func testMovingToAFlatSectionRemovesTheSecondRow() {
        let app = launch()
        XCTAssertTrue(element("home_section_chips", in: app).waitForExistence(timeout: 15))

        element("chip_2", in: app).tap()
        XCTAssertTrue(element("home_subsection_chips", in: app).waitForExistence(timeout: 5))

        element("chip_1", in: app).tap()
        XCTAssertFalse(
            element("home_subsection_chips", in: app).waitForExistence(timeout: 2),
            "La sección 1 no tiene subsecciones: la fila desaparece"
        )
    }

    func testTheFirstChipReturnsToTodaysBulletin() {
        let app = launch()
        XCTAssertTrue(element("home_section_chips", in: app).waitForExistence(timeout: 15))

        element("chip_2", in: app).tap()
        XCTAssertTrue(element("home_subsection_chips", in: app).waitForExistence(timeout: 5))

        element("chip_today", in: app).tap()
        XCTAssertFalse(element("home_subsection_chips", in: app).waitForExistence(timeout: 2))
    }
}
