//
//  GetContentItemsUseCase.swift
//  Obtains the content items.
//
//  **No añade lógica, y eso es correcto.** Existe para que la presentación no conozca los
//  repositorios y para dar un lugar evidente donde ponerla el día que aparezca.
//

struct GetContentItemsUseCase: Sendable {
    private let repository: ContentRepository

    init(repository: ContentRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> AppResult<[ContentItem]> {
        await repository.contentItems()
    }
}
