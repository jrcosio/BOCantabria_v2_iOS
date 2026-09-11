//
//  HttpFeedDownloader.swift
//  The real download, with the limits the specification asks for.
//
//  **Tres cosas que URLSession no dice como Android las decía**, y que hay que escribir en vez de
//  traducir:
//
//  1. **No hay tiempo de conexión separado.** `timeoutIntervalForRequest` es inactividad y
//     `timeoutIntervalForResource` es el total del recurso. Los diez segundos de conexión de la
//     aplicación de origen se abandonan: distinguir «no conectó» de «conectó y calló» no cambia
//     nada de lo que la pantalla hace.
//  2. **`data(for:)` bufea primero y pregunta después.** Con él, un cuerpo de quinientos megabytes
//     ya está en memoria cuando se comprueba el tope. Se cuenta **mientras llega**.
//  3. **Las redirecciones se siguen solas.** Comprobar el esquema y el host de la dirección pedida
//     no dice nada sobre dónde acabó la petición, así que se valida también la final.
//

import CryptoKit
import Foundation

struct HttpFeedDownloader: FeedDownloader {
    /// Los tres intentos y sus esperas nominales. El jitter lo pone `AppRandom` (FR-006).
    static let retryDelays: [Double] = [2, 5, 15]
    static let requestTimeout: TimeInterval = 45
    static let resourceTimeout: TimeInterval = 60
    static let trustedHost = "www.cantabria.es"

    private let session: URLSession
    private let clock: AppClock
    private let random: AppRandom

    init(clock: AppClock, random: AppRandom, session: URLSession? = nil) {
        self.clock = clock
        self.random = random
        self.session = session ?? Self.makeSession()
    }

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        // **En `false` a propósito.** Con `true`, sin red la petición espera en vez de fallar, y el
        // estado «sin conexión» que la pantalla tiene que mostrar no llega nunca.
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = [
            // Identificarse ante el servicio oficial es un requisito (FR-007).
            "User-Agent": "BOCantabria-iOS/1.0 (+https://github.com/jrcosio/BOCantabria_v2_iOS)",
            "Accept": "application/rss+xml, application/xml, text/xml",
            "Accept-Charset": "utf-8",
        ]
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        return URLSession(configuration: configuration)
    }

    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult {
        var lastFailure = FeedFailure.timedOut

        for attempt in 0..<Self.retryDelays.count {
            if Task.isCancelled { return .failed(.cancelled) }

            switch await attemptFetch(definition, knownBodyHash: knownBodyHash) {
            case .failed(let failure) where failure.isRetryable:
                lastFailure = failure
                // La espera del siguiente intento, con jitter: sin él, diecinueve reintentos
                // vuelven a caer todos en el mismo instante sobre el servicio oficial.
                let delay = random.jittered(Self.retryDelays[attempt])
                do { try await clock.sleep(seconds: delay) } catch { return .failed(.cancelled) }
            case .failed(let failure):
                return .failed(failure)
            case let result:
                return result
            }
        }
        return .failed(lastFailure)
    }

    private func attemptFetch(
        _ definition: BocFeedDefinition,
        knownBodyHash: String?
    ) async -> FeedFetchResult {
        guard definition.url.scheme?.lowercased() == "https",
              definition.url.host() == Self.trustedHost
        else { return .failed(.untrusted) }

        do {
            let (stream, response) = try await session.bytes(from: definition.url)
            guard let http = response as? HTTPURLResponse else { return .failed(.untrusted) }

            // La dirección **final**, tras las redirecciones que la sesión siguió sola.
            if let finalUrl = http.url,
               finalUrl.scheme?.lowercased() != "https" || finalUrl.host() != Self.trustedHost {
                return .failed(.untrusted)
            }

            if let failure = Self.failure(forStatus: http.statusCode) { return .failed(failure) }

            // Rechazo previo por la longitud declarada: si ya dice que no cabe, no se empieza.
            if http.expectedContentLength > Int64(BocRssParser.maxBodyBytes) {
                return .failed(.untrusted)
            }

            var body = Data()
            body.reserveCapacity(min(Int(max(http.expectedContentLength, 0)), 1 << 20))
            for try await byte in stream {
                body.append(byte)
                // Contando **mientras llega**: ésta es la diferencia entre una defensa y un
                // comentario.
                if body.count > BocRssParser.maxBodyBytes { return .failed(.untrusted) }
            }

            let hash = Self.sha256(of: body)
            if let knownBodyHash, knownBodyHash == hash { return .notModified }
            return .fetched(body: body, bodyHash: hash)
        } catch let error as URLError {
            return .failed(Self.failure(for: error))
        } catch is CancellationError {
            return .failed(.cancelled)
        } catch {
            return .failed(.timedOut)
        }
    }

    static func failure(forStatus status: Int) -> FeedFailure? {
        switch status {
        case 200..<300: nil
        case 408, 429: .timedOut
        case 500...: .serverError
        default: .rejected
        }
    }

    static func failure(for error: URLError) -> FeedFailure {
        switch error.code {
        case .cancelled: .cancelled
        case .timedOut: .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        default: .timedOut
        }
    }

    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
