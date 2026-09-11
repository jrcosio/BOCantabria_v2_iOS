//
//  PublicationNormalizerTests.swift
//
//  Es la pieza con más casos límite de la feature, y ninguno es inventado: todos salen de lo que
//  el BOC publica hoy. La matriz completa está en FR-082.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Normalizador de publicaciones")
struct PublicationNormalizerTests {

    private let disposiciones = BocFeedCatalog.named("6802081")!   // sección 1, sin subsección
    private let oposiciones = BocFeedCatalog.named("6802085")!     // 2.2
    private let seguridadSocial = BocFeedCatalog.named("6802091")! // 4.3, el anómalo

    private func item(
        title: String = "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva.",
        link: String = "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=439765",
        date: String = "2026-08-26",
        categories: String? = "1.Disposiciones Generales|Ayuntamiento de Piélagos|ORD"
    ) -> RssItemDTO {
        RssItemDTO(title: title, link: link, pubDateRaw: date, categoriesRaw: categories)
    }

    private func accepted(_ outcome: NormalizationOutcome) throws -> Publication {
        guard case .accepted(let publication) = outcome else {
            Issue.record("Se esperaba una publicación aceptada, y llegó \(outcome)")
            throw TestFailure.unexpected
        }
        return publication
    }

    enum TestFailure: Error { case unexpected }

    // MARK: - Los mínimos

    @Test("Acepta lo que trae los cuatro campos y los traduce")
    func acceptsAWellFormedItem() throws {
        let publication = try accepted(PublicationNormalizer.normalize(item(), from: disposiciones))
        #expect(publication.externalKey == "boc:439765")
        #expect(publication.blobId == "439765")
        #expect(publication.idSource == .blobId)
        #expect(publication.sectionCode == "1")
        #expect(publication.subsectionCode == nil)
        #expect(publication.editionType == .ordinary)
        #expect(publication.publicationDate.iso == "2026-08-26")
        #expect(publication.issuer == "Ayuntamiento de Piélagos")
        #expect(publication.warnings.isEmpty)
    }

    /// Un caso de rechazo. Es un `struct` y no una tupla a propósito: una lista de tuplas de
    /// cuatro con miembros inferidos hace que el comprobador de tipos tarde **minutos** en
    /// resolver el fichero, y el síntoma es que la suite no termina.
    struct RejectionCase: Sendable {
        let reason: RejectionReason
        let title: String
        let link: String
        let date: String
    }

    @Test("Rechaza, con su motivo, lo que no cumple los mínimos (FR-010)", arguments: [
        RejectionCase(reason: .missingTitle, title: "", link: "https://boc.cantabria.es/x?idAnuBlob=1", date: "2026-08-26"),
        RejectionCase(reason: .invalidLink, title: "Título", link: "http://boc.cantabria.es/x?idAnuBlob=1", date: "2026-08-26"),
        RejectionCase(reason: .invalidLink, title: "Título", link: "", date: "2026-08-26"),
        RejectionCase(reason: .invalidDate, title: "Título", link: "https://boc.cantabria.es/x?idAnuBlob=1", date: "26/08/2026"),
        RejectionCase(reason: .invalidDate, title: "Título", link: "https://boc.cantabria.es/x?idAnuBlob=1", date: ""),
    ])
    func rejectsWithAReason(testCase: RejectionCase) {
        let outcome = PublicationNormalizer.normalize(
            item(title: testCase.title, link: testCase.link, date: testCase.date),
            from: disposiciones
        )
        #expect(outcome == .rejected(testCase.reason))
    }

    // MARK: - La sección la manda la fuente

    @Test("La sección sale de la fuente, no del campo de clasificación (FR-012)")
    func theSectionComesFromTheFeed() throws {
        // La clasificación dice sección 1; la fuente es la 2.2. Manda la fuente.
        let outcome = PublicationNormalizer.normalize(
            item(categories: "1.Disposiciones Generales|Ayuntamiento de Santoña|ORD"),
            from: oposiciones
        )
        let publication = try accepted(outcome)
        #expect(publication.sectionCode == "2")
        #expect(publication.subsectionCode == "2.2")
        #expect(publication.warnings.contains(.categoryDoesNotMatchFeed))
    }

    @Test("El campo original se conserva intacto (FR-013)")
    func theRawFieldIsKept() throws {
        let raw = "4.Economía, Hacienda y Seguridad Social|4.3.Actuaciones en materia de Seguridad Social|Entidad|ORD"
        let publication = try accepted(
            PublicationNormalizer.normalize(item(categories: raw), from: seguridadSocial)
        )
        #expect(publication.rawCategories == raw)
    }

    // MARK: - Profundidad y orden de los componentes

    struct DepthCase: Sendable {
        let raw: String
        let expectedPath: [String]
    }

    @Test("Tres, cuatro y cinco componentes", arguments: [
        DepthCase(
            raw: "3.Contratación Administrativa|Junta Vecinal de Cosío|ORD",
            expectedPath: ["Junta Vecinal de Cosío"]
        ),
        DepthCase(
            raw: "2.Autoridades y Personal|2.2.Cursos, Oposiciones y Concursos|Ayuntamiento de Santoña|ORD",
            expectedPath: ["Ayuntamiento de Santoña"]
        ),
        DepthCase(
            raw: "2.Autoridades y Personal|2.2.Cursos|Consejería de Salud|Secretaría General|ORD",
            expectedPath: ["Consejería de Salud", "Secretaría General"]
        ),
    ])
    func handlesEveryDepth(testCase: DepthCase) throws {
        let raw = testCase.raw
        let expectedPath = testCase.expectedPath
        let publication = try accepted(
            PublicationNormalizer.normalize(item(categories: raw), from: oposiciones)
        )
        #expect(publication.organizationPath == expectedPath)
    }

    @Test("El tipo de edición se detecta en cualquier posición (FR-014)", arguments: [
        "2.Autoridades|2.2.Cursos|Ayuntamiento|ORD",
        "ORD|2.Autoridades|2.2.Cursos|Ayuntamiento",
        "2.Autoridades|ORD|2.2.Cursos|Ayuntamiento",
    ])
    func findsTheEditionTypeAnywhere(raw: String) throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(item(categories: raw), from: oposiciones)
        )
        #expect(publication.editionType == .ordinary)
        // Y el tipo **no** acaba en la ruta del organismo.
        #expect(!publication.organizationPath.contains("ORD"))
    }

    @Test("Una edición extraordinaria se reconoce igual")
    func recognisesExtraordinaryEditions() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(categories: "2.Autoridades|2.2.Cursos|Ayuntamiento|EXT"), from: oposiciones
            )
        )
        #expect(publication.editionType == .extraordinary)
    }

    @Test("Si el tipo no está al final, se anota que el orden no es de fiar (FR-015)")
    func flagsUnreliableOrdering() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(categories: "ORD|2.2.Cursos|Ayuntamiento de Limpias|2.Autoridades"),
                from: oposiciones
            )
        )
        #expect(publication.warnings.contains(.categoryOrderUnreliable))
        // **Y no se descarta.** Es la diferencia entre anotar una anomalía y perder un anuncio.
        #expect(publication.editionType == .ordinary)
        #expect(publication.organizationPath == ["Ayuntamiento de Limpias"])
    }

    @Test("Sin tipo de edición: desconocido y anotado, nunca descartado")
    func missingEditionTypeIsUnknown() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(categories: "1.Disposiciones Generales|Ayuntamiento de Piélagos"),
                from: disposiciones
            )
        )
        #expect(publication.editionType == .unknown)
        #expect(publication.warnings.contains(.editionTypeMissing))
    }

    @Test("Componentes vacíos y barra final se ignoran")
    func emptyTokensAreDropped() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(categories: "1.Disposiciones Generales||Ayuntamiento de Piélagos|ORD|"),
                from: disposiciones
            )
        )
        #expect(publication.organizationPath == ["Ayuntamiento de Piélagos"])
        #expect(publication.editionType == .ordinary)
    }

    @Test("Sin clasificación: sección de la fuente, tipo desconocido y anotado")
    func absentCategoriesAreHandled() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(item(categories: nil), from: oposiciones)
        )
        #expect(publication.sectionCode == "2")
        #expect(publication.subsectionCode == "2.2")
        #expect(publication.editionType == .unknown)
        #expect(publication.warnings.contains(.categoriesAbsent))
        #expect(publication.rawCategories == nil)
    }

    // MARK: - El desorden real del feed 4.3

    @Test("Las nueve publicaciones del 4.3 se aceptan, con su aviso y ninguna descartada")
    func theRealAnomalousFeedSurvivesIntact() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.anomalo.data)
        let outcomes = channel.items.map {
            PublicationNormalizer.normalize($0, from: seguridadSocial)
        }

        let publications = outcomes.compactMap { outcome -> Publication? in
            if case .accepted(let publication) = outcome { return publication }
            return nil
        }
        #expect(publications.count == 9, "Ninguna se descarta: el documento lo dice expresamente")

        // Todas quedan clasificadas en 4.3, por la fuente, dijeran lo que dijeran sus categorías.
        let allInSubsection = publications.allSatisfy { $0.subsectionCode == "4.3" }
        #expect(allInSubsection)

        // Y las que traen el orden permutado llevan su aviso: **siete de las nueve**. Las otras
        // dos traen el tipo de edición al final, que es la forma normal.
        //
        // No confundir esta cifra con las ocho del contraste contra el servicio real de la
        // aplicación de origen: aquélla se midió sobre 1.709 publicaciones vivas y ésta sobre las
        // nueve de la muestra.
        let flagged = publications.filter { $0.warnings.contains(.categoryOrderUnreliable) }
        #expect(flagged.count == 7)

        // Y las dos que no llevan aviso lo llevan por el motivo correcto: su tipo va al final.
        let clean = publications.filter { !$0.warnings.contains(.categoryOrderUnreliable) }
        #expect(clean.count == 2)
        let allEndWithEdition = clean.allSatisfy { ($0.rawCategories ?? "").hasSuffix("|ORD") }
        #expect(allEndWithEdition)
    }

    // MARK: - Identidad

    @Test("Sin identificador en el enlace se baja al siguiente escalón (FR-017)")
    func fallsBackToTheCanonicalUrl() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(link: "https://boc.cantabria.es/boces/verAnuncioAction.do?otro=1"),
                from: disposiciones
            )
        )
        #expect(publication.idSource == .canonicalUrl)
        #expect(publication.blobId == nil)
        #expect(publication.externalKey.hasPrefix("https://"))
    }

    @Test("Un identificador que no son dígitos no vale como identificador")
    func aNonNumericBlobIdIsNotAnIdentifier() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(link: "https://boc.cantabria.es/x?idAnuBlob=abc"), from: disposiciones
            )
        )
        #expect(publication.idSource == .canonicalUrl)
    }

    @Test("Dos publicaciones con el mismo título y distinto enlace NO son la misma")
    func identityIsNeverTheTitle() throws {
        // Los títulos se repiten entre ayuntamientos: identificar por título fundiría anuncios
        // distintos o duplicaría el mismo.
        let one = try accepted(PublicationNormalizer.normalize(
            item(link: "https://boc.cantabria.es/x?idAnuBlob=1"), from: disposiciones))
        let other = try accepted(PublicationNormalizer.normalize(
            item(link: "https://boc.cantabria.es/x?idAnuBlob=2"), from: disposiciones))
        #expect(one.externalKey != other.externalKey)
    }

    // MARK: - Título y organismo

    @Test("El título se guarda entero, por largo que sea (FR-018)")
    func theTitleIsKeptWhole() async throws {
        let channel = try await BocRssParser.parseFeed(Fixture.anomalo.data)
        for item in channel.items {
            guard case .accepted(let publication) =
                PublicationNormalizer.normalize(item, from: seguridadSocial) else { continue }
            #expect(publication.title == item.title)
        }
    }

    @Test("Sin ruta de organismo, el prefijo del título sirve de dato auxiliar")
    func fallsBackToTheTitlePrefix() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(title: "CONSEJERÍA DE SALUD: Resolución.", categories: "1.Disposiciones|ORD"),
                from: disposiciones
            )
        )
        #expect(publication.issuer == "CONSEJERÍA DE SALUD")
    }

    @Test("Si no hay ni ruta ni prefijo, el organismo queda nulo y no se inventa")
    func theIssuerMayBeNil() throws {
        let publication = try accepted(
            PublicationNormalizer.normalize(
                item(title: "Anuncio sin organismo reconocible", categories: "1.Disposiciones|ORD"),
                from: disposiciones
            )
        )
        #expect(publication.issuer == nil)
    }
}
