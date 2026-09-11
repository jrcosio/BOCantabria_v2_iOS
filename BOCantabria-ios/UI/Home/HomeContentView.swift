//
//  HomeContentView.swift
//  The stateless rendering of the initial screen.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las pruebas
//  pueden recorrer los estados sin arrancar el grafo, y las vistas previas también.
//
//  De arriba abajo: barra superior clara, cabecera editorial azul, filtros rápidos —una fila o
//  dos— y listado (FR-030).
//

import SwiftUI

struct HomeContentView: View {
    let state: HomeUiState
    var onRefresh: () async -> Void = {}
    var onRetry: () -> Void = {}
    var onSelect: (SectionChip) -> Void = { _ in }
    var onOpenSections: () -> Void = {}
    var onSearch: () -> Void = {}
    var onInfo: () -> Void = {}
    var onShare: (Publication) -> Void = { _ in }
    var onSave: (Publication) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            HomeTopBar(onOpenSections: onOpenSections, onSearch: onSearch, onInfo: onInfo)

            ScrollView {
                VStack(spacing: 0) {
                    if let header = state.header {
                        BulletinHeaderView(header: header)
                    }

                    SectionChipRow(
                        chips: state.sectionChips,
                        selectedCode: state.selection.topLevelCode ?? SectionChip.todayCode,
                        style: .primary,
                        onSelect: onSelect
                    )
                    .accessibilityIdentifier("home_section_chips")

                    // La segunda fila **no existe** cuando no procede: ni vacía, ni oculta
                    // (FR-052).
                    if state.hasSubsectionRow {
                        SectionChipRow(
                            chips: state.subsectionChips,
                            selectedCode: state.selection.subsectionCode
                                ?? state.selection.topLevelCode,
                            style: .secondary,
                            onSelect: onSelect
                        )
                        .accessibilityIdentifier("home_subsection_chips")
                    }

                    if state.isOffline {
                        OfflineBanner()
                    }

                    listing
                }
            }
            .refreshable { await onRefresh() }
        }
        .background(BocTheme.colors.background)
    }

    @ViewBuilder
    private var listing: some View {
        switch state.content {
        case .skeleton:
            // Cinco como máximo, con la forma del contenido final: un indicador giratorio grande
            // no dice qué está por venir (FR-041).
            VStack(spacing: BocTheme.spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in PublicationCardSkeleton() }
            }
            .padding(.horizontal, BocTheme.spacing.screenMargin)
            .padding(.vertical, BocTheme.spacing.sm)
            // Elemento propio, no contenedor: los marcadores están ocultos al lector de pantalla
            // —no dicen nada— así que un contenedor sin hijos accesibles no entra en el árbol.
            .accessibilityElement()
            .accessibilityLabel(Text(Strings.Home.loading))
            .accessibilityIdentifier("home_skeleton")

        case .publications(let items):
            LazyVStack(spacing: BocTheme.spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, publication in
                    PublicationCard(
                        publication: publication,
                        onShare: { onShare(publication) },
                        onSave: { onSave(publication) }
                    )
                    .accessibilityIdentifier("publication_card_\(index)")
                }
            }
            .padding(.horizontal, BocTheme.spacing.screenMargin)
            .padding(.vertical, BocTheme.spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home_content")

        case .empty:
            EmptyMessage(message: emptyMessage)
                .padding(.top, BocTheme.spacing.xxl)
                .accessibilityIdentifier("home_empty")

        case .error:
            // El error de dominio no se pinta: la pantalla nunca dice códigos. Lo que se ve es
            // siempre el mismo texto, y el detalle vive en el registro.
            ErrorMessage(
                message: Strings.Home.errorSync,
                retryTitle: Strings.Action.retry,
                retryIdentifier: "home_retry",
                onRetry: onRetry
            )
            .padding(.top, BocTheme.spacing.xxl)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home_error")
        }
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
    HomeContentView(state: HomeUiState(sectionChips: previewChips))
}

#Preview("Sin contenido") {
    HomeContentView(state: HomeUiState(sectionChips: previewChips, content: .empty))
}

#Preview("Error") {
    HomeContentView(state: HomeUiState(sectionChips: previewChips, content: .error(.network)))
}

private let previewChips: [SectionChip] =
    [SectionChip(code: SectionChip.todayCode, title: "Boletín de hoy")]
    + BocSection.topLevel.map { SectionChip(code: $0.code, title: $0.shortName) }
