//
//  ObservePublicationsUseCase.swift
//  Observes what is stored for a selection.
//

import Foundation

struct ObservePublicationsUseCase: Sendable {
    private let repository: PublicationRepository

    init(repository: PublicationRepository) {
        self.repository = repository
    }

    func callAsFunction(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>> {
        repository.observePublications(selection)
    }
}
