//
//  SectionChipRow.swift
//  One row of filter chips. The same view serves both rows.
//
//  **La segunda fila se distingue por peso y color, no por un divisor ni por una sangría.** Una
//  jerarquía se comunica con peso; un divisor diría lo contrario —que son dos listas de iguales—
//  y la sangría se perdería al desplazar la fila.
//

import SwiftUI

struct SectionChipRow: View {
    enum Style {
        /// La fila de secciones.
        case primary
        /// La de subsecciones: subordinada a la de arriba.
        case secondary
    }

    let chips: [SectionChip]
    let selectedCode: String?
    var style: Style = .primary
    let onSelect: (SectionChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BocTheme.spacing.xs) {
                ForEach(chips) { chip in
                    chipView(chip)
                }
            }
            .padding(.horizontal, BocTheme.spacing.screenMargin)
        }
        // La fila se desplaza; el resto de la pantalla, no (FR-056).
        .scrollClipDisabled(false)
        .padding(.vertical, BocTheme.spacing.xs)
    }

    private func chipView(_ chip: SectionChip) -> some View {
        let isSelected = chip.code == selectedCode
        return Button { onSelect(chip) } label: {
            Text(chip.title)
                .bocTextStyle(style == .primary
                    ? BocTheme.typography.labelLarge
                    : BocTheme.typography.labelMedium)
                .foregroundStyle(foreground(isSelected: isSelected))
                .padding(.horizontal, 14)
                .frame(height: style == .primary ? 38 : 34)
                .background(background(isSelected: isSelected))
                .clipShape(BocTheme.shape.chip)
                .overlay(
                    BocTheme.shape.chip.stroke(border(isSelected: isSelected), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chip_\(chip.code)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private func foreground(isSelected: Bool) -> Color {
        if isSelected { return BocTheme.colors.onPrimary }
        return style == .primary ? BocTheme.colors.textPrimary : BocTheme.colors.textSecondary
    }

    private func background(isSelected: Bool) -> Color {
        if isSelected { return BocTheme.colors.secondary }
        return style == .primary ? BocTheme.colors.surface : BocTheme.colors.surfaceSoft
    }

    private func border(isSelected: Bool) -> Color {
        if isSelected { return BocTheme.colors.secondary }
        return style == .primary ? BocTheme.colors.outline : .clear
    }
}
