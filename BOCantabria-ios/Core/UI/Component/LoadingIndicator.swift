//
//  LoadingIndicator.swift
//  The shared loading state.
//
//  Sin estado: recibe todo por parámetro y no conoce ningún modelo de pantalla, de modo que se
//  puede previsualizar y probar aislado.
//

import SwiftUI

struct LoadingIndicator: View {
    let message: LocalizedStringResource

    var body: some View {
        VStack(spacing: BocTheme.spacing.sm) {
            ProgressView()
                .tint(BocTheme.colors.primary)
            Text(message)
                .bocTextStyle(BocTheme.typography.bodyMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BocTheme.spacing.screenMargin)
    }
}

#Preview {
    LoadingIndicator(message: Strings.Home.loading)
}
