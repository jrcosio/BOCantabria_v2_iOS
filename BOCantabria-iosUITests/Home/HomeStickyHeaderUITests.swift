//
//  HomeStickyHeaderUITests.swift
//  The header stays, shrinks, and comes back (FR-009, FR-010, FR-011, FR-019).
//
//  **Es la mitad de la feature 004.** Hasta ella, la cabecera editorial y los filtros vivían dentro
//  del mismo desplazamiento que el listado, así que a las dos tarjetas ya no se sabía qué se estaba
//  viendo ni cuántos anuncios había, y cambiar de sección obligaba a subir del todo.
//
//  Se busca por identificador y **sin fijar el tipo de elemento**, por la razón de siempre: un
//  contenedor de SwiftUI no aparece como `otherElements`.
//

import XCTest

final class HomeStickyHeaderUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Desplaza el listado con un arrastre sobre **coordenadas de la ventana**, no sobre el
    /// elemento.
    ///
    /// **`listing.swipeUp()` no vale, y cuesta un rato averiguar por qué.** El marco que XCUITest
    /// da a un contenedor de desplazamiento es el de su **contenido**, no el de lo que se ve: en
    /// un iPhone SE con diez publicaciones, `home_content` mide 665 puntos de alto sobre una
    /// ventana de 667, así que su centro cae **encima de la barra de pestañas** y el gesto
    /// sintetizado cambia de pestaña en vez de desplazar. La prueba fallaba diciendo que el aviso
    /// de falta de conexión había desaparecido; lo que había desaparecido era la pantalla entera.
    ///
    /// Con coordenadas de la ventana, las dos fracciones caen dentro de la banda del listado en
    /// los dos tamaños de pantalla: en el SE, entre 291 y 584; en el 17 Pro, entre 299 y 790.
    private func drag(_ app: XCUIApplication, from: CGFloat, to: CGFloat) {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            .press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
            )
    }

    private func scrollDown(_ app: XCUIApplication) { drag(app, from: 0.75, to: 0.55) }
    private func scrollUp(_ app: XCUIApplication) { drag(app, from: 0.55, to: 0.85) }

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

    /// FR-009 y FR-010: al desplazar, la cabecera **se queda** y **encoge**.
    func testTheHeaderStaysAndShrinksWhenTheListingScrolls() {
        let app = launch()
        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 15))

        // Arriba del todo: entera, con su fecha rotulada.
        XCTAssertTrue(element("home_header_date", in: app).exists)
        let fullHeight = element("home_header", in: app).frame.height

        scrollDown(app)

        // **Sigue ahí**, que es lo que la feature vino a arreglar.
        XCTAssertTrue(element("home_header", in: app).exists, "La cabecera no puede irse al desplazar")
        XCTAssertTrue(element("home_header_count", in: app).exists, "El recuento se conserva (FR-011)")
        XCTAssertTrue(element("home_section_chips", in: app).exists, "Los filtros se quedan (FR-009)")

        // Y **ha encogido**: la fecha rotulada se repliega y el alto baja.
        XCTAssertFalse(
            element("home_header_date", in: app).exists,
            "Compacta, la fecha rotulada se repliega (FR-011)"
        )
        XCTAssertLessThan(
            element("home_header", in: app).frame.height, fullHeight,
            "Compacta ocupa menos alto que entera"
        )
    }

    /// FR-010: volver al principio la devuelve a su tamaño.
    func testTheHeaderComesBackWhenTheListingReturnsToTheTop() {
        let app = launch()
        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 15))

        scrollDown(app)
        XCTAssertFalse(element("home_header_date", in: app).exists)

        scrollUp(app)
        scrollUp(app)
        scrollUp(app)

        XCTAssertTrue(
            element("home_header_date", in: app).waitForExistence(timeout: 5),
            "Al volver arriba, la cabecera recupera su fecha rotulada"
        )
    }

    /// SC-003: cambiar de sección **no requiere volver al principio del listado**.
    func testASectionCanBeChosenWithoutScrollingBackUp() {
        let app = launch()
        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 15))

        scrollDown(app)

        // Cero desplazamientos previos: el chip está donde estaba.
        let chip = element("chip_2", in: app)
        XCTAssertTrue(chip.exists, "Los filtros siguen alcanzables con el listado desplazado")
        chip.tap()

        // Y la selección se aplica: la sección 2 tiene subsecciones, así que aparece la segunda
        // fila, dentro de la zona fija (FR-017).
        XCTAssertTrue(element("home_subsection_chips", in: app).waitForExistence(timeout: 5))
    }

    /// FR-014: el aviso de falta de conexión **no se va con el listado**.
    func testTheOfflineBannerStaysVisibleWhileScrolling() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=offline",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()

        let listing = element("home_content", in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 15))
        XCTAssertTrue(element("home_offline_banner", in: app).exists)

        scrollDown(app)

        XCTAssertTrue(
            element("home_offline_banner", in: app).exists,
            "Perderlo de vista al desplazar haría creer que se está leyendo lo de hoy"
        )
    }
}
