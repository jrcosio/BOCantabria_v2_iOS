//
//  AskView.swift
//  Asking about the publication. A placeholder, and it says so.
//
//  **Es una pantalla propia y no un diálogo** (FR-044), y eso es lo que esta feature deja hecho: su
//  sitio en la pila de retroceso y su ruta, que ya lleva la clave aunque todavía no la lea. Añadir
//  el argumento después obligaría a cambiar una ruta que ya estaría en la calle.
//
//  Una conversación sobre un boletín de cuarenta páginas necesita la pantalla entera, que no es lo
//  que da un diálogo encima de una ficha de metadatos.
//

import SwiftUI

struct AskView: View {
    /// Todavía no se lee. Está por lo que dice la cabecera.
    let externalKey: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ComingSoonMessage(title: Strings.Ask.title)
        }
        .background(BocTheme.colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask_root")
    }

    private var topBar: some View {
        HStack(spacing: BocTheme.spacing.xxs) {
            Button { dismiss() } label: {
                Image(.icArrowBack)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(BocTheme.colors.onPrimary)
            .accessibilityLabel(Text(Strings.Detail.back))
            .accessibilityIdentifier("ask_back")

            Image(.icEscudoCantabria)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(Strings.Ask.title)
                .bocTextStyle(BocTheme.typography.titleMedium)
                .foregroundStyle(BocTheme.colors.onPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, BocTheme.spacing.xxs)
        }
        .padding(.horizontal, BocTheme.spacing.xs)
        .background(BocTheme.colors.primary)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    AskView(externalKey: "boc:439765")
}
