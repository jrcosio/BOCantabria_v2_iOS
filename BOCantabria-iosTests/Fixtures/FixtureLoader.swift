//
//  FixtureLoader.swift
//  Reads the sample feeds from the test bundle.
//
//  **Se leen del bundle de pruebas, nunca por ruta absoluta.** Un `.xml` dentro de la carpeta de
//  pruebas entra como recurso de ese bundle, y ésa es la única forma de encontrarlo cuando el
//  proceso corre en el simulador.
//
//  Y es también la razón de que el sembrador de escenarios de las pruebas de interfaz **no** pueda
//  usarlas: ese código vive en la aplicación, que es otro proceso y no ve este bundle
//  (research.md D-322).
//

import Foundation

enum Fixture: String, CaseIterable {
    case disposiciones = "feed_1_disposiciones"
    case oposiciones = "feed_2_2_oposiciones"
    case anomalo = "feed_4_3_anomalo"
    case vacio = "feed_8_1_vacio"
    case camposDesconocidos = "feed_campos_desconocidos"
    case conDoctype = "feed_con_doctype"
    case conEntidadExterna = "feed_con_entidad_externa"
    case fechaInvalida = "feed_fecha_invalida"
    case sinCategorias = "feed_item_sin_categorias"
    case sizeIncorrecto = "feed_size_incorrecto"

    var data: Data {
        let bundle = Bundle(for: FixtureBundleAnchor.self)
        guard let url = bundle.url(forResource: rawValue, withExtension: "xml"),
              let data = try? Data(contentsOf: url)
        else {
            fatalError("No está la muestra «\(rawValue).xml» en el bundle de pruebas.")
        }
        return data
    }

    var text: String { String(decoding: data, as: UTF8.self) }
}

/// Solo existe para dar a `Bundle(for:)` una clase de este target.
private final class FixtureBundleAnchor {}
