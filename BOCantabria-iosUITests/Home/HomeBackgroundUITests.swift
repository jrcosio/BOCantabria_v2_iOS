//
//  HomeBackgroundUITests.swift
//  The state survives a background/foreground cycle without reloading (FR-044).
//
//  Es la traducción a iOS del requisito que en Android hablaba de «cambio de configuración del
//  dispositivo». Allí la pantalla se recreaba y había algo real que proteger; aquí el objeto de
//  estado no se recrea al rotar —y además la aplicación está bloqueada en vertical—, así que la
//  pregunta equivalente con mordiente es esta.
//

import XCTest

final class HomeBackgroundUITests: XCTestCase {

    func testTheListingSurvivesBackgroundAndForeground() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()

        let listing = app.descendants(matching: .any).matching(identifier: "home_content").firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(listing.waitForExistence(timeout: 5), "Lo que se veía tiene que seguir ahí.")
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "home_skeleton").firstMatch.exists,
            "Volver de segundo plano no puede recargar: el estado vive en el modelo de pantalla."
        )
    }
}
