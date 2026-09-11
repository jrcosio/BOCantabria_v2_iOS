//
//  BocRssParser.swift
//  Reads one source, safely.
//
//  `XMLParser` es SAX y **`XMLDocument` no existe en iOS**, así que el analizado se escribe con
//  estado explícito y el orden de llegada importa. Tres cosas que no son obvias y que cada una
//  costó una prueba:
//
//  1. **`parser.delegate` es una referencia débil.** Asignar un acumulador recién creado lo libera
//     en el acto y el analizado no devuelve nada, **sin error ninguno**. Hay que sostenerlo.
//  2. **`foundCharacters` llega troceado.** Un título con tildes o con una entidad llega en varias
//     llamadas: hay que acumular y confirmar solo al cerrar el elemento.
//  3. **`parse()` devuelve un booleano.** Ignorarlo convierte un XML roto en «cero anuncios», que
//     es indistinguible de un feed vacío legítimo — y un feed vacío legítimo existe (FR-009).
//

import Foundation

enum FeedParseError: Error, Equatable, Sendable {
    /// El cuerpo trae una definición de tipo de documento o una entidad. Se rechaza **antes** de
    /// analizarlo (FR-008).
    case unsafeConstruct
    case notWellFormed
    case bodyTooLarge
}

enum BocRssParser {
    /// Tope de seguridad de publicaciones por fuente (FR-008).
    static let defaultItemLimit = 500
    /// Tope de tamaño del cuerpo, en bytes.
    static let maxBodyBytes = 5 * 1024 * 1024

    /// - Parameter onStart: instrumentación. La usa la prueba que demuestra que esto **no** corre
    ///   en el actor principal; en producción nadie la pasa. Con
    ///   `SWIFT_APPROACHABLE_CONCURRENCY` una función `nonisolated async` heredaría el ejecutor de
    ///   quien la llama, y sin `@concurrent` este analizado se comería el hilo principal sin que
    ///   el compilador dijera nada (research.md D-300).
    @concurrent
    static func parseFeed(
        _ body: Data,
        limit: Int = defaultItemLimit,
        onStart: (@Sendable () -> Void)? = nil
    ) async throws -> RssChannelDTO {
        onStart?()
        guard body.count <= maxBodyBytes else { throw FeedParseError.bodyTooLarge }
        try rejectUnsafeConstructs(in: body)

        let parser = XMLParser(data: body)
        // Las dos capas: la bandera histórica y el control moderno, que es el más fuerte.
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never

        // **Sostener el acumulador.** `delegate` es débil: sin este `let`, se libera aquí mismo.
        let accumulator = FeedAccumulator(limit: limit)
        parser.delegate = accumulator

        let succeeded = parser.parse()
        if let failure = accumulator.failure { throw failure }
        // Abortar a propósito —por el tope o por cancelación— también hace que `parse()` devuelva
        // `false`. Eso **no** es un XML roto: el canal que se lleva hasta ahí es válido.
        guard succeeded || accumulator.abortedOnPurpose else { throw FeedParseError.notWellFormed }
        return accumulator.channel
    }

    /// Guarda de texto **sobre bytes**, no sobre texto decodificado.
    ///
    /// Decodificar cinco megabytes para mirar los primeros doscientos sería un desperdicio, y peor:
    /// la codificación declarada puede no ser UTF-8, y una decodificación fallida convertiría la
    /// guarda en un pase libre. Buscar los bytes ASCII es independiente de la codificación.
    private static func rejectUnsafeConstructs(in body: Data) throws {
        let prefix = body.prefix(4096)
        for marker in ["<!DOCTYPE", "<!doctype", "<!ENTITY", "<!entity"] {
            if prefix.range(of: Data(marker.utf8)) != nil { throw FeedParseError.unsafeConstruct }
        }
    }
}

// MARK: - El acumulador

/// Estado explícito del analizado SAX.
///
/// **No es `Sendable` y no debe declararse que lo es.** Es una clase de Objective-C con estado
/// mutable; lo que la hace segura es que nace y muere dentro de la función `@concurrent` que la
/// usa, sin escapar a ninguna parte. En Swift 6 el aislamiento barato no es una anotación: es un
/// ámbito.
private final class FeedAccumulator: NSObject, XMLParserDelegate {
    private let limit: Int

    private var channelTitle: String?
    private var channelLink: String?
    private var channelDescription: String?
    private var declaredSize: Int?
    private var items: [RssItemDTO] = []

    private var insideItem = false
    private var itemTitle: String?
    private var itemLink: String?
    private var itemDate: String?
    private var itemCategories: String?

    /// Búfer del texto del elemento en curso. **`foundCharacters` llega troceado**: un título con
    /// una tilde o una entidad se entrega en varias llamadas, y confirmar en la primera perdería
    /// el resto.
    private var buffer = ""
    private var currentElement: String?

    private(set) var failure: FeedParseError?
    /// Se abortó por el tope o por cancelación, no por un XML mal formado.
    private(set) var abortedOnPurpose = false

    init(limit: Int) {
        self.limit = limit
    }

    var channel: RssChannelDTO {
        RssChannelDTO(
            title: channelTitle,
            link: channelLink,
            description: channelDescription,
            declaredSize: declaredSize,
            items: items
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        buffer = ""
        if elementName == "item" {
            insideItem = true
            itemTitle = nil
            itemLink = nil
            itemDate = nil
            itemCategories = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer {
            buffer = ""
            currentElement = nil
        }
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "item" {
            insideItem = false
            items.append(
                RssItemDTO(
                    title: itemTitle, link: itemLink,
                    pubDateRaw: itemDate, categoriesRaw: itemCategories
                )
            )
            // El tope de seguridad: una fuente no puede obligarnos a construir lo que quiera.
            if items.count >= limit {
                abortedOnPurpose = true
                parser.abortParsing()
            }
            // Cancelación: `parse()` es síncrono y no la comprueba por su cuenta, así que se mira
            // al cerrar cada item. El grano es suficiente: hay como mucho quinientos.
            if Task.isCancelled {
                abortedOnPurpose = true
                parser.abortParsing()
            }
            return
        }

        if insideItem {
            switch elementName {
            case "title": itemTitle = text
            case "link": itemLink = text
            case "pubDate": itemDate = text
            case "categorias": itemCategories = text
            default: break   // Lo desconocido se ignora, no rompe (FR-008).
            }
            return
        }

        switch elementName {
        case "title": channelTitle = text
        case "link": channelLink = text
        case "description": channelDescription = text
        case "size": declaredSize = Int(text)   // No numérico queda en nulo: manda el recuento real.
        default: break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        // Abortar a propósito —por el tope o por cancelación— también llega aquí. Lo que se
        // guarda es solo el fallo de verdad: si ya hay items y se abortó, el canal es válido.
        guard failure == nil, !abortedOnPurpose else { return }
        failure = .notWellFormed
    }
}
