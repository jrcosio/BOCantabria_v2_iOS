//
//  PdfViewerUiState.swift
//  What the viewer screen shows.
//
//  **Ni `PDFDocument` ni `PDFPage` están aquí, y no por elegancia: no compilarían.** Son `NSObject`
//  pelados, sin anotación de concurrencia, así que no son `Sendable` y un estado de pantalla los
//  rechaza. Bien que los rechace: el estado lleva una dirección de fichero, un título y un entero.
//
//  **La página visible tampoco está aquí.** Es una posición de lectura, no algo que el modelo de
//  pantalla decida; vive en el almacenamiento de escena, que es lo que sobrevive a la muerte del
//  proceso (research.md D-515).
//

import Foundation

enum PdfViewerUiState: Equatable {
    case loading
    case ready(fileUrl: URL, title: String, pageCount: Int)
    case error(PdfViewerError)
}

/// Los tres motivos por los que no se puede leer, **y son tres, no uno**.
enum PdfViewerError: Equatable {
    /// Protegido con contraseña.
    case locked
    /// Truncado, corrupto o sin páginas.
    case unreadable
    /// No se pudo obtener: red, almacenamiento, o algo inesperado.
    case document(DomainError)

    /// `true` cuando volver a intentarlo puede salir bien.
    ///
    /// Un documento protegido no se arregla reintentando: lo que hay es una salida. Ofrecer
    /// reintentar ahí sería invitar a pulsar un botón que no puede funcionar.
    var isRetryable: Bool {
        switch self {
        case .locked, .unreadable: false
        case .document: true
        }
    }
}
