//
//  ScenarioDocumentDownloader.swift
//  The seam that lets a UI test see the viewer without going out to the network.
//
//  **No hay un tercer argumento de lanzamiento**, y es deliberado: `LaunchConfiguration` lleva
//  escrita la promesa de que la costura «se sustituye, no se amplía», y la feature del arranque ya
//  gastó su excepción. `DataScenario` ya es el mando que gobierna de dónde salen los datos, y el
//  documento es un dato más (research.md D-524).
//
//  **El documento se sintetiza en código, no se lee de una muestra.** Las muestras viven en el
//  bundle de pruebas y **el proceso de la aplicación no lo ve**, como el sembrador de escenarios ya
//  explica. Además, unos bytes literales dan una huella constante que se puede afirmar.
//

import CryptoKit
import Foundation

/// Qué devuelve el enlace del documento en un escenario de prueba.
enum DocumentOutcome: Sendable {
    case ready
    case rejected
    case tooLarge
    case unavailable
}

struct ScenarioDocumentDownloader: DocumentDownloader {
    let outcome: DocumentOutcome

    func download(
        from url: URL,
        into destination: URL,
        progress: @Sendable (Int64, Int64?) async -> Void
    ) async -> DocumentDownloadResult {
        switch outcome {
        case .ready:
            let bytes = Self.onePagePdf
            guard (try? bytes.write(to: destination)) != nil else { return .rejected(.storage) }
            await progress(Int64(bytes.count), Int64(bytes.count))
            return .downloaded(byteCount: Int64(bytes.count), checksum: Self.checksum(of: bytes))
        case .rejected:
            // Lo que un servicio sin compromiso de disponibilidad devuelve cualquier martes: algo
            // que no es el anuncio.
            return .rejected(.notAPdf)
        case .tooLarge:
            return .rejected(.tooLarge)
        case .unavailable:
            return .rejected(.network)
        }
    }

    private static func checksum(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Un documento portátil mínimo de una página, con texto visible.
    ///
    /// Es el mismo que las muestras de prueba, escrito a mano por la misma razón: el sistema no
    /// tiene ninguna herramienta de PDF y unos bytes literales son deterministas.
    static let onePagePdf: Data = {
        let contenido = "BT /F1 18 Tf 72 700 Td (Boletin Oficial de Cantabria) Tj ET"
        var objetos: [String] = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
                + "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
            "<< /Length \(contenido.utf8.count) >>\nstream\n\(contenido)\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ]
        var salida = "%PDF-1.4\n"
        var desplazamientos: [Int] = []
        for (indice, cuerpo) in objetos.enumerated() {
            desplazamientos.append(salida.utf8.count)
            salida += "\(indice + 1) 0 obj\n\(cuerpo)\nendobj\n"
        }
        let xref = salida.utf8.count
        salida += "xref\n0 \(objetos.count + 1)\n0000000000 65535 f \n"
        for desplazamiento in desplazamientos {
            salida += String(format: "%010d 00000 n \n", desplazamiento)
        }
        salida += "trailer\n<< /Size \(objetos.count + 1) /Root 1 0 R >>\n"
            + "startxref\n\(xref)\n%%EOF\n"
        objetos.removeAll()
        return Data(salida.utf8)
    }()
}
