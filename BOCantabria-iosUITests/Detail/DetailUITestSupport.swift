//
//  DetailUITestSupport.swift
//  Shared helpers for the detail and viewer suites.
//
//  **Son funciones libres y no una extensión de `XCTestCase`**, y eso costó una vuelta: declarar
//  `element(_:in:)` sobre `XCTestCase` convierte en «override» el `private func element` que cada
//  suite existente ya tenía, y el target de interfaz deja de compilar entero. Una función libre no
//  puede sobrescribir nada, y dentro de aquellas clases su método privado sigue mandando.
//
//  Los identificadores son un contrato, fijado en `contracts/internal-contracts.md` §4.3.
//

import XCTest

/// Busca por identificador **sin fijar el tipo de elemento**.
///
/// Un contenedor de SwiftUI no aparece como `otherElements`: según lo que lleve dentro se expone
/// como un tipo u otro, o no se expone. Atar la consulta a un tipo hace que la prueba falle por el
/// motivo equivocado.
func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
}

func launchApp(scenario: String, extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
        "-boc-data-scenario=\(scenario)",
        // Idioma y región fijos: el texto que estas pruebas leen es español.
        "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
        // Y la selección, siempre: sin esto, una prueba que elige una sección deja el valor puesto
        // y la siguiente arranca contaminada.
        "-home_selection", "",
    ] + extraArguments
    app.launch()
    return app
}

/// Abre el detalle de la primera publicación y espera a que esté.
func openFirstDetail(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        element("publication_card_0", in: app).waitForExistence(timeout: 20),
        "No hay ninguna tarjeta que pulsar", file: file, line: line
    )
    element("publication_card_0", in: app).tap()
    XCTAssertTrue(
        element("detail_root", in: app).waitForExistence(timeout: 20),
        "No se ha abierto el detalle", file: file, line: line
    )
}
