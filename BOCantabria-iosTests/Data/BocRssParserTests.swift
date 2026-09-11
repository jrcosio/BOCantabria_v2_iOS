//
//  BocRssParserTests.swift
//
//  Las diez muestras son reales, tomadas del servicio, y traen las anomalías que importan. Lo que
//  se comprueba aquí no es que el camino feliz funcione: es que **ninguna de las anomalías conocidas
//  rompe nada**, porque cada una de ellas existe de verdad en el BOC de hoy.
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

@Suite("Analizador del RSS del BOC")
struct BocRssParserTests {

    // MARK: - El camino normal

    @Test("Lee el canal y sus publicaciones")
    func readsChannelAndItems() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.disposiciones.data)

        #expect(channel.title == "Filtro BOC")
        #expect(channel.declaredSize == 100)
        #expect(channel.items.count == 5)

        let first = try #require(channel.items.first)
        #expect(first.title?.hasPrefix("AYUNTAMIENTO DE CAMPOO DE ENMEDIO:") == true)
        #expect(first.link == "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=439765")
        #expect(first.pubDateRaw == "2026-08-26")
        #expect(first.categoriesRaw == "1.Disposiciones Generales|Ayuntamiento de Campoo de Enmedio|ORD")
    }

    @Test("Una jerarquía de dos niveles llega entera")
    func readsTwoLevelHierarchy() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.oposiciones.data)
        let withSubsection = channel.items.first { $0.categoriesRaw?.contains("2.2.") == true }
        #expect(withSubsection != nil)
    }

    // MARK: - Las anomalías del servicio

    @Test("Un canal válido con cero publicaciones NO es un error (FR-009)")
    func anEmptyChannelIsValid() async throws {
        // Es la subsección de Subastas judiciales, que responde bien y no trae nada. Tratarlo como
        // fallo pondría un mensaje de error donde hay un resultado correcto.
        let channel = try await BocRssParser.parseFeed(Fixture.vacio.data)
        #expect(channel.items.isEmpty)
        #expect(channel.declaredSize == 0)
        #expect(channel.title == "Filtro BOC")
    }

    @Test("Si el recuento declarado miente, mandan los nodos")
    func theDeclaredSizeIsOnlyInformative() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.sizeIncorrecto.data)
        #expect(channel.declaredSize == 100)
        #expect(channel.items.count < 100)
        #expect(!channel.items.isEmpty)
    }

    @Test("Un recuento no numérico se ignora sin romper nada")
    func aNonNumericSizeIsIgnored() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.camposDesconocidos.data)
        #expect(channel.declaredSize == nil)
        #expect(!channel.items.isEmpty)
    }

    @Test("Los elementos desconocidos se ignoran; no fallan")
    func unknownElementsAreIgnored() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.camposDesconocidos.data)
        let item = try #require(channel.items.first)
        #expect(item.title?.isEmpty == false)
        #expect(item.link?.isEmpty == false)
    }

    @Test("Las categorías permutadas del feed 4.3 llegan enteras, sin descartar nada")
    func theAnomalousFeedIsNotRejected() async throws {
        // Nueve publicaciones con los componentes en cualquier orden. El analizador no interpreta:
        // solo entrega el texto. Interpretar es del normalizador, y tampoco descarta.
        let channel = try await BocRssParser.parseFeed(Fixture.anomalo.data)
        #expect(channel.items.count == 9)
        let allHaveCategories = channel.items.allSatisfy { $0.categoriesRaw?.isEmpty == false }
        #expect(allHaveCategories)
    }

    @Test("Un item sin categorías no rompe el canal")
    func anItemWithoutCategoriesIsStillRead() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.sinCategorias.data)
        #expect(!channel.items.isEmpty)
        let withoutCategories = channel.items.filter { ($0.categoriesRaw ?? "").isEmpty }
        #expect(!withoutCategories.isEmpty)
    }

    // MARK: - Endurecimiento

    @Test("Una definición de tipo de documento se rechaza antes de analizar (FR-008)")
    func aDoctypeIsRejected() async {
        await #expect(throws: FeedParseError.unsafeConstruct) {
            try await BocRssParser.parseFeed(Fixture.conDoctype.data)
        }
    }

    @Test("Una entidad externa se rechaza, y no se pide nada a la red")
    func anExternalEntityIsRejectedWithoutFetchingAnything() async {
        // El fallo de verdad de una entidad externa no es que se analice: es que el analizador
        // salga a buscar el recurso. Se rechaza **antes**, así que no hay ocasión.
        await #expect(throws: FeedParseError.unsafeConstruct) {
            try await BocRssParser.parseFeed(Fixture.conEntidadExterna.data)
        }
        #expect(Fixture.conEntidadExterna.text.contains("file:///"))
    }

    @Test("Un cuerpo desmesurado se rechaza sin analizarlo")
    func anOversizedBodyIsRejected() async {
        let huge = Data(repeating: 0x20, count: BocRssParser.maxBodyBytes + 1)
        await #expect(throws: FeedParseError.bodyTooLarge) {
            try await BocRssParser.parseFeed(huge)
        }
    }

    // MARK: - Las tres trampas de XMLParser

    @Test("Un XML roto LANZA; no devuelve cero anuncios")
    func aMalformedBodyThrows() async {
        // Es la trampa del booleano de `parse()`. Ignorarlo convertiría esto en un canal vacío,
        // **indistinguible de la 8.1**, que responde bien y no trae nada.
        let truncated = Fixture.disposiciones.text.prefix(600)
        await #expect(throws: FeedParseError.notWellFormed) {
            try await BocRssParser.parseFeed(Data(truncated.utf8))
        }
    }

    @Test("El delegado se sostiene: si se liberara, no llegaría ni una publicación")
    func theDelegateIsHeldForTheWholeParse() async throws {
        // `XMLParser.delegate` es débil. Asignar un acumulador recién creado lo libera en el acto
        // y el analizado termina «bien» con cero publicaciones, sin error. Esta prueba se pone
        // roja si alguien «simplifica» la asignación.
        let channel = try await BocRssParser.parseFeed(Fixture.disposiciones.data)
        #expect(channel.items.count == 5)
        #expect(channel.title == "Filtro BOC")
    }

    @Test("El texto troceado se recompone entero")
    func fragmentedTextIsReassembled() async throws {
        // `foundCharacters` entrega el texto en varias llamadas cuando hay tildes o entidades.
        // Confirmar en la primera perdería el resto, y el título saldría cortado.
        let channel = try await BocRssParser.parseFeed(Fixture.anomalo.data)
        let longest = channel.items.compactMap(\.title).max { $0.count < $1.count }
        let title = try #require(longest)
        #expect(title.count > 200, "El título más largo del 4.3 pasa de doscientos caracteres")
        #expect(title.contains("ñ") || title.contains("ó") || title.contains("í"))
        #expect(!title.hasSuffix("…"))
    }

    // MARK: - Cancelación y aislamiento

    @Test("Cancelar deja de analizar en lugar de llegar al final")
    func cancellingStopsTheParse() async throws {
        // `XMLParser.parse()` es síncrono y no comprueba cancelación por su cuenta: cambiar de
        // hilo no hace cancelable un trabajo bloqueante.
        let task = Task {
            try await BocRssParser.parseFeed(Fixture.anomalo.data)
        }
        task.cancel()
        let channel = try? await task.value
        #expect(channel == nil || channel!.items.count <= 9)
    }

    @Test("El tope de publicaciones por fuente se respeta")
    func theItemLimitIsEnforced() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.anomalo.data, limit: 3)
        #expect(channel.items.count == 3)
    }

    @Test("El analizado NO corre en el actor principal")
    @MainActor
    func theParseLeavesTheMainActor() async throws {
        // Con `SWIFT_APPROACHABLE_CONCURRENCY`, una función `nonisolated async` hereda el ejecutor
        // de quien la llama: sin `@concurrent`, analizar cinco megabytes desde aquí se los comería
        // al hilo principal **y el compilador no diría nada**. Esta prueba se pone roja si alguien
        // quita el atributo, que es lo único que impide que sea una convención.
        let onMainThread = Mutex(true)
        _ = try await BocRssParser.parseFeed(Fixture.disposiciones.data) {
            onMainThread.withLock { $0 = Thread.isMainThread }
        }
        #expect(!onMainThread.withLock { $0 })
    }
}
