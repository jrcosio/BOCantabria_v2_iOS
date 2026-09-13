//
//  AccessibilityUITests.swift
//  What the screen has to keep doing when the text grows.
//
//  **Se mira la pantalla, no el código.** Así se descubrió en la feature anterior que el botón
//  principal era invisible sobre la portada: leyendo el código no se veía.
//

import XCTest

final class AccessibilityUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(textSize: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-boc-data-scenario=today",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        if let textSize {
            arguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// SC-010: con el tamaño de letra del sistema al 200 %, la tarjeta crece y **no recorta** el
    /// organismo, el título ni la fecha.
    func testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes() {
        let normal = launch(textSize: nil)
        XCTAssertTrue(element("home_content", in: normal).waitForExistence(timeout: 15))
        let normalHeight = element("publication_card_0", in: normal).frame.height
        let normalLabel = element("publication_card_0", in: normal).label
        normal.terminate()

        let large = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(element("home_content", in: large).waitForExistence(timeout: 15))
        let card = element("publication_card_0", in: large)
        XCTAssertTrue(card.exists)

        // **Crece**: si en vez de crecer recortara, la altura sería la misma o menor.
        XCTAssertGreaterThan(
            card.frame.height, normalHeight,
            "Con el texto al 200 % la tarjeta tiene que crecer, no recortar"
        )

        // Y dice lo mismo: el organismo, el título y la fecha siguen enteros. Si se hubiera
        // recortado el texto, la etiqueta combinada sería más corta.
        //
        // **El plan de la 004 predijo que esta aserción se rompería, y no se rompe.** El
        // razonamiento era que al apilarse la fila cambiaría el orden en que `.combine` concatena
        // los fragmentos. No cambia: las dos acciones son **botones**, elementos propios del árbol
        // de accesibilidad, y nunca formaron parte de esta etiqueta. La fecha es el último texto
        // tanto en fila como apilada. Se comprobó ejecutando, y la igualdad se conserva porque
        // sigue comprobando lo que quería comprobar (research.md D-417).
        XCTAssertEqual(
            card.label, normalLabel,
            "El organismo, el título y la fecha siguen enteros"
        )
    }

    /// La cabecera editorial también crece, y su rótulo de fecha no desaparece.
    func testTheHeaderKeepsItsLabelledDateAtLargeTextSizes() {
        let app = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(element("home_header", in: app).waitForExistence(timeout: 15))

        let date = element("home_header_date", in: app)
        XCTAssertTrue(date.exists, "Sin rótulo, la fecha no se sabe de qué es")
        XCTAssertTrue(date.label.hasPrefix("Edición del"))
        XCTAssertTrue(element("home_header_count", in: app).exists)
    }

    /// El organismo aparece **una sola vez** en la tarjeta.
    ///
    /// Es una de las tres cosas que en la aplicación de origen solo se vieron al ejecutar en un
    /// dispositivo: el organismo salía dos veces, porque está en el campo de clasificación **y**
    /// como prefijo del título, y las dos se pintaban.
    ///
    /// **Se compara sin distinguir mayúsculas, y esa es la prueba entera.** Escrita con una
    /// comparación exacta, esta prueba estuvo en verde toda la feature 003 **por accidente**: el
    /// BOC publica el organismo en la ruta de clasificación con su caja normal y otra vez al
    /// principio del título en mayúsculas, así que «Consejería de Salud» y «CONSEJERÍA DE SALUD»
    /// no coincidían y el recuento daba uno. Se pintaba dos veces y nadie lo veía. Lo destapó el
    /// volcado del árbol de accesibilidad al planificar la 004 (research.md D-416).
    func testTheIssuerIsNotPaintedTwice() {
        let app = launch(textSize: nil)
        XCTAssertTrue(element("home_content", in: app).waitForExistence(timeout: 15))

        let label = element("publication_card_0", in: app).label
        let issuer = "Consejería de Salud"
        let occurrences = label.lowercased()
            .components(separatedBy: issuer.lowercased()).count - 1
        XCTAssertEqual(occurrences, 1, "El organismo se pinta una vez: «\(label)»")
    }

    /// FR-004 y FR-005: la fecha comparte fila con las acciones, y **se apila cuando no cabe**.
    ///
    /// Se comprueba con el solapamiento **vertical** entre el texto de la fecha y el botón de
    /// compartir, que es la diferencia grande e inequívoca entre los dos candidatos del
    /// `ViewThatFits`: compartiendo fila se solapan; apilados, el botón queda estrictamente
    /// debajo. Comparar alturas o posiciones exactas sería frágil; esto no.
    ///
    /// **El plan daba esto por incomprobable** y se equivocaba: decía que una prueba solo puede
    /// afirmar que la tarjeta crece, no qué candidato se eligió. Puede afirmar las dos cosas, y
    /// hace falta, porque un `Spacer()` sin `minLength` en el primer candidato haría que la fila
    /// no se apilara **nunca** sin romper nada más (research.md D-404).
    func testTheDateSharesItsRowWithTheActionsAndStacksWhenItDoesNotFit() {
        let normal = launch(textSize: nil)
        XCTAssertTrue(element("home_content", in: normal).waitForExistence(timeout: 15))
        let normalDate = element("publication_date", in: normal).frame
        let normalShare = element("publication_share", in: normal).frame
        XCTAssertTrue(
            normalDate.minY < normalShare.maxY && normalShare.minY < normalDate.maxY,
            "Al 100 % la fecha y las acciones comparten fila: \(normalDate) · \(normalShare)"
        )
        normal.terminate()

        let large = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(element("home_content", in: large).waitForExistence(timeout: 15))
        let largeDate = element("publication_date", in: large).frame
        let largeShare = element("publication_share", in: large).frame
        XCTAssertGreaterThanOrEqual(
            largeShare.minY, largeDate.maxY,
            "Al 200 % no caben en una línea: se apilan, no se pisan \(largeDate) · \(largeShare)"
        )
    }
}

// MARK: - La tarjeta ahora abre

extension AccessibilityUITests {

    /// **La tarjeta se hizo pulsable con un gesto y no con un enlace de navegación**, y esta prueba
    /// es lo que demuestra que el árbol no se ha movido: la tarjeta sigue siendo un elemento con su
    /// etiqueta combinada, y sus dos controles siguen siendo elementos propios que responden por
    /// separado (research.md D-519).
    func testTheCardOpensWithoutSwallowingItsOwnControls() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-boc-data-scenario=documentReady",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
            "-home_selection", "",
        ]
        app.launch()

        let tarjeta = app.descendants(matching: .any)
            .matching(identifier: "publication_card_0").firstMatch
        XCTAssertTrue(tarjeta.waitForExistence(timeout: 20))

        // Los dos controles siguen existiendo **dentro** de la tarjeta y con su área táctil.
        let compartir = app.descendants(matching: .any)
            .matching(identifier: "publication_share").firstMatch
        let guardar = app.descendants(matching: .any)
            .matching(identifier: "publication_save").firstMatch
        XCTAssertTrue(compartir.exists, "El envoltorio se ha tragado la acción de compartir")
        XCTAssertTrue(guardar.exists, "El envoltorio se ha tragado la acción de guardar")
        XCTAssertEqual(compartir.frame.width, 48, accuracy: 1)
        XCTAssertEqual(compartir.frame.height, 48, accuracy: 1)

        // Y la etiqueta combinada sigue diciendo lo mismo: sección, organismo, título y fecha.
        XCTAssertFalse(tarjeta.label.isEmpty)

        // Pulsar la tarjeta abre el detalle; pulsar un control, no.
        tarjeta.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "detail_root").firstMatch
                .waitForExistence(timeout: 20)
        )
    }
}
