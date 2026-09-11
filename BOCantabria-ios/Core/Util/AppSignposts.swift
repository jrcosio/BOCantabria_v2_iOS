//
//  AppSignposts.swift
//  The measurable points of the application.
//
//  **Existe porque XCUITest no sabe medir por debajo del segundo.** Su sondeo del árbol de
//  accesibilidad tiene una granularidad de aproximadamente un segundo, así que cronometrar entre
//  dos `waitForExistence` da siempre algo por encima de un segundo aunque la pantalla haya
//  respondido en veinte milisegundos. SC-001 pide **menos de un segundo**, así que medirlo de esa
//  forma es medir el instrumento y no la aplicación.
//
//  Un *signpost* sí lo mide, y `XCTOSSignpostMetric` lo lee desde la prueba. En producción, cuando
//  nadie está grabando, no cuesta nada.
//

import OSLog

enum AppSignposts {
    static let subsystem = "com.jrblanco.BOCantabria"

    /// Desde que Inicio aparece hasta que hay publicaciones en pantalla. Es exactamente lo que
    /// SC-001 mide.
    static let timeToContent = OSSignposter(
        subsystem: subsystem, category: "time_to_content"
    )

    static let timeToContentName: StaticString = "home_time_to_content"
}
