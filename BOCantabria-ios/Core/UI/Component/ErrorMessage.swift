//
//  ErrorMessage.swift
//  The shared error state, with its retry action.
//
//  El reintento va **con** el mensaje y no en otro sitio: un error sin salida es una pantalla sin
//  salida (FR-003).
//

import SwiftUI

struct ErrorMessage: View {
    let message: LocalizedStringResource
    let retryTitle: LocalizedStringResource
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: BocTheme.spacing.md) {
            Text(message)
                .bocTextStyle(BocTheme.typography.bodyLarge)
                .foregroundStyle(BocTheme.colors.textPrimary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text(retryTitle)
                    .bocTextStyle(BocTheme.typography.labelLarge)
                    .padding(.horizontal, BocTheme.spacing.lg)
                    .padding(.vertical, BocTheme.spacing.sm)
            }
            .buttonStyle(BocPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BocTheme.spacing.screenMargin)
    }
}

/// El botón principal del sistema de diseño.
///
/// Consume `primaryPressed`, y eso es lo que cambia de papel al portar: en Android ese token lo
/// absorbía el efecto de pulsación de Material y ni siquiera se exponía. Aquí no hay tal efecto,
/// así que el estado pulsado se pinta (research.md D-111).
struct BocPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BocTheme.colors.onPrimary)
            .background(
                configuration.isPressed
                    ? BocTheme.colors.primaryPressed
                    : BocTheme.colors.primary
            )
            .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.small))
    }
}

/// El botón principal **sobre el azul institucional**.
///
/// `BocPrimaryButtonStyle` pinta el fondo con `primary`, que es exactamente el color de fondo de la
/// portada: allí el botón se vuelve invisible y solo se ve su texto. No es un caso raro —es el
/// único sitio donde hay un botón sobre `primary`— y se descubrió mirando la portada con el texto
/// al 200 %, no leyendo el código.
struct BocOnPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BocTheme.colors.primary)
            .background(
                configuration.isPressed
                    ? BocTheme.colors.onPrimaryAccent
                    : BocTheme.colors.onPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.small))
    }
}

#Preview {
    ErrorMessage(
        message: Strings.Home.errorSync,
        retryTitle: Strings.Action.retry,
        onRetry: {}
    )
}
