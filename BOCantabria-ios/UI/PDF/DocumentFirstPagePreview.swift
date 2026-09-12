//
//  DocumentFirstPagePreview.swift
//  The first page, as the detail screen embeds it.
//
//  **Vive aquí y no en `UI/Detail/` a propósito.** El detalle embebe *esta vista*, no una imagen,
//  y así ningún tipo de PDFKit —ni siquiera un `UIImage` que venga de él— sale de esta carpeta. Es
//  lo que hace que la regla 14 se cumpla sola en vez de a base de disciplina (research.md D-513).
//

import SwiftUI

struct DocumentFirstPagePreview: View {
    let status: DocumentStatus
    var onRetry: () -> Void = {}

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.sm) {
            Text(Strings.Detail.previewTitle)
                .bocTextStyle(BocTheme.typography.labelMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_preview")
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .absent, .downloading:
            placeholder(Strings.Detail.previewLoading, id: "detail_preview_loading")

        case .failed(let error):
            // **El error del documento no tiene estilo propio** (§34).
            ErrorMessage(
                message: error == .network ? Strings.Detail.errorNetwork : Strings.Detail.errorInvalid,
                retryTitle: Strings.Action.retry,
                retryIdentifier: "detail_retry",
                onRetry: onRetry
            )
            .frame(minHeight: 160)
            .background(BocTheme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.medium))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("detail_preview_error")

        case .available(let document):
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: BocTheme.shape.medium)
                            .stroke(BocTheme.colors.divider, lineWidth: 1)
                    )
                    .accessibilityLabel(Text(Strings.Detail.previewTitle))
            } else if failed {
                // **La previsualización falla y el documento sirve**: se dice, y no se convierte
                // en un error de pantalla que impida abrirlo.
                Text(Strings.Detail.previewUnavailable)
                    .bocTextStyle(BocTheme.typography.bodyMedium)
                    .foregroundStyle(BocTheme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("detail_preview_unavailable")
            } else {
                placeholder(Strings.Detail.previewLoading, id: "detail_preview_loading")
                    // `.task(id:)` y no `.task`: si el documento cambia, se vuelve a dibujar; si
                    // no, no se relanza en cada redibujado.
                    .task(id: document.localPath) { await render(document) }
            }
        }
    }

    private func placeholder(_ text: LocalizedStringResource, id: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: BocTheme.shape.medium)
                .fill(BocTheme.colors.surfaceStrong)
            Text(text)
                .bocTextStyle(BocTheme.typography.bodyMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)
        }
        .frame(height: 220)
        // Elemento propio y no contenedor: sus hijos no dicen nada al lector de pantalla, y un
        // contenedor sin hijos accesibles no entra en el árbol.
        .accessibilityElement()
        .accessibilityLabel(Text(text))
        .accessibilityIdentifier(id)
    }

    private func render(_ document: OfficialDocument) async {
        let url = URL(fileURLWithPath: document.localPath)
        let dibujada = await PdfPageRenderer.firstPageImage(
            of: url, width: 600, displayScale: displayScale
        )
        if let dibujada { image = dibujada } else { failed = true }
    }
}
