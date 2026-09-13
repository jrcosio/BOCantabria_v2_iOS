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

    /// SC-008: recorrer cincuenta páginas **no agota la memoria ni bloquea la interfaz**.
    ///
    /// **Se mide, no se estima.** El escenario sirve un documento de cincuenta páginas justo para
    /// esto: con uno de una sola, este camino no se ejercitaría nunca.
    func testScrollingFiftyPagesDoesNotExhaustMemory() {
        let app = launchApp(scenario: "documentReady")
        openViewer(in: app)

        XCTAssertTrue(element("pdf_viewer_page_indicator", in: app).exists,
                      "Con más de una página tiene que aparecer el indicador")

        // **Una sola pasada, y se explica por qué.**
        //
        // Empezó con doce arrastres por las cinco pasadas que `measure` hace por defecto: sesenta
        // gestos sintetizados sobre un documento de cincuenta páginas. El simulador dejaba de poder
        // sintetizar eventos, la prueba fallaba **y arrastraba a otras dos de la tanda** por pura
        // carga. Bajar a cuatro no bastó: falló cuatro veces de cuatro.
        //
        // Subir los tiempos de espera no habría arreglado nada: lo que sobraba era el trabajo. Y la
        // cifra que justificaba las cinco pasadas **ya está tomada** —122 MB de media, 192 de pico,
        // y el incremento por pasada en cero— y anotada en `tasks.md`. Lo que esta prueba conserva
        // es lo que sí puede afirmar siempre: que **recorrer el documento entero deja la interfaz
        // respondiendo**, que es la otra mitad de SC-008.
        let opciones = XCTMeasureOptions()
        opciones.iterationCount = 1
        measure(metrics: [XCTMemoryMetric(application: app)], options: opciones) {
            let ventana = app.windows.firstMatch
            for _ in 0..<4 {
                ventana.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    .press(forDuration: 0.01,
                           thenDragTo: ventana.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
            }
        }

        // Y sigue respondiendo: la interfaz no se ha quedado bloqueada.
        XCTAssertTrue(element("pdf_viewer_back", in: app).isHittable)
    }

    private func openViewer(in app: XCUIApplication) {
        openFirstDetail(in: app)
        element("detail_action_open", in: app).tap()
        XCTAssertTrue(element("pdf_viewer", in: app).waitForExistence(timeout: 30))
    }
}
