//
//  ContentItemRecord.swift
//  What the local source stores.
//

struct ContentItemRecord: Equatable, Sendable {
    let id: String
    let title: String
}

extension ContentItemRecord {
    func toDomain() -> ContentItem {
        ContentItem(id: id, title: title)
    }

    init(_ item: ContentItem) {
        self.init(id: item.id, title: item.title)
    }
}
