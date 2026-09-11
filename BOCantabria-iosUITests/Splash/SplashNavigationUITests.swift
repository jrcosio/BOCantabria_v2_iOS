//
//  SplashNavigationUITests.swift
//  Getting in without touching anything, and not being able to go back (FR-004, FR-007).
//
//  Los identificadores son un contrato: están fijados en `contracts/internal-contracts.md` §5.
//

import XCTest

final class SplashNavigationUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(startup: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = startup.map { ["-boc-startup-scenario=\($0)"] } ?? []
        app.launch()
        return app
    }

    func testCoverIsTheFirstScreen() {
        // Con el escenario lento la portada se queda: comprobarlo contra el arranque normal sería
        // una carrera contra el propio lanzamiento de la aplicación.
        let app = launch(startup: "slow")

        XCTAssertTrue(
            element("splash_root", in: app).waitForExistence(timeout: 10),
            "La portada tiene que ser la primera pantalla, antes que cualquier otra (FR-001)."
        )
        XCTAssertTrue(
            element("splash_emblem", in: app).exists,
            "El escudo forma parte de la portada desde el primer momento (FR-019)."
        )
        XCTAssertTrue(
            element("splash_loading", in: app).exists,
            "Mientras prepara, la portada lo dice con su indicador."
        )
    }

    func testReachesMainContentWithoutAnyInteraction() {
        let app = launch()

        XCTAssertTrue(
            element("home_content", in: app).waitForExistence(timeout: 15),
            "Al terminar la preparación se pasa solo al contenido principal (FR-004)."
        )
    }

    func testBackGestureDoesNotReturnToTheCover() {
        let app = launch()
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        // El gesto de retroceso desde el borde izquierdo. La portada no está en la pila, así que
        // no hay nada a lo que volver (FR-007).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            )

        XCTAssertTrue(
            element("home_content", in: app).waitForExistence(timeout: 5),
            "Se sigue en el contenido principal."
        )
        XCTAssertFalse(
            element("splash_root", in: app).exists,
            "El retroceso no puede devolver a la portada."
        )
    }
}
