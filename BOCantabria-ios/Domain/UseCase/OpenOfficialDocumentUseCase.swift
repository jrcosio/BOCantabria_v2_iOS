//
//  OpenOfficialDocumentUseCase.swift
//  Makes sure the official document is on the device, fetching it when it is not.
//

import Foundation

struct OpenOfficialDocumentUseCase: Sendable {
    private let repository: DocumentRepository

    init(repository: DocumentRepository) {
        self.repository = repository
    }

    func callAsFunction(_ publication: Publication) async -> AppResult<OfficialDocument> {
        await repository.ensureLocalCopy(publication)
    }
}
