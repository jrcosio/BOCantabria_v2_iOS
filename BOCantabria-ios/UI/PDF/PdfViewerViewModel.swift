//
//  PdfViewerViewModel.swift
//  The viewer screen's model.
//
//  **Observa el estado del documento, no lo pide y espera.** Es lo que hace que abrirlo con la
//  copia ya en caché sea inmediato y que un fallo llegue con su reintento — y lo que hace que el
//  cuelgue de D-510 sea imposible: lo primero que recibe al suscribirse es el estado vigente.
//

import Foundation
import Synchronization

@MainActor
@Observable
final class PdfViewerViewModel {
    static let screenName = "pdf_viewer"

    private(set) var state: PdfViewerUiState = .loading
    /// El visor comparte igual que el detalle y que la tarjeta (FR-038), y por el mismo camino: la
    /// regla de degradación vive en el caso de uso y aquí solo se pide y se presenta.
    private(set) var share: ShareState = .idle

    private let externalKey: String
    private let observePublication: ObservePublicationUseCase
    private let observeDocument: ObserveOfficialDocumentUseCase
    private let openDocument: OpenOfficialDocumentUseCase
    private let shareDocument: ShareOfficialDocumentUseCase
    private let analytics: AnalyticsTracker
    private let observations = ViewerObservationBox()

    private var publication: Publication?

    init(
        externalKey: String,
        observePublication: ObservePublicationUseCase,
        observeDocument: ObserveOfficialDocumentUseCase,
        openDocument: OpenOfficialDocumentUseCase,
        shareDocument: ShareOfficialDocumentUseCase,
        analytics: AnalyticsTracker
    ) {
        self.externalKey = externalKey
        self.observePublication = observePublication
        self.observeDocument = observeDocument
        self.openDocument = openDocument
        self.shareDocument = shareDocument
        self.analytics = analytics
        analytics.trackScreenView(Self.screenName)
    }

    deinit {
        observations.cancelAll()
    }

    func onAppear() async {
        observations.publication = Task { [weak self] in
            guard let self else { return }
            for await result in await self.observePublication(self.externalKey) {
                guard case .success(let publicacion) = result else { continue }
                await self.apply(publicacion)
            }
        }
        observations.document = Task { [weak self] in
            guard let self else { return }
            for await status in await self.observeDocument(self.externalKey) {
                await self.apply(status)
            }
        }
        await ensure()
    }

    func onShare() async {
        guard let publication else { return }
        share = .preparing
        let destino = await shareDocument(publication)
        analytics.track(
            .documentShared(target: { if case .document = destino { .document } else { .link } }())
        )
        share = .ready(destino)
    }

    func onShareConsumed() {
        share = .idle
    }

    func onRetry() async {
        state = .loading
        await ensure()
    }

    private func ensure() async {
        guard let publication else { return }
        _ = await openDocument(publication)
    }

    private func apply(_ publicacion: Publication?) async {
        publication = publicacion
        if case .ready(let url, _, let paginas) = state, let publicacion {
            state = .ready(fileUrl: url, title: publicacion.titleWithoutIssuer, pageCount: paginas)
        }
        // La primera vez que llega la publicación puede ser después de `onAppear`, así que aquí es
        // donde se dispara la obtención si todavía no se había podido.
        if publicacion != nil, case .loading = state { await ensure() }
    }

    private func apply(_ status: DocumentStatus) async {
        switch status {
        case .absent, .downloading:
            state = .loading
        case .failed(let error):
            state = .error(.document(error))
        case .available(let document):
            await open(document)
        }
    }

    private func open(_ document: OfficialDocument) async {
        let url = URL(fileURLWithPath: document.localPath)
        // El sondeo va **fuera del actor principal**: abrir un documento grande aquí se comería un
        // fotograma, y el compilador no diría nada.
        switch await PdfDocumentProbe.inspect(url) {
        case .readable(let paginas):
            state = .ready(
                fileUrl: url,
                title: publication?.titleWithoutIssuer ?? "",
                pageCount: paginas
            )
        case .locked:
            state = .error(.locked)
        case .unreadable:
            state = .error(.unreadable)
        }
    }
}

/// La misma caja `nonisolated` que usa Inicio, y por lo mismo: el `deinit` de una clase
/// `@MainActor` no puede tocar sus propiedades aisladas.
private final class ViewerObservationBox: Sendable {
    private let storage = Mutex<(publication: Task<Void, Never>?, document: Task<Void, Never>?)>((nil, nil))

    var publication: Task<Void, Never>? {
        get { storage.withLock { $0.publication } }
        set { storage.withLock { $0.publication = newValue } }
    }

    var document: Task<Void, Never>? {
        get { storage.withLock { $0.document } }
        set { storage.withLock { $0.document = newValue } }
    }

    func cancelAll() {
        storage.withLock { tasks in
            tasks.publication?.cancel()
            tasks.document?.cancel()
            tasks = (nil, nil)
        }
    }
}
