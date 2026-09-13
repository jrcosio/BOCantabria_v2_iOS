//
//  PdfPageRenderer.swift
//  Drawing the first page, off the main actor.
//

import Foundation
import PDFKit
import UIKit

enum PdfPageRenderer {
    /// Tope de píxeles del lado mayor.
    ///
    /// **No es una optimización.** Hay anuncios con planos urbanísticos en tamaño A0; a escala 3
    /// son decenas de megapíxeles en una sola imagen.
    static let maxPixelWidth: CGFloat = 2048

    /// La primera página, dibujada **fuera del actor principal**.
    ///
    /// - Parameter displayScale: llega **por parámetro** y no de la pantalla, por dos motivos: el
    ///   tamaño de la miniatura se interpreta en puntos, así que sin multiplicar sale borrosa en
    ///   cualquier iPhone; y tomarla del entorno hace esta función comprobable sin simulador.
    /// - Parameter onStart: la misma costura que el sondeo, y por lo mismo.
    ///
    /// `UIImage` **sí** es `Sendable` —comprobado en `UIImage.h`—, así que cruza a la vista sin
    /// envoltorio. `PDFDocument` y `PDFPage` no lo son, y por eso nacen y mueren aquí dentro.
    @concurrent
    static func firstPageImage(
        of fileUrl: URL,
        width: CGFloat,
        displayScale: CGFloat,
        onStart: (@Sendable () -> Void)? = nil
    ) async -> UIImage? {
        onStart?()
        guard let document = PDFDocument(url: fileUrl), !document.isLocked,
              let page = document.page(at: 0)
        else { return nil }

        // `.cropBox` y no `.mediaBox`: con el segundo aparecen las marcas de imprenta y el margen
        // de sangrado, y la miniatura sale con una franja blanca enorme y el contenido diminuto.
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let pixelWidth = min(width * displayScale, maxPixelWidth)
        let size = CGSize(width: pixelWidth, height: pixelWidth * bounds.height / bounds.width)
        return page.thumbnail(of: size, for: .cropBox)
    }
}
