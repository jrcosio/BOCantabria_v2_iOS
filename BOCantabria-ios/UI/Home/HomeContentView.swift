//
//  HomeContentView.swift
//  The stateless rendering of the four states.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las pruebas
//  pueden recorrer los cuatro estados sin arrancar el grafo, y las vistas previas también.
//

import SwiftUI

struct HomeContentView: View {
    let state: HomeUiState
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .loading:
            LoadingIndicator(message: Strings.Home.loading)
                .accessibilityIdentifier("home_loading")

        case .content(let items):
            List(items) { item in
                Text(item.title)
                    .bocTextStyle(BocTheme.typography.titleMedium)
                    .foregroundStyle(BocTheme.colors.textPrimary)
                    .listRowBackground(BocTheme.colors.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BocTheme.colors.background)
            .accessibilityIdentifier("home_content")

        case .empty:
            EmptyMessage(message: Strings.Home.empty)
                .accessibilityIdentifier("home_empty")

        case .error:
            // El error de dominio no se pinta: la pantalla nunca dice códigos. Lo que se ve es
            // siempre el mismo texto, y el detalle vive en el registro.
            ErrorMessage(
                message: Strings.Home.error,
                retryTitle: Strings.Action.retry,
                onRetry: onRetry
            )
            .accessibilityIdentifier("home_error")
        }
    }
}

#Preview("Contenido") {
    HomeContentView(state: .content([ContentItem(id: "1", title: "Disposiciones generales")]), onRetry: {})
}

#Preview("Sin contenido") {
    HomeContentView(state: .empty, onRetry: {})
}

#Preview("Error") {
    HomeContentView(state: .error(.network), onRetry: {})
}
