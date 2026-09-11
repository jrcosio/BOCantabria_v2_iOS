//
//  SplashStatesUITests.swift
//  The four states of the cover and their actions (FR-028).
//
//  Los identificadores son un contrato: `contracts/internal-contracts.md` §5. **Los botones se
//  buscan por identificador, nunca por su texto**: aquí hay dos y uno de ellos dice lo mismo que
//  el de la pantalla de inicio.
//
//  El escenario llega por argumento de lanzamiento porque una prueba de interfaz corre en otro
//  proceso y no puede sustituir nada por dentro. Ver `LaunchConfiguration` y research.md D-212.
//

import XCTest

final class SplashStatesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Busca por identificador **sin fijar el tipo de elemento**: un contenedor de SwiftUI no
    /// aparece como `otherElements`.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-boc-startup-scenario=\(scenario)"]
        app.launch()
        return app
    }

    // MARK: - Preparando

    func testPreparingStateShowsTheProgressIndicator() {
        let app = launch("slow")

        XCTAssertTrue(
            element("splash_loading", in: app).waitForExistence(timeout: 10),
            "Mientras prepara, la portada lo dice con su indicador y no se queda muda."
        )
        XCTAssertFalse(
            element("splash_error", in: app).exists,
            "Preparar no es fallar: los cuatro estados son excluyentes (FR-009)."
        )
    }

    // MARK: - Error recuperable

    func testRecoverableErrorOffersBothWaysOut() {
        let app = launch("offline")

        XCTAssertTrue(
            element("splash_error", in: app).waitForExistence(timeout: 15),
            "Sin conexión se explica qué pasa, no se deja un indicador girando (FR-010)."
        )
        XCTAssertTrue(element("splash_retry", in: app).exists, "Falta la salida de reintentar.")
        XCTAssertTrue(
            element("splash_continue_offline", in: app).exists,
            "Falta la salida de continuar sin conexión."
        )
    }

    func testContinueOfflineReachesMainContent() {
        // SC-003: dos toques como máximo, y el primero es este.
        let app = launch("offline")
        XCTAssertTrue(element("splash_error", in: app).waitForExistence(timeout: 15))

        element("splash_continue_offline", in: app).tap()

        XCTAssertTrue(
            element("home_root", in: app).waitForExistence(timeout: 15),
            "Continuar sin conexión tiene que llevar al contenido principal."
        )
    }

    // MARK: - Acceso bloqueado

    func testOutdatedVersionInformsAndHasNoWayIn() {
        let app = launch("updateRequired")

        XCTAssertTrue(
            element("splash_blocked", in: app).waitForExistence(timeout: 15),
            "Una versión sin soporte tiene que decirlo (FR-012)."
        )
        XCTAssertFalse(
            element("splash_continue_offline", in: app).exists,
            "El bloqueo no ofrece continuar: saltárselo anula su propósito."
        )
        XCTAssertFalse(element("home_root", in: app).exists)
    }

    func testMaintenanceInformsAndHasNoWayIn() {
        let app = launch("maintenance")

        XCTAssertTrue(
            element("splash_blocked", in: app).waitForExistence(timeout: 15),
            "El mensaje de mantenimiento publicado tiene que verse (FR-013)."
        )
        XCTAssertFalse(element("splash_continue_offline", in: app).exists)
        XCTAssertFalse(element("home_root", in: app).exists)
    }

    func testBlockedAccessSurvivesBackgroundAndForeground() {
        // SC-005: «ninguna secuencia de toques lleva al contenido principal». Mandar la aplicación
        // al fondo y recuperarla es la vía que nadie recorre a mano y por la que se cuelan estas
        // cosas.
        let app = launch("updateRequired")
        XCTAssertTrue(element("splash_blocked", in: app).waitForExistence(timeout: 15))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(
            element("splash_blocked", in: app).waitForExistence(timeout: 10),
            "Volver de segundo plano no puede abrir la puerta."
        )
        XCTAssertFalse(element("home_root", in: app).exists)
    }

    func testRetryIsOfferedAndKeepsTheCoverWhenItFailsAgain() {
        let app = launch("offline")
        XCTAssertTrue(element("splash_error", in: app).waitForExistence(timeout: 15))

        element("splash_retry", in: app).tap()

        // El escenario sigue sin conexión, así que vuelve al mismo sitio: lo que se comprueba es
        // que el reintento existe y no rompe nada, no que arregle la red.
        XCTAssertTrue(
            element("splash_error", in: app).waitForExistence(timeout: 15),
            "Reintentar sin conexión vuelve al error, nunca a una pantalla muerta."
        )
        XCTAssertFalse(
            element("home_root", in: app).exists,
            "Reintentar no es continuar: no puede colarse al contenido principal."
        )
    }
}
