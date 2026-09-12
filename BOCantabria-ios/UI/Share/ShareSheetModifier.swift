//
//  ShareSheetModifier.swift
//  Presenting what the use case decided, in one place.
//
//  **La pantalla no decide entre fichero y enlace: pregunta y obedece** (FR-041). Aquí solo se
//  presenta lo que el caso de uso ya resolvió, y se consume el evento para que volver a la pantalla
//  no reabra la hoja sin que nadie la haya pedido.
//

import SwiftUI

extension View {
    func shareSheet(state: ShareState, onConsumed: @escaping () -> Void) -> some View {
        modifier(ShareSheetModifier(state: state, onConsumed: onConsumed))
    }
}

private struct ShareSheetModifier: ViewModifier {
    let state: ShareState
    let onConsumed: () -> Void

    @State private var target: ShareTarget?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                // El «preparando» del caso en que hay que traer el documento (FR-039). Es un aviso,
                // no un bloqueo: la persona puede seguir leyendo.
                if case .preparing = state {
                    Text(Strings.Share.preparing)
                        .bocTextStyle(BocTheme.typography.bodyMedium)
                        .foregroundStyle(BocTheme.colors.onPrimary)
                        .padding(.horizontal, BocTheme.spacing.md)
                        .padding(.vertical, BocTheme.spacing.xs)
                        .background(BocTheme.colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.banner))
                        .padding(.bottom, BocTheme.spacing.xxl)
                        .accessibilityIdentifier("share_preparing")
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { target != nil },
                    set: { if !$0 { target = nil; onConsumed() } }
                )
            ) {
                if let target { ShareSheetContent(target: target) }
            }
            .onChange(of: state) { _, nuevo in
                if case .ready(let destino) = nuevo { target = destino }
            }
    }
}

/// Lo que se entrega, y la explicación cuando es el enlace.
private struct ShareSheetContent: View {
    let target: ShareTarget

    var body: some View {
        VStack(spacing: BocTheme.spacing.md) {
            switch target {
            case .document(let document):
                // **Un tipo propio necesita `preview:`**, a diferencia de una `URL` o un `String`:
                // sin ella no hay sobrecarga que case y el error que da el compilador —«no exact
                // matches in call to initializer»— no dice por qué.
                ShareLink(
                    item: document,
                    subject: Text(document.fileName),
                    message: Text(Strings.Card.shareChooser),
                    preview: SharePreview(document.fileName, image: Image(.icDocument))
                ) {
                    Text(Strings.Detail.share)
                        .bocTextStyle(BocTheme.typography.labelLarge)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(BocPrimaryButtonStyle())
                .accessibilityIdentifier("share_document")

            case .link(let url, let reason):
                // **El caso degradado se explica** (FR-040). Sin el motivo, compartir un enlace en
                // lugar del documento sorprende.
                Text(reason == .noConnection ? Strings.Share.linkFallback : Strings.Share.linkFallback)
                    .bocTextStyle(BocTheme.typography.bodyMedium)
                    .foregroundStyle(BocTheme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("share_link_reason")

                ShareLink(item: url, message: Text(Strings.Card.shareChooser)) {
                    Text(Strings.Detail.share)
                        .bocTextStyle(BocTheme.typography.labelLarge)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(BocPrimaryButtonStyle())
                .accessibilityIdentifier("share_link")
            }
        }
        .padding(BocTheme.spacing.screenMargin)
        .presentationDetents([.height(220)])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("share_sheet")
    }
}
