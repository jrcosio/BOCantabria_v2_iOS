//
//  PdfViewerContentView.swift
//  The viewer's rendering, which does not know the view model.
//

import SwiftUI

struct PdfViewerContentView: View {
    let state: PdfViewerUiState
    @Binding var pageIndex: Int
    var onBack: () -> Void = {}
    var onRetry: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(BocTheme.colors.readerSurface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pdf_viewer")
    }

    /// **Tres controles, no cinco** (§24.1, enmendado): atrás, título abreviado y compartir. Buscar
    /// dentro del documento y el menú de más opciones quedan fuera del alcance, y un menú sin nada
    /// que ofrecer sería un botón que no hace nada.
    private var topBar: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            iconButton(.icArrowBack, label: Strings.Detail.back, id: "pdf_viewer_back", action: onBack)

            Text(title)
                .bocTextStyle(BocTheme.typography.titleMedium)
                .foregroundStyle(BocTheme.colors.onPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pdf_viewer_title")

            iconButton(.icShare, label: Strings.Detail.share, id: "pdf_viewer_share", action: onShare)
        }
        .padding(.horizontal, BocTheme.spacing.xs)
        .background(BocTheme.colors.primary)
        .accessibilityElement(children: .contain)
    }

    /// El título abreviado es el del anuncio **sin el organismo**, que ya va implícito en el propio
    /// documento y dejaría sin sitio a la parte que dice de qué trata (§24.1).
    private var title: String {
        if case .ready(_, let titulo, _) = state { return titulo }
        return ""
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: BocTheme.spacing.sm) {
                ProgressView()
                Text(Strings.PdfViewer.loading)
                    .bocTextStyle(BocTheme.typography.bodyMedium)
                    .foregroundStyle(BocTheme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement()
            .accessibilityLabel(Text(Strings.PdfViewer.loading))
            .accessibilityIdentifier("pdf_viewer_loading")

        case .ready(let url, _, let pageCount):
            ZStack(alignment: .bottom) {
                PdfDocumentView(fileUrl: url, pageIndex: $pageIndex)

                // El indicador flotante del §24.2. Con una sola página no aporta nada.
                if pageCount > 1 {
                    Text(verbatim: "\(pageIndex + 1) / \(pageCount)")
                        .bocTextStyle(BocTheme.typography.labelMedium)
                        .foregroundStyle(BocTheme.colors.onPrimary)
                        .padding(.horizontal, BocTheme.spacing.sm)
                        .padding(.vertical, BocTheme.spacing.xxs)
                        .background(BocTheme.colors.primary.opacity(0.85))
                        .clipShape(BocTheme.shape.chip)
                        .padding(.bottom, BocTheme.spacing.md)
                        .accessibilityIdentifier("pdf_viewer_page_indicator")
                }
            }

        case .error(let error):
            // **El error del visor no tiene estilo propio** (§34): es el mismo componente que el
            // resto de la aplicación. Lo que cambia es que un documento protegido no ofrece
            // reintentar, porque reintentarlo no puede salir bien.
            VStack(spacing: BocTheme.spacing.md) {
                if error.isRetryable {
                    ErrorMessage(
                        message: message(for: error),
                        retryTitle: Strings.Action.retry,
                        retryIdentifier: "pdf_viewer_retry",
                        onRetry: onRetry
                    )
                } else {
                    Text(message(for: error))
                        .bocTextStyle(BocTheme.typography.bodyLarge)
                        .foregroundStyle(BocTheme.colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Button(action: onBack) {
                        Text(Strings.Detail.missingAction)
                            .bocTextStyle(BocTheme.typography.labelLarge)
                            .padding(.horizontal, BocTheme.spacing.lg)
                            .padding(.vertical, BocTheme.spacing.sm)
                    }
                    .buttonStyle(BocPrimaryButtonStyle())
                    .accessibilityIdentifier("pdf_viewer_exit")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(BocTheme.spacing.screenMargin)
            .background(BocTheme.colors.background)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pdf_viewer_error")
        }
    }

    private func message(for error: PdfViewerError) -> LocalizedStringResource {
        switch error {
        case .locked: Strings.PdfViewer.locked
        case .unreadable: Strings.PdfViewer.error
        case .document(.network): Strings.Detail.errorNetwork
        case .document: Strings.Detail.errorInvalid
        }
    }

    private func iconButton(
        _ icon: ImageResource,
        label: LocalizedStringResource,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BocTheme.colors.onPrimary)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }
}

#Preview("Cargando") {
    PdfViewerContentView(state: .loading, pageIndex: .constant(0))
}

#Preview("Protegido") {
    PdfViewerContentView(state: .error(.locked), pageIndex: .constant(0))
}

#Preview("Ilegible") {
    PdfViewerContentView(state: .error(.unreadable), pageIndex: .constant(0))
}

#Preview("Sin conexión") {
    PdfViewerContentView(state: .error(.document(.network)), pageIndex: .constant(0))
}
