//
//  SharedDocumentTransfer.swift
//  Handing the official document to the system's share sheet.
//
//  ## Por qué un tipo transferible y no un controlador de UIKit envuelto
//
//  Tres problemas y una sola respuesta (research.md D-517):
//
//  1. **El nombre.** El fichero en disco se llama con una huella de sesenta y cuatro caracteres
//     hexadecimales, porque la clave viene de la red y no puede entrar en una ruta. Compartirlo así
//     manda a la otra persona un adjunto ilegible. El nombre sugerido lo arregla (FR-042).
//  2. **El «preparando».** La hoja necesita el elemento de antemano, y cuando el documento no está
//     descargado no lo hay. Pero **el cierre de exportación es asíncrono**: la hoja se abre al
//     instante y, al elegir destino, el sistema espera a que el proveedor resuelva enseñando **su
//     propio** indicador. Un solo toque (FR-039).
//  3. **La constitución.** Un `UIActivityViewController` envuelto es, literalmente, **una pantalla
//     escrita en UIKit**, y la única excepción que la constitución concede es el visor. Usarlo
//     exigiría una enmienda.
//
//  ## `allowAccessingOriginalFile` se queda en falso, y se escribe por qué
//
//  El fichero vive en el directorio de cachés, que **el sistema puede vaciar mientras la hoja está
//  abierta**. Dejando que el receptor acceda al original, se encontraría una ruta vacía y guardaría
//  un fichero de cero bytes, sin error visible. Con la copia, el sistema se lleva los bytes antes.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension SharedDocument: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            SentTransferredFile(try await resolve(document), allowAccessingOriginalFile: false)
        }
        .suggestedFileName { $0.fileName }
    }

    /// Dónde está el fichero que se va a entregar.
    ///
    /// Si no hay copia local, lanza. **Y eso es correcto**: la decisión de degradar al enlace se
    /// toma **antes de dibujar** —en el caso de uso— y no aquí dentro, porque desde aquí no hay
    /// forma de enseñar nuestra explicación (FR-040, FR-041).
    private static func resolve(_ document: SharedDocument) async throws -> URL {
        guard let path = document.localPath else { throw ShareError.notAvailable }
        return URL(fileURLWithPath: path)
    }

    enum ShareError: Error { case notAvailable }
}
