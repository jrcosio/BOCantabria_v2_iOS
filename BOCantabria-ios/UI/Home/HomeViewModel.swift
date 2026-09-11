//
//  HomeViewModel.swift
//  The screen model of the initial screen.
//

import Foundation

@MainActor
@Observable
final class HomeViewModel {
    /// El identificador de pantalla que viaja a analítica. Un enumerado sería más seguro, pero
    /// hoy hay una sola pantalla y adivinar su forma futura es peor que esperar.
    static let screenName = "home"

    private(set) var state: HomeUiState = .loading

    private let getContentItems: GetContentItemsUseCase
    private let analytics: AnalyticsTracker
    private var hasLoaded = false
    private var isLoading = false

    init(getContentItems: GetContentItemsUseCase, analytics: AnalyticsTracker) {
        self.getContentItems = getContentItems
        self.analytics = analytics
        // Exactamente una vez por instancia, no una por aparición de la vista: la vista aparece
        // otra vez al volver de segundo plano, y eso no es una visita nueva.
        analytics.trackScreenView(Self.screenName)
    }

    /// La carga inicial. **Se dispara una sola vez**: volver de segundo plano no recarga, que es
    /// lo que FR-005 pide.
    func onAppear() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Reintentar. **No hace nada si ya hay una carga en curso**, de modo que pulsar repetidamente
    /// no lanza cargas simultáneas.
    func onRetry() async {
        guard !isLoading else { return }
        await load()
    }

    private func load() async {
        isLoading = true
        state = .loading
        defer { isLoading = false }

        let result = await getContentItems()

        // Si la tarea se canceló mientras esperábamos, quien la canceló ya no está mirando esta
        // pantalla. Publicar aquí un estado sería pintar sobre algo que ya no existe, y en el
        // caso del fallo además mentiría: diría «no hay conexión» de una cancelación.
        guard !Task.isCancelled else { return }

        hasLoaded = true
        switch result {
        case .success(let items):
            state = items.isEmpty ? .empty : .content(items)
        case .failure(let error):
            state = .error(error)
        }
    }
}
