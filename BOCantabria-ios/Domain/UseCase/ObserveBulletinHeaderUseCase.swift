//
//  ObserveBulletinHeaderUseCase.swift
//  Observes the editorial header of a selection.
//

import Foundation

struct ObserveBulletinHeaderUseCase: Sendable {
    private let repository: PublicationRepository

    init(repository: PublicationRepository) {
        self.repository = repository
    }

    func callAsFunction(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>> {
        repository.observeHeader(selection)
    }
}
