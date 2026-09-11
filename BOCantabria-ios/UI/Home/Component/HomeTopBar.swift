//
//  HomeTopBar.swift
//  The main top bar: menu, crest, name, search, information.
//
//  **Sin campana.** Un icono presente que no hace nada es peor que un icono que todavía no está;
//  las notificaciones llegan con su feature y entonces la campana vivirá en la barra inferior,
//  como cuarto destino, no aquí: dos campanas dirían lo mismo dos veces.
//

import SwiftUI

struct HomeTopBar: View {
    let onOpenSections: () -> Void
    let onSearch: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            iconButton(.icMenu, label: Strings.AppBar.openSections, identifier: "home_menu",
                       action: onOpenSections)

            Image(.icEscudoCantabria)
                .resizable()
                .scaledToFit()
                .frame(height: 34)
                .accessibilityHidden(true)

            Text(Strings.AppBar.title)
                .bocTextStyle(BocTheme.typography.titleLarge)
                .foregroundStyle(BocTheme.colors.primary)
                .padding(.leading, BocTheme.spacing.xxs)

            Spacer(minLength: 0)

            iconButton(.icSearch, label: Strings.AppBar.search, identifier: "home_search",
                       action: onSearch)
            iconButton(.icInfo, label: Strings.AppBar.info, identifier: "home_info",
                       action: onInfo)
        }
        .padding(.horizontal, BocTheme.spacing.md)
        .frame(height: 64)
        .background(BocTheme.colors.surface)
    }

    private func iconButton(
        _ icon: ImageResource,
        label: LocalizedStringResource,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                // Icono de 24, área táctil de 48: documento de diseño §11.4.
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BocTheme.colors.primary)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}
