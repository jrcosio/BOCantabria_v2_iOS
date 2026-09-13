//
//  ShareOfficialDocumentUseCase.swift
//  Decides what sharing offers: the document, or the link with its reason.
//
//  **Es el ÚNICO sitio donde vive la regla de degradación** (FR-041). Las tres pantallas que
//  comparten —el detalle, el visor y la tarjeta— preguntan y obedecen. Repartir la decisión entre
//  ellas garantizaría que las tres acabaran decidiendo cosas ligeramente distintas.
//

import Foundation

struct ShareOfficialDocumentUseCase: Sendable {
    private let documents: DocumentRepository
    private let connectivity: ConnectivityRepository

    init(documents: DocumentRepository, connectivity: ConnectivityRepository) {
        self.documents = documents
        self.connectivity = connectivity
    }

    /// - Returns: el documento cuando existe o puede obtenerse; el enlace **con su motivo** cuando
    ///   no hay conexión y no hay copia.
    ///
    /// **Un fallo que no sea la falta de conexión no devuelve enlace** (FR-040): devuelve el
    /// documento pendiente, y quien lo exporte se encontrará el error de verdad. Disfrazar un
    /// disco lleno de «sin conexión» sería mentirle a la persona sobre qué ha pasado.
    func callAsFunction(_ publication: Publication) async -> ShareTarget {
        let pendiente = SharedDocument(
            externalKey: publication.externalKey,
            fileName: SharedDocument.fileName(forExternalKey: publication.externalKey),
            localPath: nil
        )

        // La copia que ya está: se ofrece de inmediato, sin preguntar por la red.
        if case .success(let document) = await documents.ensureLocalCopy(publication) {
            return .document(
                SharedDocument(
                    externalKey: document.externalKey,
                    fileName: SharedDocument.fileName(forExternalKey: document.externalKey),
                    localPath: document.localPath
                )
            )
        }

        // No se pudo. **Solo** la falta de conexión degrada al enlace.
        if await connectivity.isOnline() {
            return .document(pendiente)
        }
        return .link(url: publication.documentUrl, reason: .noConnection)
    }
}
