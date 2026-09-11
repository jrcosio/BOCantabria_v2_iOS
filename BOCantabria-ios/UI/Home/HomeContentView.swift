//
//  HomeContentView.swift
//  The stateless rendering of the listing.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las pruebas
//  pueden recorrer los estados sin arrancar el grafo, y las vistas previas también.
//

import SwiftUI

struct HomeContentView: View {
    let state: HomeUiState
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch state.content {
            case .skeleton:
                // Cinco como máximo, con la forma del contenido final: un indicador giratorio
                // grande no dice qué está por venir (FR-041).
                VStack(spacing: BocTheme.spacing.sm) {
                    ForEach(0..<5, id: \.self) { _ in PublicationCardSkeleton() }
                }
                .padding(.horizontal, BocTheme.spacing.screenMargin)
                .padding(.top, BocTheme.spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("home_skeleton")

            case .publications(let items):
                ScrollView {
                    LazyVStack(spacing: BocTheme.spacing.sm) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, publication in
                            PublicationCard(publication: publication)
                                .accessibilityIdentifier("publication_card_\(index)")
                        }
                    }
                    .padding(.horizontal, BocTheme.spacing.screenMargin)
                    .padding(.vertical, BocTheme.spacing.sm)
                }
                .accessibilityIdentifier("home_content")

            case .empty:
                EmptyMessage(message: emptyMessage)
                    .accessibilityIdentifier("home_empty")

            case .error:
                // El error de dominio no se pinta: la pantalla nunca dice códigos. Lo que se ve es
                // siempre el mismo texto, y el detalle vive en el registro.
                ErrorMessage(
                    message: Strings.Home.errorSync,
                    retryTitle: Strings.Action.retry,
                    onRetry: onRetry
                )
                .accessibilityIdentifier("home_error")
            }
        }
        .background(BocTheme.colors.background)
    }

    /// El estado vacío dice cosas distintas según lo que se esté mirando: «no hay nada hoy» y
    /// «esta sección no tiene nada» no son el mismo mensaje.
    private var emptyMessage: LocalizedStringResource {
        switch state.selection {
        case .todaysBulletin: Strings.Home.emptyToday
        case .section: Strings.Home.emptySection
        }
    }
}

#Preview("Marcadores") {
    HomeContentView(state: HomeUiState(), onRetry: {})
}

#Preview("Sin contenido") {
    HomeContentView(state: HomeUiState(content: .empty), onRetry: {})
}

#Preview("Error") {
    HomeContentView(state: HomeUiState(content: .error(.network)), onRetry: {})
}
