//
//  PublicationNormalizer.swift
//  Turns what a source said into what the domain understands.
//
//  **La regla que manda sobre todas las demás**: la sección de una publicación es la de la fuente
//  de la que se obtuvo, nunca la que el campo de clasificación declare (FR-012). Ese campo se
//  conserva íntegro y sirve para enriquecer y verificar, no para clasificar.
//
//  No es teoría. El feed 4.3 trae sus nueve publicaciones con los componentes **permutados** —el
//  tipo de edición al principio, la sección al final, el organismo en medio—, así que cualquier
//  código que leyera una posición fija clasificaría mal y nadie lo notaría.
//

import CryptoKit
import Foundation

enum NormalizationOutcome: Sendable, Equatable {
    case accepted(Publication)
    case rejected(RejectionReason)
}

/// Por qué se descartó una publicación. Se registra: un descarte sin motivo es un misterio.
enum RejectionReason: String, Sendable, Equatable {
    case missingTitle = "MISSING_TITLE"
    case invalidLink = "INVALID_LINK"
    case invalidDate = "INVALID_DATE"
}

enum PublicationNormalizer {

    static func normalize(
        _ item: RssItemDTO,
        from definition: BocFeedDefinition
    ) -> NormalizationOutcome {
        // 1 · Los mínimos. Un item que no los cumple se rechaza **él solo**, con su motivo, sin
        // detener el procesamiento del resto de la fuente (FR-010).
        let title = (item.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .rejected(.missingTitle) }

        let rawLink = (item.link ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: rawLink), url.scheme?.lowercased() == "https" else {
            return .rejected(.invalidLink)
        }

        guard let date = BocDate(iso: (item.pubDateRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .rejected(.invalidDate)
        }

        let categories = parseCategories(item.categoriesRaw, definition: definition)
        let identity = identify(url: url, item: item, definition: definition)

        return .accepted(
            Publication(
                externalKey: identity.key,
                blobId: identity.blobId,
                idSource: identity.source,
                feedId: definition.feedId,
                // 2 · Sección y subsección **siempre** de la fuente.
                sectionCode: definition.sectionCode,
                subsectionCode: definition.subsectionCode,
                // 11 · El título entero. Recortar es cosa de la pantalla (FR-018).
                title: title,
                issuer: issuer(from: categories.organizationPath, title: title),
                organizationPath: categories.organizationPath,
                editionType: categories.editionType,
                publicationDate: date,
                documentUrl: url,
                // 3 · El campo original, sin tocar (FR-013).
                rawCategories: item.categoriesRaw,
                warnings: categories.warnings
            )
        )
    }

    // MARK: - El campo de clasificación

    private struct ParsedCategories {
        let editionType: EditionType
        let organizationPath: [String]
        let warnings: Set<ParserWarning>
    }

    /// Un componente que empieza por `1.`, `4.3.` y demás es un código de sección.
    ///
    /// Se declara calculada y no estática: `Regex` **no es `Sendable`**, así que una constante de
    /// ese tipo no compila bajo concurrencia estricta. Construirla cuesta menos que cualquier cosa
    /// que haya al otro extremo.
    private static var sectionCodePattern: Regex<AnyRegexOutput> {
        // swiftlint:disable:next force_try
        try! Regex(#"^\d+(?:\.\d+)?\."#)
    }

    private static func parseCategories(
        _ raw: String?,
        definition: BocFeedDefinition
    ) -> ParsedCategories {
        var warnings: Set<ParserWarning> = []

        let tokens = (raw ?? "")
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 8 · Sin clasificación: la sección la pone la fuente y el tipo queda desconocido.
        guard !tokens.isEmpty else {
            return ParsedCategories(
                editionType: .unknown,
                organizationPath: [],
                warnings: [.categoriesAbsent, .editionTypeMissing]
            )
        }

        // 4 · El tipo de edición se busca **en cualquier posición**, no en la última.
        let editionIndex = tokens.firstIndex { $0 == "ORD" || $0 == "EXT" }
        let editionType: EditionType = editionIndex.map {
            tokens[$0] == "ORD" ? .ordinary : .extraordinary
        } ?? .unknown
        if editionIndex == nil { warnings.insert(.editionTypeMissing) }

        // 7 · Si está, pero no al final, el orden no es de fiar. **No se descarta nada.**
        if let editionIndex, editionIndex != tokens.count - 1 {
            warnings.insert(.categoryOrderUnreliable)
        }

        // 5 · Los componentes con prefijo numérico son códigos; el resto, quitado el tipo, es la
        // ruta del organismo. **Ninguna posición es fija.**
        let pattern = sectionCodePattern
        var numericTokens: [String] = []
        var organizationPath: [String] = []
        for (index, token) in tokens.enumerated() {
            if index == editionIndex { continue }
            if token.firstMatch(of: pattern) != nil {
                numericTokens.append(token)
            } else {
                organizationPath.append(token)
            }
        }

        // 6 · Si el código declarado no corresponde al de la fuente, **manda la fuente** y se anota.
        let expected = definition.mostSpecificSectionCode
        let declaresExpected = numericTokens.contains { $0.hasPrefix(expected + ".") }
        if !numericTokens.isEmpty, !declaresExpected {
            warnings.insert(.categoryDoesNotMatchFeed)
        }

        return ParsedCategories(
            editionType: editionType,
            organizationPath: organizationPath,
            warnings: warnings
        )
    }

    // MARK: - Identidad

    private struct Identity {
        let key: String
        let blobId: String?
        let source: IdSource
    }

    /// 9 · La cascada de tres escalones, y **se registra cuál se usó** (FR-017): si mañana una
    /// publicación identificada por huella aparece con su identificador de verdad, hay que poder
    /// saber que ese registro es sustituible.
    ///
    /// **Nunca por título**: los títulos se repiten entre ayuntamientos.
    private static func identify(
        url: URL,
        item: RssItemDTO,
        definition: BocFeedDefinition
    ) -> Identity {
        if let blobId = blobId(in: url) {
            return Identity(key: "boc:\(blobId)", blobId: blobId, source: .blobId)
        }
        if let canonical = url.absoluteString.isEmpty ? nil : url.absoluteString {
            return Identity(key: canonical, blobId: nil, source: .canonicalUrl)
        }
        let material = [
            definition.feedId, item.pubDateRaw ?? "", item.title ?? "", item.categoriesRaw ?? "",
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(material.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return Identity(key: "sha256:\(hex)", blobId: nil, source: .contentHash)
    }

    private static func blobId(in url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "idAnuBlob" })?.value,
              !value.isEmpty,
              value.allSatisfy({ $0.isASCII && $0.isNumber })
        else { return nil }
        return value
    }

    // MARK: - Organismo

    /// 10 · El último elemento de la ruta; y si no hay ruta, el texto anterior al primer dos
    /// puntos del título. Es **auxiliar** y puede quedar nulo: no todos los títulos lo llevan.
    private static func issuer(from organizationPath: [String], title: String) -> String? {
        if let last = organizationPath.last { return last }
        guard let colon = title.firstIndex(of: ":") else { return nil }
        let prefix = title[title.startIndex..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? nil : prefix
    }
}
