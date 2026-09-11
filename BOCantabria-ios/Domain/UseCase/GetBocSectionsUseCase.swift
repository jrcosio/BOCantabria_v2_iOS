//
//  GetBocSectionsUseCase.swift
//  The section tree the drawer and the chip rows draw.
//

import Foundation

struct GetBocSectionsUseCase: Sendable {
    private let repository: BocSectionRepository

    init(repository: BocSectionRepository) {
        self.repository = repository
    }

    func callAsFunction() -> [BocSection] {
        repository.sections()
    }
}
