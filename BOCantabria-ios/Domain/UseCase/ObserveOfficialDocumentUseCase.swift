//
//  ObserveOfficialDocumentUseCase.swift
//  Observes the state of a publication's local copy.
//

import Foundation

struct ObserveOfficialDocumentUseCase: Sendable {
    private let repository: DocumentRepository

    init(repository: DocumentRepository) {
        self.repository = repository
    }

    func callAsFunction(_ externalKey: String) -> AsyncStream<DocumentStatus> {
        repository.observeDocument(externalKey: externalKey)
    }
}
