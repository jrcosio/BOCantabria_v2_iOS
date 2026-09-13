//
//  DocumentFlowIntegrationTests.swift
//  The whole chain, with a double only at the network boundary.
//
//  **Lo que aquí se prueba y no se prueba en ningún otro sitio** es que las piezas encajan: la
//  caché de verdad sobre un directorio de verdad, el almacén de verdad, el repositorio de verdad y
//  los casos de uso de verdad. El único doble está donde la constitución dice que esté: en la
//  frontera externa.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Integración: el documento, de extremo a extremo")
struct DocumentFlowIntegrationTests {

    @Test("Camino feliz: se descarga, se guarda con su huella y se sirve desde la caché")
    func happyPath() async throws {
        let grafo = make(outcome: .downloaded(
            byteCount: Int64(PdfFixture.valido.data.count), checksum: PdfFixture.valido.sha256
        ))
        defer { grafo.cleanUp() }

        let primero = await grafo.open(publication(externalKey: "boc:1"))

        guard case .success(let documento) = primero else {
            Issue.record("Debería haber traído el documento: \(primero)"); return
        }
        #expect(documento.checksum == PdfFixture.valido.sha256)
        #expect(FileManager.default.fileExists(atPath: documento.localPath))
        // El lateral existe **y es válido**: es el invariante de FR-023.
        let lateral = URL(fileURLWithPath: documento.localPath)
            .deletingPathExtension().appendingPathExtension("sha256")
        let escrita = try String(contentsOf: lateral, encoding: .utf8)
        #expect(OfficialDocument.isValidChecksum(escrita.trimmingCharacters(in: .whitespacesAndNewlines)))

        // Segunda vez: **no se vuelve a descargar**.
        _ = await grafo.open(publication(externalKey: "boc:1"))
        #expect(await grafo.downloader.downloadCount == 1)
    }

    @Test("Un rechazo no deja restos, y el estado queda en fallo con su motivo en el registro")
    func aRejectionLeavesNothingBehind() async {
        let grafo = make(outcome: .rejected(.notAPdf))
        defer { grafo.cleanUp() }

        let resultado = await grafo.open(publication(externalKey: "boc:1"))

        #expect(resultado == .failure(.unknown))
        // SC-005: **ni un fichero**, ni el documento ni su temporal ni su lateral.
        let restos = (try? FileManager.default.contentsOfDirectory(atPath: grafo.directory.path)) ?? []
        #expect(restos.isEmpty, "Han quedado restos: \(restos)")

        var estado: DocumentStatus?
        for await valor in grafo.repository.observeDocument(externalKey: "boc:1") { estado = valor; break }
        #expect(estado == .failed(.unknown))
        #expect(grafo.reporter.messages.contains { $0.contains("NOT_A_PDF") })
    }

    @Test("Una copia con el lateral vacío se sirve igual, y la aplicación no se cae")
    func aCopyWithAnEmptySidecarIsStillServed() async throws {
        // **Es STAB-001 recorrido entero**, desde el caso de uso hasta el disco. En la aplicación
        // de origen, este camino cerraba la aplicación.
        let grafo = make(outcome: .downloaded(
            byteCount: Int64(PdfFixture.valido.data.count), checksum: PdfFixture.valido.sha256
        ))
        defer { grafo.cleanUp() }

        guard case .success(let documento) = await grafo.open(publication(externalKey: "boc:1")) else {
            Issue.record("Debería haber traído el documento"); return
        }
        let lateral = URL(fileURLWithPath: documento.localPath)
            .deletingPathExtension().appendingPathExtension("sha256")
        try Data().write(to: lateral)

        let segundo = await grafo.open(publication(externalKey: "boc:1"))

        guard case .success(let recuperado) = segundo else {
            Issue.record("El documento tiene que servirse igual: \(segundo)"); return
        }
        #expect(recuperado.hasUnknownChecksum)
        #expect(await grafo.downloader.downloadCount == 1, "No hacía falta volver a descargarlo")
    }

    @Test("Retirar de la caché devuelve el estado a «no descargado», y se puede volver a traer")
    func evictingReturnsTheStateToAbsent() async {
        let grafo = make(outcome: .downloaded(
            byteCount: Int64(PdfFixture.valido.data.count), checksum: PdfFixture.valido.sha256
        ))
        defer { grafo.cleanUp() }
        _ = await grafo.open(publication(externalKey: "boc:1"))

        // Con presupuesto cero y sin nada en uso, se va.
        grafo.cache.evict(maxBytes: 0, keeping: [])

        #expect(grafo.cache.get("boc:1") == nil)
        // Y volver a pedirlo lo trae otra vez: la caché puede desaparecer sin que se pierda nada.
        _ = await grafo.open(publication(externalKey: "boc:1"))
        #expect(await grafo.downloader.downloadCount == 2)
        #expect(grafo.cache.get("boc:1") != nil)
    }

    @Test("Compartir recorre la cadena entera y entrega el documento con nombre legible")
    func sharingWalksTheWholeChain() async {
        let grafo = make(outcome: .downloaded(
            byteCount: Int64(PdfFixture.valido.data.count), checksum: PdfFixture.valido.sha256
        ))
        defer { grafo.cleanUp() }

        let destino = await ShareOfficialDocumentUseCase(
            documents: grafo.repository, connectivity: FakeConnectivityRepository(online: true)
        )(publication(externalKey: "boc:439765"))

        guard case .document(let compartido) = destino else {
            Issue.record("Debería ofrecer el documento: \(destino)"); return
        }
        #expect(compartido.fileName == "boc-439765.pdf")
        #expect(compartido.localPath != nil)
        // Y lo que se entrega **existe de verdad**.
        #expect(FileManager.default.fileExists(atPath: compartido.localPath ?? ""))
    }

    // MARK: - El grafo

    private struct Graph {
        let repository: DocumentRepository
        let cache: FileDocumentCache
        let downloader: CountingDocumentDownloader
        let reporter: RecordingCrashReporter
        let directory: URL

        func open(_ publication: Publication) async -> AppResult<OfficialDocument> {
            await OpenOfficialDocumentUseCase(repository: repository)(publication)
        }

        func cleanUp() { try? FileManager.default.removeItem(at: directory) }
    }

    private func make(outcome: DocumentDownloadResult) -> Graph {
        let directorio = FileManager.default.temporaryDirectory
            .appendingPathComponent("boc-flow-\(UUID().uuidString)", isDirectory: true)
        let reporter = RecordingCrashReporter()
        let cache = FileDocumentCache(
            directory: directorio, clock: ImmediateClock(), crashReporter: reporter
        )
        let downloader = CountingDocumentDownloader(outcome: outcome, body: PdfFixture.valido.data)
        return Graph(
            repository: DocumentRepositoryImpl(
                store: DocumentStore(downloader: downloader, cache: cache, crashReporter: reporter),
                analytics: NoOpAnalyticsTracker()
            ),
            cache: cache,
            downloader: downloader,
            reporter: reporter,
            directory: directorio
        )
    }
}
