//
//  PdfDocumentProbe.swift
//  Can this document be read, and if not, why not.
//
//  **Tres desenlaces distintos, y confundirlos tiene consecuencias opuestas** (FR-036, research.md
//  D-514):
//
//  | Lo que se observa | Qué es | Qué se hace |
//  |---|---|---|
//  | No se puede construir | ilegible o truncado | error con salida |
//  | Se construye y está **bloqueado** | contraseña de usuario | error con salida, texto propio |
//  | Se construye, **cifrado** pero no bloqueado | restricción de impresión o copia | **se abre** |
//  | Se construye y no tiene páginas | ilegible | error con salida |
//
//  La tercera fila es la que importa: rechazar por «cifrado» sería un falso negativo **sobre
//  documentos oficiales legítimos**. Un boletín publicado con restricción de copia se lee
//  perfectamente, y la cabecera de PDFKit lo dice: «con la contraseña, un PDF puede desbloquearse;
//  aun así sigue indicando que está cifrado».
//
//  **Y no vale mirar si el dibujado falla.** Se comprobó al generar las muestras: el documento
//  protegido **sí devuelve miniatura** aunque esté bloqueado. Lo único que lo distingue es la
//  propiedad.
//

import Foundation
import PDFKit

enum PdfReadability: Sendable, Equatable {
    case readable(pageCount: Int)
    /// Protegido con contraseña de usuario.
    case locked
    /// No se puede abrir: truncado, corrupto o sin páginas.
    case unreadable
}

enum PdfDocumentProbe {
    /// **`@concurrent` no es decoración.**
    ///
    /// Con `SWIFT_APPROACHABLE_CONCURRENCY = YES`, una `nonisolated async func` hereda el ejecutor
    /// de quien la llama. Sin el atributo, abrir un documento desde la vista lo abriría **en el
    /// actor principal**, y el compilador no diría nada: el síntoma no es un error, es que la
    /// pantalla se congela y se diagnostica como «el visor es lento».
    ///
    /// - Parameter onStart: costura de prueba. Es lo único que permite afirmar que esto **no**
    ///   corre en el actor principal; sin ella, `@concurrent` sería una convención.
    @concurrent
    static func inspect(
        _ fileUrl: URL,
        onStart: (@Sendable () -> Void)? = nil
    ) async -> PdfReadability {
        onStart?()
        guard let document = PDFDocument(url: fileUrl) else { return .unreadable }
        if document.isLocked { return .locked }
        guard document.pageCount > 0 else { return .unreadable }
        return .readable(pageCount: document.pageCount)
    }
}
