//
//  DocumentRepositoryImplTests.swift
//
//  Lo que aquí se comprueba no es la coordinación —ésa vive en el almacén y se prueba allí— sino
//  **qué sale hacia fuera del dispositivo**.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Repositorio de documentos")
struct DocumentRepositoryImplTests {

    @Test("Un documento que ya estaba se marca como venido de la caché")
    func anAlreadyPresentDocumentIsReportedAsCached() async {
        let analytics = RecordingAnalyticsTracker()
        let repository = make(seeded: ["boc:1": officialDocument(externalKey: "boc:1")], analytics: analytics)

        _ = await repository.ensureLocalCopy(publication(externalKey: "boc:1"))

        #expect(analytics.events.count == 1)
        #expect(analytics.events.first?.parameters["cached"] == "true")
    }

    @Test("Un documento que hubo que traer se marca como no venido de la caché")
    func aFetchedDocumentIsReportedAsNotCached() async {
        let analytics = RecordingAnalyticsTracker()
        let repository = make(analytics: analytics)

        _ = await repository.ensureLocalCopy(publication(externalKey: "boc:1"))

        #expect(analytics.events.first?.parameters["cached"] == "false")
    }

    @Test("Un fallo no emite ningún evento: no se ha abierto nada")
    func aFailureEmitsNothing() async {
        let analytics = RecordingAnalyticsTracker()
        let repository = make(outcome: .rejected(.notAPdf), analytics: analytics)

        let resultado = await repository.ensureLocalCopy(publication(externalKey: "boc:1"))

        #expect(resultado == .failure(.unknown))
        #expect(analytics.events.isEmpty)
    }

    @Test("Nada de la publicación sale del dispositivo")
    func nothingAboutThePublicationLeavesTheDevice() async {
        // Es el principio VI, y es la clase de cosa que se rompe al añadir un parámetro «para
        // depurar». El motivo exacto de un rechazo va al registro, no a analítica.
        let analytics = RecordingAnalyticsTracker()
        let repository = make(analytics: analytics)

        _ = await repository.ensureLocalCopy(publication(externalKey: "boc:439765"))

        let texto = analytics.events
            .map { "\($0.name) " + $0.parameters.map { "\($0.key)=\($0.value)" }.joined(separator: " ") }
            .joined(separator: " ")
        for prohibido in ["boc:", "439765", "http", ".pdf", "AYUNTAMIENTO"] {
            #expect(!texto.contains(prohibido), "«\(prohibido)» no puede viajar a analítica")
        }
    }

    @Test("Un rechazo queda en el registro con su motivo, y SIN nada de la publicación")
    func aRejectionIsLoggedWithItsReasonAndNothingElse() async {
        // FR-024 y el principio VI a la vez: el registro es el único sitio donde se distingue qué
        // pasó, **y aun ahí no entra el título, ni la dirección, ni la clave**.
        let reporter = RecordingCrashReporter()
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(outcome: .rejected(.unexpectedType)),
            cache: FakeDocumentCache(),
            crashReporter: reporter
        )
        let repository = DocumentRepositoryImpl(store: store, analytics: NoOpAnalyticsTracker())

        _ = await repository.ensureLocalCopy(publication(externalKey: "boc:439765"))

        let mensajes = reporter.messages.joined(separator: " ")
        #expect(mensajes.contains("UNEXPECTED_TYPE"), "El motivo tiene que constar: \(mensajes)")
        for prohibido in ["boc:439765", "cantabria.es", "AYUNTAMIENTO"] {
            #expect(!mensajes.contains(prohibido), "«\(prohibido)» no puede constar en el registro")
        }
    }

    private func make(
        seeded: [String: OfficialDocument] = [:],
        outcome: DocumentDownloadResult = .downloaded(
            byteCount: 609, checksum: String(repeating: "a", count: 64)
        ),
        analytics: AnalyticsTracker = NoOpAnalyticsTracker()
    ) -> DocumentRepositoryImpl {
        DocumentRepositoryImpl(
            store: DocumentStore(
                downloader: CountingDocumentDownloader(outcome: outcome),
                cache: FakeDocumentCache(seeded: seeded),
                crashReporter: NoOpCrashReporter()
            ),
            analytics: analytics
        )
    }
}
