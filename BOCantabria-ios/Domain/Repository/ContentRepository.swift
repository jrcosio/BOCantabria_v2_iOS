//
//  ContentRepository.swift
//  The contract the domain declares and the data layer implements.
//

protocol ContentRepository: Sendable {
    /// **Nunca lanza**: los fallos viajan dentro del resultado.
    ///
    /// Una colección vacía es un éxito con colección vacía, no un fallo. Y es idempotente:
    /// llamarla dos veces no produce efectos secundarios observables.
    func contentItems() async -> AppResult<[ContentItem]>
}
