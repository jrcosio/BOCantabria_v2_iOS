//
//  OfflineBanner.swift
//  «No connection. You are seeing the last download.»
//
//  **No oculta el contenido** (FR-043). Es lo que distingue un aviso de un estado: el contenido
//  guardado sigue siendo válido y se sigue pudiendo leer.
//

import SwiftUI

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            Image(.icCloudOff)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(Strings.Home.offline)
                .bocTextStyle(BocTheme.typography.bodySmall)
            Spacer(minLength: 0)
        }
        .foregroundStyle(BocTheme.colors.textSecondary)
        .padding(.horizontal, BocTheme.spacing.sm)
        .padding(.vertical, BocTheme.spacing.xs)
        .background(BocTheme.colors.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.banner))
        .padding(.horizontal, BocTheme.spacing.screenMargin)
        .padding(.top, BocTheme.spacing.xs)
        .accessibilityIdentifier("home_offline_banner")
    }
}

#Preview {
    OfflineBanner()
}
