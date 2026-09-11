//
//  FeedDownloader.swift
//  Brings one source's body, or says why it could not.
//
//  **Es la única interfaz del proyecto que puede fallar sin lanzar**, y es deliberado: devuelve el
//  fallo como valor para que el orquestador siga con las demás fuentes sin escaleras de `catch`.
//  Es lo que hace FR-004 barato en lugar de laborioso.
//

import Foundation

enum FeedFetchResult: Sendable, Equatable {
    case fetched(body: Data, bodyHash: String)
    /// La huella coincide con la conocida: no hay nada que volver a analizar (FR-022).
    case notModified
    case failed(FeedFailure)
}

/// Por qué falló una fuente. Se distingue lo que se reintenta de lo que no (FR-006).
enum FeedFailure: String, Sendable, Equatable {
    case timedOut = "TIMED_OUT"
    case offline = "OFFLINE"
    case serverError = "SERVER_ERROR"
    /// 4xx que no se reintenta: no se va a resolver solo.
    case rejected = "REJECTED"
    /// Esquema, host o tipo de contenido inesperados, o cuerpo desmesurado.
    case untrusted = "UNTRUSTED"
    case cancelled = "CANCELLED"

    /// Lo que merece otro intento. Un 404 no lo merece; un 503, sí.
    var isRetryable: Bool {
        switch self {
        case .timedOut, .offline, .serverError: true
        case .rejected, .untrusted, .cancelled: false
        }
    }
}

protocol FeedDownloader: Sendable {
    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult
}
