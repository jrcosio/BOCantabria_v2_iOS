//
//  DetailActionBar.swift
//  The bottom action bar (§18.5).
//
//  **«Más área segura» no era un adorno.** La barra aplica el margen inferior **dentro de su propia
//  superficie**: si lo aplicara el contenedor, la barra quedaría anclada al borde crudo de la
//  ventana y sus botones se solaparían con el indicador de inicio (FR-049).
//
//  Y **se apilan si no caben** (FR-050). Con el texto al 200 %, «Abrir PDF oficial» y «Preguntar»
//  no comparten línea. La trampa de `ViewThatFits` ya está anotada en la tarjeta: un separador sin
//  longitud mínima tiene un ideal minúsculo, así que la fila «cabría» siempre y el segundo
//  candidato no se elegiría nunca.
//

import SwiftUI

struct DetailActionBar: View {
    var onOpen: () -> Void = {}
    var onAsk: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BocTheme.spacing.sm) {
                openButton
                askButton
            }
            VStack(spacing: BocTheme.spacing.sm) {
                openButton
                askButton
            }
        }
        .padding(.horizontal, BocTheme.spacing.md)
        .padding(.top, BocTheme.spacing.sm)
        .padding(.bottom, BocTheme.spacing.sm)
        .frame(maxWidth: .infinity)
        .background(BocTheme.colors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(BocTheme.colors.divider).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_actions")
    }

    /// **La acción más destacada de la pantalla** (FR-046). Es la razón por la que existe.
    private var openButton: some View {
        Button(action: onOpen) {
            HStack(spacing: BocTheme.spacing.xs) {
                Image(.icDocument).resizable().scaledToFit().frame(width: 20, height: 20)
                Text(Strings.Detail.actionOpen)
                    .bocTextStyle(BocTheme.typography.labelLarge)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, BocTheme.spacing.ml)
        }
        .buttonStyle(BocPrimaryButtonStyle())
        .accessibilityIdentifier("detail_action_open")
    }

    private var askButton: some View {
        Button(action: onAsk) {
            HStack(spacing: BocTheme.spacing.xs) {
                Image(.icAsk).resizable().scaledToFit().frame(width: 20, height: 20)
                Text(Strings.Detail.actionAsk)
                    .bocTextStyle(BocTheme.typography.labelLarge)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, BocTheme.spacing.ml)
        }
        .buttonStyle(BocSecondaryButtonStyle())
        .accessibilityIdentifier("detail_action_ask")
    }
}

/// El botón secundario del §11.2: borde de un punto en `primary`, mismas medidas que el principal.
struct BocSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BocTheme.colors.primary)
            .background(
                configuration.isPressed ? BocTheme.colors.primaryContainer : BocTheme.colors.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.small))
            .overlay(
                RoundedRectangle(cornerRadius: BocTheme.shape.small)
                    .stroke(BocTheme.colors.primary, lineWidth: 1)
            )
    }
}
