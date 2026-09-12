//
//  HomeBackgroundUITests.swift
//  The state survives a background/foreground cycle without reloading (FR-044 de la 003).
//
//  Es la traducción a iOS del requisito que en Android hablaba de «cambio de configuración del
//  dispositivo». Allí la pantalla se recreaba y había algo real que proteger; aquí el objeto de
//  estado no se recrea al rotar —y además la aplicación está bloqueada en vertical—, así que la
//  pregunta equivalente con mordiente es esta.
//
//  **La 004 le añade la mitad que faltaba.** Hasta ella, esta prueba comprobaba que el listado
//  seguía existiendo; no comprobaba que siguiera **donde estaba**. Y esa es justo la garantía que
//  la 004 pone en riesgo: mover el `ScrollView` de sitio puede hacer que SwiftUI lo recree
//  (FR-016, research.md D-413).
//

import XCTest

final class HomeBackgroundUITests: XCTestCase {

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Desplaza el listado con coordenadas de la **ventana**, no del elemento.
    ///
    /// El marco que XCUITest da a `home_content` es el de su **contenido**: en una pantalla
    /// pequeña con contenido largo, su centro cae sobre la barra de pestañas y `swipeUp()` cambia
    /// de pestaña en vez de desplazar.
    private func scrollDown(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            )
    }

    func testTheListingSurvivesBackgroundAndForeground() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()

        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(listing.waitForExistence(timeout: 5), "Lo que se veía tiene que seguir ahí.")
        XCTAssertFalse(
            element("home_skeleton", in: app).exists,
            "Volver de segundo plano no puede recargar: el estado vive en el modelo de pantalla."
        )
    }

    /// FR-016: la **posición de lectura** sobrevive al ciclo de segundo plano.
    ///
    /// Se mide sobre el marco del propio listado y **no sobre la enésima tarjeta**: el listado es
    /// un `LazyVStack` y la tarjeta que se estaba mirando puede no estar realizada al volver. El
    /// origen vertical de `home_content` se vuelve negativo conforme se desplaza, y no depende de
    /// qué celdas estén vivas (research.md D-413).
    func testTheReadingPositionSurvivesBackgroundAndForeground() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()

        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 10))

        let top = listing.frame.origin.y
        scrollDown(app)
        let scrolled = listing.frame.origin.y
        XCTAssertLessThan(scrolled, top, "El deslizamiento tiene que haber movido el listado")

        // La cabecera está compacta en este punto: forma parte de lo que hay que conservar.
        XCTAssertFalse(element("home_header_date", in: app).exists)

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(listing.waitForExistence(timeout: 5))
        XCTAssertEqual(
            listing.frame.origin.y, scrolled, accuracy: 1,
            "Volver de segundo plano no puede devolver el listado al principio (FR-016)"
        )
        XCTAssertFalse(
            element("home_header_date", in: app).exists,
            "Y la cabecera sigue compacta: el estado de la vista tampoco se pierde"
        )
    }
}
