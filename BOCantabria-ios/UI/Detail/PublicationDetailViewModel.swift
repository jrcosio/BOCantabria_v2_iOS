//
//  PublicationDetailViewModel.swift
//  The detail screen's model.
//
//  **Observa la fila, no recibe la publicación.** Es lo que hace que una sincronización posterior
//  corrija la pantalla sola (FR-003) y que «ya no está guardada» llegue como un dato y no como un
//  fallo (FR-004). La clave viaja por la ruta; el contenido, por la base (research.md D-512).
//
//  **Y el documento se pide al mostrarse la pestaña, no al abrir la pantalla** (FR-016): quien solo
//  quería ojear un anuncio no tiene por qué gastar sus datos en él.
//

import Foundation
import Synchronization

@MainActor
@Observable
final class PublicationDetailViewModel {
    static let screenName = "publication_detail"

    private(set) var state = PublicationDetailUiState()

    private let externalKey: String
    private let observePublication: ObservePublicationUseCase
    private let observeDocument: ObserveOfficialDocumentUseCase
    private let openDocument: OpenOfficialDocumentUseCase
    private let shareDocument: ShareOfficialDocumentUseCase
    private let analytics: AnalyticsTracker
    private let observations = DetailObservationBox()

    /// Para no volver a pedir el documento cada vez que la pestaña se vuelve a mostrar.
    private var documentRequested = false

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

    // MARK: - Eventos

    func onAppear() async {
        // **Sin `await` al pedir el flujo**, y no es un descuido: `Task { }` hereda el aislamiento
        // de quien lo crea, así que estas llamadas ocurren ya en el actor principal y no suspenden.
        // Ponerlo compila y deja un aviso —«no 'async' operations occur within 'await' expression»—
        // que la cuarta puerta de calidad no perdona.
        observations.publication = Task { [weak self] in
            guard let self else { return }
            for await result in self.observePublication(self.externalKey) {
                await self.apply(result)
            }
        }
        observations.document = Task { [weak self] in
            guard let self else { return }
            for await status in self.observeDocument(self.externalKey) {
                self.apply(status)
            }
        }
    }

    func onSelectTab(_ tab: DetailTab) {
        state.selectedTab = tab
    }

    /// **Aquí, y no en `onAppear`** (FR-016).
    func onDocumentTabShown() async {
        guard !documentRequested, let publication = state.publication else { return }
        documentRequested = true
        _ = await openDocument(publication)
    }

    func onRetryDocument() async {
        guard let publication = state.publication else { return }
        documentRequested = true
        _ = await openDocument(publication)
    }

    func onShare() async {
        guard let publication = state.publication else { return }
        state.share = .preparing
        let destino = await shareDocument(publication)
        analytics.track(.documentShared(target: destino.analyticsKind))
        state.share = .ready(destino)
    }

    /// La hoja se ha presentado: el evento se consume.
    func onShareConsumed() {
        state.share = .idle
    }

    // MARK: - Estado

    private func apply(_ result: AppResult<Publication?>) async {
        switch result {
        case .success(let publicacion):
            state.publication = publicacion
            state.section = publicacion.flatMap { BocSection.named($0.mostSpecificSectionCode) }
            // **`nil` es un dato, no un fallo** (FR-004).
            state.isMissing = publicacion == nil
            state.loadFailed = false
            // La publicación puede llegar después de que la pestaña se haya mostrado.
            if publicacion != nil, state.selectedTab == .document, !documentRequested {
                await onDocumentTabShown()
            }
        case .failure:
            // Un fallo de lectura **no es** «se retiró», y **tampoco es un fallo del documento**:
            // escribirlo en `state.document` lo convertía en una carrera con la observación del
            // documento, que lo pisaba un instante después. Tiene su propio campo.
            state.isMissing = false
            state.loadFailed = true
        }
    }

    private func apply(_ status: DocumentStatus) {
        state.document = status
    }
}

private extension ShareTarget {
    var analyticsKind: AnalyticsEvent.ShareTargetKind {
        switch self {
        case .document: .document
        case .link: .link
        }
    }
}

/// La misma caja `nonisolated` que usan Inicio y el visor.
private final class DetailObservationBox: Sendable {
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
