//
//  EmptyMessage.swift
//  The shared "nothing to show" state.
//
//  **No es un error y no debe parecerlo.** La distinción entre «vacío» y «error» se toma en el
//  dominio —una colección vacía es un éxito— y se pinta aquí.
//

import SwiftUI

struct EmptyMessage: View {
    let message: LocalizedStringResource

    var body: some View {
        Text(message)
            .bocTextStyle(BocTheme.typography.bodyLarge)
            .foregroundStyle(BocTheme.colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(BocTheme.spacing.screenMargin)
    }
}

#Preview {
    EmptyMessage(message: Strings.Home.emptyToday)
}
