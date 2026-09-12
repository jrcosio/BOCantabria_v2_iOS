//
//  HttpDocumentDownloader.swift
//  The real download of the official document.
//
//  **Es hermano de `HttpFeedDownloader` y hay que leerlos juntos.** De allí vienen tal cual la
//  guarda de esquema y host antes de conectar, la revalidación del destino **final** tras las
//  redirecciones que la sesión sigue sola, y el conteo mientras el cuerpo llega. Tres diferencias,
//  y las tres son decisiones:
//
//  1. **A disco, no a memoria.** El tope del feed son cinco mebibytes y el del documento
//     veinticinco megas. Se escribe en trozos de sesenta y cuatro kibibytes con la huella calculada
//     al vuelo, así que nunca hay más de un trozo vivo (research.md D-502).
//  2. **`FileHandle` y no `OutputStream`.** El segundo devuelve `-1` y deja el motivo en una
//     propiedad opcional que hay que acordarse de consultar; con el disco lleno, el fallo se pierde
//     en silencio. Eso es exactamente el defecto que FR-029 prohíbe. `write(contentsOf:)` **lanza**.
//  3. **Un solo intento.** El feed reintenta tres veces porque son diecinueve peticiones pequeñas y
//     automáticas que nadie mira. Veinticinco megas reintentados tres veces son setenta y cinco de
//     los datos de la persona, gastados mientras mira una pantalla que no dice por qué tarda. El
//     reintento lo pide ella con el botón (D-504).
//
//  **Y el host NO es el mismo que el de los feeds.** Aquéllos viven en `www.cantabria.es` y los
//  documentos en `boc.cantabria.es`. Confundirlos rechazaría todos los documentos o, peor,
//  aceptaría cualquiera de los dos en los dos sitios.
//

import CryptoKit
import Foundation

struct HttpDocumentDownloader: DocumentDownloader {
    /// Veinticinco megas. Es la cifra que la aplicación de origen usó y midió, y es una decisión de
    /// producto: cuánto de los datos de la persona puede gastar un solo anuncio.
    static let maxDocumentBytes: Int64 = 25 * 1024 * 1024

    /// El servicio que sirve los documentos. **No es `www.cantabria.es`.**
    static let trustedHost = "boc.cantabria.es"

    /// Un documento tarda más que un feed: los 45/60 s de aquél se le quedan cortos.
    static let requestTimeout: TimeInterval = 60
    static let resourceTimeout: TimeInterval = 180

    /// Sesenta y cuatro kibibytes. Es lo máximo que llega a estar vivo en memoria.
    static let chunkSize = 64 * 1024

    /// `%PDF-`. Los cinco primeros bytes de un documento portátil.
    static let pdfMagic: [UInt8] = [0x25, 0x50, 0x44, 0x46, 0x2D]

    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        // En `false` a propósito, igual que en los feeds: con `true`, sin red la petición espera en
        // vez de fallar, y el estado que la pantalla tiene que mostrar no llega nunca.
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = [
            "User-Agent": "BOCantabria-iOS/1.0 (+https://github.com/jrcosio/BOCantabria_v2_iOS)",
            "Accept": "application/pdf",
        ]
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        return URLSession(configuration: configuration)
    }

    /// **`@concurrent` no es decoración.** Con `SWIFT_APPROACHABLE_CONCURRENCY = YES`, una
    /// `nonisolated async func` hereda el ejecutor de quien la llama. Calcular la huella de
    /// veinticinco megas desde el actor principal lo haría *en* el actor principal, y el compilador
    /// no diría nada.
    @concurrent
    func download(
        from url: URL,
        into destination: URL,
        progress: @Sendable (Int64, Int64?) async -> Void
    ) async -> DocumentDownloadResult {
        // 1 y 2 · Antes de conectar. No se abre el enchufe.
        guard url.scheme?.lowercased() == "https" else { return .rejected(.insecureScheme) }
        guard url.host() == Self.trustedHost else { return .rejected(.unexpectedHost) }

        do {
            let (stream, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse else { return .rejected(.network) }

            // 3 · El destino **final**, tras las redirecciones que la sesión siguió sola. Sin esto,
            // comprobar la dirección pedida no dice nada sobre dónde acabó la petición.
            if let finalUrl = http.url,
               finalUrl.scheme?.lowercased() != "https" || finalUrl.host() != Self.trustedHost {
                return .rejected(.unexpectedHost)
            }

            // 4 · Estado.
            guard (200..<300).contains(http.statusCode) else { return .rejected(.httpError) }

            // 5 · Tipo declarado.
            let declaredType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            guard declaredType.contains("application/pdf") else { return .rejected(.unexpectedType) }

            // 6 · Longitud declarada. Si ya dice que no cabe, no se empieza.
            let declaredLength = http.expectedContentLength
            if declaredLength > Self.maxDocumentBytes { return .rejected(.tooLarge) }
            let total: Int64? = declaredLength > 0 ? declaredLength : nil

            return await write(stream, to: destination, total: total, progress: progress)
        } catch let error as URLError {
            return .rejected(Self.rejection(for: error))
        } catch is CancellationError {
            return .rejected(.cancelled)
        } catch {
            return .rejected(.network)
        }
    }

    /// El bucle: acumular, comprobar, escribir, resumir.
    private func write(
        _ stream: URLSession.AsyncBytes,
        to destination: URL,
        total: Int64?,
        progress: @Sendable (Int64, Int64?) async -> Void
    ) async -> DocumentDownloadResult {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: destination)
        else { return .rejected(.storage) }
        defer { try? handle.close() }

        var hasher = SHA256()
        var buffer: [UInt8] = []
        buffer.reserveCapacity(Self.chunkSize)
        var head: [UInt8] = []
        var written: Int64 = 0

        do {
            for try await byte in stream {
                // 7 · Los cinco primeros bytes. Se rechaza en cuanto se sabe, no al terminar.
                if head.count < Self.pdfMagic.count {
                    head.append(byte)
                    if head.count == Self.pdfMagic.count, head != Self.pdfMagic {
                        return .rejected(.notAPdf)
                    }
                }

                buffer.append(byte)
                written += 1

                // 8 · El tope, **contando mientras llega**. Ésta es la diferencia entre una defensa
                // y un comentario.
                if written > Self.maxDocumentBytes { return .rejected(.tooLarge) }

                if buffer.count == Self.chunkSize {
                    hasher.update(data: buffer)
                    do { try handle.write(contentsOf: buffer) } catch { return .rejected(.storage) }
                    // `removeAll(keepingCapacity:)` conserva la reserva: sin él, cada trozo
                    // vuelve a pedir memoria.
                    buffer.removeAll(keepingCapacity: true)
                    await progress(written, total)
                    if Task.isCancelled { return .rejected(.cancelled) }
                }
            }
        } catch let error as URLError {
            return .rejected(Self.rejection(for: error))
        } catch is CancellationError {
            return .rejected(.cancelled)
        } catch {
            return .rejected(.network)
        }

        // Un cuerpo más corto que la firma no llegó a comprobarse arriba.
        guard head == Self.pdfMagic else { return .rejected(.notAPdf) }

        if !buffer.isEmpty {
            hasher.update(data: buffer)
            do { try handle.write(contentsOf: buffer) } catch { return .rejected(.storage) }
        }
        await progress(written, total)

        let checksum = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return .downloaded(byteCount: written, checksum: checksum)
    }

    static func rejection(for error: URLError) -> DocumentRejection {
        switch error.code {
        case .cancelled: .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .network
        default: .network
        }
    }
}
