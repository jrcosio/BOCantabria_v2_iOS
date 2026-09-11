//
//  TabNavigationUITests.swift
//  The three destinations, and that none of them leaves you without an answer.
//

import XCTest

final class TabNavigationUITests: XCTestCase {

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

    func testThereAreExactlyThreeDestinations() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        // Tres, no cuatro: «Avisos» se aplaza con el resto del trabajo de notificaciones. Un
        // cuarto destino que solo pudiera prometer algo sería peor que tres que llevan a alguna
        // parte.
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    func testSearchAndSavedSayWhatIsGoingOn() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        app.tabBars.buttons["Buscar"].tap()
        XCTAssertTrue(element("coming_soon", in: app).waitForExistence(timeout: 5))

        app.tabBars.buttons["Guardados"].tap()
        XCTAssertTrue(element("coming_soon", in: app).waitForExistence(timeout: 5))

        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 5))
    }
}
