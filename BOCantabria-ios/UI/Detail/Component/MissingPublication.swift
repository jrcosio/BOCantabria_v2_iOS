//
//  MissingPublication.swift
//  The publication is no longer stored.
//
//  **No es un error, y por eso no tiene reintento**: la publicación se retiró al liberar espacio, y
//  volver a intentarlo no la trae. Lo que hay es una salida (FR-004).
//

import SwiftUI

struct MissingPublication: View {
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: BocTheme.spacing.md) {
            Image(.icWarning)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(BocTheme.colors.textMuted)
                .accessibilityHidden(true)

            Text(Strings.Detail.missingTitle)
                .bocTextStyle(BocTheme.typography.titleLarge)
                .foregroundStyle(BocTheme.colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(Strings.Detail.missingBody)
                .bocTextStyle(BocTheme.typography.bodyMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onBack) {
                Text(Strings.Detail.missingAction)
                    .bocTextStyle(BocTheme.typography.labelLarge)
                    .padding(.horizontal, BocTheme.spacing.lg)
                    .padding(.vertical, BocTheme.spacing.sm)
            }
            .buttonStyle(BocSecondaryButtonStyle())
            .accessibilityIdentifier("detail_missing_action")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BocTheme.spacing.screenMargin)
        .background(BocTheme.colors.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_missing")
    }
}

#Preview {
    MissingPublication()
}
