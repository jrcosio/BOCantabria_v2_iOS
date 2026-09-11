//
//  ComingSoonMessage.swift
//  What a destination that does not exist yet says.
//
//  **Con el aspecto de la aplicación**, no una pantalla en blanco: un destino que no responde se
//  percibe como una aplicación rota; uno que dice lo que pasa, no (FR-071).
//

import SwiftUI

struct ComingSoonMessage: View {
    let title: LocalizedStringResource

    var body: some View {
        VStack(spacing: BocTheme.spacing.sm) {
            Text(title)
                .bocTextStyle(BocTheme.typography.headlineSmall)
                .foregroundStyle(BocTheme.colors.textPrimary)
            Text(Strings.Common.comingSoon)
                .bocTextStyle(BocTheme.typography.bodyLarge)
                .foregroundStyle(BocTheme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BocTheme.colors.background)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coming_soon")
    }
}

#Preview {
    ComingSoonMessage(title: Strings.Nav.search)
}
