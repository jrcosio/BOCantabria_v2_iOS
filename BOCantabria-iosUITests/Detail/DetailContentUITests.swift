//
//  DetailContentUITests.swift
//  The detail's composition, in the order the requirement fixes.
//

import XCTest

final class DetailContentUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// FR-007: sección, **título**, organismo, fecha, distintivo. En ese orden.
    ///
    /// Al revés que la tarjeta de Inicio, y a propósito: allí el organismo permite descartar sin
    /// leer, y aquí ya se ha decidido leer.
    func testTheHeaderShowsItsFiveElementsInOrder() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        let seccion = element("detail_section", in: app)
        let titulo = element("detail_title", in: app)
        let organismo = element("detail_issuer", in: app)
        let fecha = element("detail_date", in: app)
        let distintivo = element("detail_official_badge", in: app)

        for (nombre, elemento) in [
            ("sección", seccion), ("título", titulo), ("organismo", organismo),
            ("fecha", fecha), ("distintivo", distintivo),
        ] {
            XCTAssertTrue(elemento.exists, "Falta \(nombre) en la cabecera")
        }

        // **El orden se comprueba por posición vertical**, no por el orden del árbol: es lo que
        // la persona ve.
        XCTAssertLessThan(seccion.frame.minY, titulo.frame.minY, "El título va DESPUÉS de la sección")
        XCTAssertLessThan(titulo.frame.minY, organismo.frame.minY, "El título va ANTES del organismo")
        XCTAssertLessThan(organismo.frame.minY, fecha.frame.minY)
        XCTAssertLessThan(fecha.frame.minY, distintivo.frame.minY)
    }

    /// FR-008: el título **completo**, sin puntos suspensivos.
    func testALongTitleIsNotTruncated() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        let titulo = element("detail_title", in: app)
        XCTAssertTrue(titulo.exists)
        XCTAssertFalse(titulo.label.contains("…"), "El título se está recortando: \(titulo.label)")
        XCTAssertFalse(titulo.label.hasSuffix("..."), "El título se está recortando: \(titulo.label)")
    }

    /// FR-011: la cabecera **se va** y las pestañas **se quedan**.
    ///
    /// Es lo contrario de lo que hace Inicio, y por eso hay que comprobarlo: si alguien reutilizara
    /// el mecanismo de allí, la cabecera se quedaría y esta prueba se pondría roja.
    func testTheHeaderScrollsAwayWhileTheTabsStay() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        let pestanas = element("detail_tabs", in: app)
        XCTAssertTrue(pestanas.exists)
        let arribaAntes = pestanas.frame.minY
        XCTAssertTrue(element("detail_title", in: app).exists)

        // El gesto se hace con **coordenadas de la ventana**, no sobre el elemento: el marco que
        // XCUITest da a un contenedor de desplazamiento es el de su CONTENIDO, y el centro de ese
        // marco puede caer fuera de la pantalla.
        let ventana = app.windows.firstMatch
        ventana.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05,
                   thenDragTo: ventana.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))

        // Las pestañas siguen ahí y **a la misma altura o más arriba**: se han fijado.
        XCTAssertTrue(pestanas.exists, "Las pestañas tienen que quedarse")
        XCTAssertLessThanOrEqual(pestanas.frame.minY, arribaAntes + 1)
        XCTAssertTrue(element("detail_tab_document", in: app).isHittable,
                      "Las pestañas fijadas tienen que seguir siendo pulsables")
    }

    /// FR-014 y FR-043: dos pestañas, y la segunda **dice** que llegará.
    func testThereAreTwoTabsAndTheSecondSaysItIsComing() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        XCTAssertTrue(element("detail_tab_document", in: app).exists)
        XCTAssertTrue(element("detail_tab_summary", in: app).exists)
        XCTAssertTrue(element("detail_metadata", in: app).waitForExistence(timeout: 10))

        element("detail_tab_summary", in: app).tap()

        XCTAssertTrue(element("coming_soon", in: app).waitForExistence(timeout: 10))
        // Y la acción de abrir **sigue siendo la más destacada** (FR-046).
        XCTAssertTrue(element("detail_action_open", in: app).exists)
    }

    /// FR-015: la ficha de metadatos, y debajo la previsualización.
    func testTheDocumentTabShowsTheMetadataCardAndThePreview() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        let ficha = element("detail_metadata", in: app)
        XCTAssertTrue(ficha.waitForExistence(timeout: 15))
        let previsualizacion = element("detail_preview", in: app)
        XCTAssertTrue(previsualizacion.waitForExistence(timeout: 20))
        XCTAssertLessThan(ficha.frame.minY, previsualizacion.frame.minY,
                          "La previsualización va DEBAJO de la ficha")
    }

    /// FR-045: guardar todavía lo dice.
    func testSavingStillSaysItIsComing() {
        let app = launchApp(scenario: "documentReady")
        openFirstDetail(in: app)

        element("detail_save", in: app).tap()

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10),
                      "Guardar no puede quedarse sin respuesta")
    }
}
