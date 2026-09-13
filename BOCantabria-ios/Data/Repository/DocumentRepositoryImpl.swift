//
//  DocumentRepositoryImpl.swift
//  The domain's view of the local copies.
//
//  Es una capa fina sobre `DocumentStore`, y lo es a propósito: **toda la coordinación vive en el
//  actor**, que es donde puede haber estado. Aquí solo queda traducir y contar.
//
//  **Y aquí es donde se emite `document_opened`**, no en el almacén: el almacén no conoce la
//  telemetría, y así se puede probar sin dobles de analítica.
//

import Foundation

struct DocumentRepositoryImpl: DocumentRepository {
    private let store: DocumentStore
    private let analytics: AnalyticsTracker

    init(store: DocumentStore, analytics: AnalyticsTracker) {
        self.store = store
        self.analytics = analytics
    }

    func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus> {
        store.observeDocument(externalKey: externalKey)
    }

    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument> {
        // Si ya estaba antes de pedirlo, venía de la caché. Es lo único que el evento manda: una
        // bandera. Ni el título, ni la dirección, ni la clave (principio VI).
        let venaDeCache = await store.isCached(publication.externalKey)
        let resultado = await store.ensureLocalCopy(publication)
        if case .success = resultado {
            analytics.track(.documentOpened(cached: venaDeCache))
        }
        return resultado
    }

    func releaseUnused() async {
        await store.releaseUnused()
    }
}
