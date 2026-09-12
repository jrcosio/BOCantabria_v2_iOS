//
//  ObservePublicationUseCase.swift
//  Observes a single stored publication.
//

import Foundation

struct ObservePublicationUseCase: Sendable {
    private let repository: PublicationRepository

    init(repository: PublicationRepository) {
        self.repository = repository
    }

    func callAsFunction(_ externalKey: String) -> AsyncStream<AppResult<Publication?>> {
        repository.observePublication(externalKey: externalKey)
    }
}
