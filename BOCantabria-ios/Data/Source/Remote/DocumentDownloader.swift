//
//  DocumentDownloader.swift
//  Fetching the official document, and the ways of refusing to believe it.
//
//  **El rechazo viaja como valor, no como excepción**, igual que en la fuente de feeds de la 003 y
//  por la misma razón: el motivo tiene que llegar arriba para poder registrarlo, y una excepción
//  por cada forma de desconfiar convertiría el repositorio en una escalera de capturas.
//

import Foundation

/// Por qué no nos creemos lo que ha llegado.
///
/// **El orden de la enumeración es el orden en que se comprueban**, y ese orden es parte del
/// requisito: se rechaza en cuanto se sabe. Mirar el host después de haberse bajado cinco megas de
/// una página de error es haber pagado el precio para nada (research.md D-503).
enum DocumentRejection: String, Sendable, Equatable {
    /// No es un canal seguro. Se mira **antes de conectar**.
    case insecureScheme = "INSECURE_SCHEME"
    /// No apunta al servicio del boletín. Antes de conectar, **y otra vez sobre el destino final**.
    case unexpectedHost = "UNEXPECTED_HOST"
    /// El servicio no lo declara documento portátil.
    case unexpectedType = "UNEXPECTED_TYPE"
    /// Lo declaraba, y sus primeros bytes dicen otra cosa.
    case notAPdf = "NOT_A_PDF"
    /// Pasa del tope. Se corta **mientras llega**.
    case tooLarge = "TOO_LARGE"
    case httpError = "HTTP_ERROR"
    case network = "NETWORK"
    /// No se pudo escribir en el disco.
    case storage = "STORAGE"
    /// **No es un fallo.** Quien la pidió se fue.
    case cancelled = "CANCELLED"

    /// Cómo lo ve el dominio. `DomainError` **no crece** por esto.
    ///
    /// La pantalla hace lo mismo con los cinco de validación —explicar y ofrecer reintentar—, así
    /// que distinguirlos arriba no cambiaría nada. El motivo exacto viaja **al registro**, que es
    /// donde se diagnostica y que no sale del dispositivo.
    var domainError: DomainError {
        switch self {
        case .network: .network
        case .storage: .storage
        case .cancelled: .cancelled
        case .insecureScheme, .unexpectedHost, .unexpectedType, .notAPdf, .tooLarge, .httpError: .unknown
        }
    }
}

enum DocumentDownloadResult: Sendable, Equatable {
    case downloaded(byteCount: Int64, checksum: String)
    case rejected(DocumentRejection)
}

protocol DocumentDownloader: Sendable {
    /// Escribe en `destination` —siempre un fichero temporal— y **nunca lanza**.
    ///
    /// - Parameter progress: se llama al terminar cada trozo. Es `async` a propósito: da
    ///   contrapresión y evita sembrar una tarea por cada bloque de sesenta y cuatro kibibytes.
    ///   `totalBytes` es opcional porque el servicio puede no declarar la longitud.
    func download(
        from url: URL,
        into destination: URL,
        progress: @Sendable (_ bytesRead: Int64, _ totalBytes: Int64?) async -> Void
    ) async -> DocumentDownloadResult
}
