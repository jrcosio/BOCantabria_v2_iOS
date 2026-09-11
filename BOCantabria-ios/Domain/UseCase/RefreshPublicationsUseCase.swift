//
//  RefreshPublicationsUseCase.swift
//  Brings the bulletin up to date.
//
//  Dos entradas y una sola política. El arranque llama con `force: false` y respeta la ventana de
//  caducidad; el gesto de deslizar llama con `force: true` y siempre sale a la red. No hay una
//  tercera política escondida.
//

import Foundation

struct RefreshPublicationsUseCase: Sendable {
    private let repository: PublicationRepository

    init(repository: PublicationRepository) {
        self.repository = repository
    }

    func callAsFunction(force: Bool) async -> AppResult<SyncSummary> {
        await repository.refresh(force: force)
    }
}
