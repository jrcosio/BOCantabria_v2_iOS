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

import CryptoKit
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

/// Las muestras de documento de la feature 005.
///
/// **Es un enumerado hermano y no un caso más de `Fixture`**: aquél fija `withExtension: "xml"`, y
/// aquí las extensiones son tres. Ampliar el de arriba obligaría a que cada caso llevara la suya,
/// que es más código para que los diez de los feeds digan lo que ya se sabe.
///
/// Las cuatro que son PDF están **escritas a mano** —el sistema no tiene ninguna herramienta de
/// PDF— y **verificadas contra PDFKit** antes de entrar: la válida construye con una página, la de
/// dos construye con dos, la protegida construye con `isLocked` cierto y la truncada **devuelve
/// `nil`**. Sus bytes son deterministas, así que su huella es constante y se puede afirmar.
///
/// **Un detalle que la verificación destapó y que decide el diseño del sondeo**: el documento
/// protegido **sí devuelve miniatura** aunque esté bloqueado. Mirar si el dibujado falla no
/// distingue «protegido» de «legible»; lo único que lo distingue es `isLocked` (research.md D-514).
enum PdfFixture: String, CaseIterable {
    /// Una página. El camino feliz.
    case valido = "documento_valido"
    /// Dos páginas. La previsualización enseña la **primera**.
    case dosPaginas = "documento_dos_paginas"
    /// Contraseña **de usuario**: `isLocked` cierto. No es lo mismo que ilegible.
    case protegido = "documento_protegido"
    /// Cabecera válida y cuerpo cortado: ilegible. No es lo mismo que protegido.
    case truncado = "documento_truncado"
    /// Una respuesta con código 200 que no es el documento. La que engaña.
    case paginaError = "pagina_error"
    /// Se declara documento portátil y sus primeros bytes no lo son.
    case declaradoPdfNoLoEs = "declarado_pdf_no_lo_es"

    var fileExtension: String {
        switch self {
        case .paginaError: "html"
        case .declaradoPdfNoLoEs: "bin"
        default: "pdf"
        }
    }

    var url: URL {
        let bundle = Bundle(for: FixtureBundleAnchor.self)
        guard let url = bundle.url(forResource: rawValue, withExtension: fileExtension) else {
            fatalError("No está la muestra «\(rawValue).\(fileExtension)» en el bundle de pruebas.")
        }
        return url
    }

    var data: Data {
        guard let data = try? Data(contentsOf: url) else {
            fatalError("No se pudo leer la muestra «\(rawValue).\(fileExtension)».")
        }
        return data
    }

    /// La huella de la muestra, para poder afirmar la que calcula el descargador.
    var sha256: String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Solo existe para dar a `Bundle(for:)` una clase de este target.
private final class FixtureBundleAnchor {}
