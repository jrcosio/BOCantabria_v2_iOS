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

    /// Desde que se pide el documento oficial hasta que está listo para leerse.
    ///
    /// Es lo que miden SC-002 —menos de un segundo con la copia ya en caché— y SC-003 —menos de
    /// diez con una conexión normal—. **Las dos cifras son imposibles de tomar con la espera de una
    /// prueba de interfaz**, por lo que dice la cabecera de este fichero: la primera medición de
    /// SC-001 dio 1,10 s y con un hito dio 126 ms.
    ///
    /// Y sirve además para una tercera cosa que no es un criterio de la especificación: decidir si
    /// la descarga byte a byte aguanta un documento de veinticinco megas (research.md D-502).
    static let timeToDocument = OSSignposter(
        subsystem: subsystem, category: "time_to_document"
    )

    static let timeToDocumentName: StaticString = "document_time_to_ready"
}
