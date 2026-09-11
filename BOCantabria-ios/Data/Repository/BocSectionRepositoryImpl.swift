//
//  BocSectionRepositoryImpl.swift
//  Serves the section tree. No storage involved: it is a catalogue.
//

import Foundation

struct BocSectionRepositoryImpl: BocSectionRepository {
    func sections() -> [BocSection] {
        BocSection.all
    }
}
