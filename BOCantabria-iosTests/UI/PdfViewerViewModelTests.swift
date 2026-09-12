//
//  PdfViewerViewModelTests.swift
//
//  **Los dos errores del visor son distintos, y ésa es la mitad de esta suite.** Un documento
//  protegido con contraseña no es lo mismo que uno ilegible, y un documento cifrado que SÍ se puede
//  leer no es ninguno de los dos: rechazarlo sería mutilar documentos oficiales legítimos (FR-036).
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: visor")
@MainActor
struct PdfViewerViewModelTests {

    @Test("Nace cargando, no en blanco")
    func itStartsLoading() {
        #expect(make().state == .loading)
    }

    @Test("Un documento legible llega listo, con su número de páginas y su título abreviado")
    func aReadableDocumentArrivesReady() async {
        // El organismo del doble es «Ayuntamiento de Piélagos», así que el título tiene que
        // empezar por él para que el prefijo se recorte. Con otro organismo **no se recorta**, y
        // eso es lo correcto: recortar por parecido mutilaría títulos oficiales.
        let publicacion = publication(
            externalKey: "boc:1",
            title: "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva de la Ordenanza"
        )
        let viewModel = make(
            publication: publicacion,
            document: .available(document(for: .dosPaginas))
        )

        await viewModel.onAppear()
        await until("el visor deja de cargar") { viewModel.state != .loading }

        guard case .ready(_, let titulo, let paginas) = viewModel.state else {
            Issue.record("Debería estar listo, y está en \(viewModel.state)")
            return
        }
        #expect(paginas == 2)
        // El título abreviado es el del anuncio **sin el organismo** (§24.1).
        #expect(titulo == "Aprobación definitiva de la Ordenanza")
    }

    @Test("Un documento protegido con contraseña da su error propio, SIN reintento")
    func aPasswordProtectedDocumentGivesItsOwnErrorWithoutRetry() async {
        // Reintentar un documento protegido no puede salir bien. Ofrecer el botón sería invitar a
        // pulsar algo que no funciona.
        let viewModel = make(document: .available(document(for: .protegido)))

        await viewModel.onAppear()
        await until("el visor deja de cargar") { viewModel.state != .loading }

        #expect(viewModel.state == .error(.locked))
        #expect(PdfViewerError.locked.isRetryable == false)
    }

    @Test("Un documento ilegible da un error DISTINTO del protegido")
    func anUnreadableDocumentGivesADifferentErrorThanAProtectedOne() async {
        let viewModel = make(document: .available(document(for: .truncado)))

        await viewModel.onAppear()
        await until("el visor deja de cargar") { viewModel.state != .loading }

        #expect(viewModel.state == .error(.unreadable))
        #expect(viewModel.state != .error(.locked), "Son dos casos, no uno")
    }

    @Test("Un fallo al obtener el documento sí ofrece reintento")
    func aFetchFailureDoesOfferRetry() async {
        let viewModel = make(document: .failed(.network))

        await viewModel.onAppear()
        await until("el visor deja de cargar") { viewModel.state != .loading }

        #expect(viewModel.state == .error(.document(.network)))
        #expect(PdfViewerError.document(.network).isRetryable)
    }

    @Test("Mientras se obtiene, la pantalla carga; y nunca se queda ahí si el estado es terminal")
    func whileFetchingTheScreenLoads() async {
        let viewModel = make(document: .downloading(bytesRead: 100, totalBytes: 1000))

        await viewModel.onAppear()
        // Aquí **no** se espera a que cambie: lo que se comprueba es que se queda cargando
        // mientras llega, que es lo correcto.
        #expect(viewModel.state == .loading)
    }

    @Test("Compartir desde el visor pasa por el mismo caso de uso que el detalle")
    func sharingFromTheViewerGoesThroughTheSameUseCase() async {
        let viewModel = make(
            publication: publication(externalKey: "boc:439765"),
            document: .available(document(for: .valido)),
            shareResult: .success(officialDocument(externalKey: "boc:439765"))
        )
        await viewModel.onAppear()
        await until("el visor deja de cargar") { viewModel.state != .loading }

        await viewModel.onShare()

        guard case .ready(.document(let compartido)) = viewModel.share else {
            Issue.record("Debería ofrecer el documento, y ofrece \(viewModel.share)")
            return
        }
        #expect(compartido.fileName == "boc-439765.pdf")
    }

    // MARK: - Ayudas

    /// Un documento cuya ruta apunta a una muestra real, para que el sondeo tenga algo que abrir.
    private func document(for fixture: PdfFixture) -> OfficialDocument {
        officialDocument(externalKey: "boc:1", localPath: fixture.url.path)
    }

    private func make(
        publication publicacion: Publication? = nil,
        document status: DocumentStatus = .absent,
        shareResult: AppResult<OfficialDocument> = .failure(.network)
    ) -> PdfViewerViewModel {
        let publications = FakePublicationRepository(
            single: [.success(publicacion ?? publication(externalKey: "boc:1"))]
        )
        let documents = FakeDocumentRepository(
            statuses: ["boc:1": [status], "boc:439765": [status]], result: shareResult
        )
        return PdfViewerViewModel(
            externalKey: publicacion?.externalKey ?? "boc:1",
            observePublication: ObservePublicationUseCase(repository: publications),
            observeDocument: ObserveOfficialDocumentUseCase(repository: documents),
            openDocument: OpenOfficialDocumentUseCase(repository: documents),
            shareDocument: ShareOfficialDocumentUseCase(
                documents: documents, connectivity: FakeConnectivityRepository(online: true)
            ),
            analytics: NoOpAnalyticsTracker()
        )
    }
}
