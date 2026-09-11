//
//  ContentLocalDataSource.swift
//  The local source of content.
//

protocol ContentLocalDataSource: Sendable {
    func readContentItems() async -> [ContentItemRecord]
    func writeContentItems(_ items: [ContentItemRecord]) async
}

/// Caché en memoria mientras no hay persistencia (research.md D-104). Es un `actor` porque su
/// estado se toca desde fuera del actor principal.
actor InMemoryContentLocalDataSource: ContentLocalDataSource {
    private var items: [ContentItemRecord] = []

    func readContentItems() async -> [ContentItemRecord] { items }

    func writeContentItems(_ items: [ContentItemRecord]) async { self.items = items }
}
