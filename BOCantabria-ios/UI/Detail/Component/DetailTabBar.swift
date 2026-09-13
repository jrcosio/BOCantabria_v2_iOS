//
//  DetailTabBar.swift
//  The two tabs, pinned under the top bar.
//
//  Dos, no tres: «Preguntar» es pantalla propia (FR-014). El apartado 11.7 del documento de diseño
//  fija el alto en 56, el indicador inferior en 3 y los colores.
//

import SwiftUI

struct DetailTabBar: View {
    let selected: DetailTab
    var onSelect: (DetailTab) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            tab(.document, title: Strings.Detail.tabDocument, icon: nil, id: "detail_tab_document")
            tab(.aiSummary, title: Strings.Detail.tabSummary, icon: .icAi, id: "detail_tab_summary")
        }
        .frame(height: 56)
        // **Fondo opaco y divisor** (FR-012). Fijada bajo la barra superior, el contenido pasa por
        // debajo; sin fondo, se leen dos cosas a la vez.
        .background(BocTheme.colors.surface)
        .overlay(alignment: .bottom) {
            // Un `Divider()` pintaría el color de separador **del sistema**, no el token.
            Rectangle().fill(BocTheme.colors.divider).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_tabs")
    }

    private func tab(
        _ tab: DetailTab,
        title: LocalizedStringResource,
        icon: ImageResource?,
        id: String
    ) -> some View {
        let activa = selected == tab
        return Button { onSelect(tab) } label: {
            VStack(spacing: 0) {
                HStack(spacing: BocTheme.spacing.xxs) {
                    // **La IA se distingue por icono y etiqueta, no solo por color** (FR-048).
                    if let icon {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    Text(title)
                        .bocTextStyle(BocTheme.typography.labelLarge)
                }
                .foregroundStyle(activa ? BocTheme.colors.primary : BocTheme.colors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(activa ? BocTheme.colors.primary : Color.clear)
                    .frame(height: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(activa ? [.isButton, .isSelected] : .isButton)
    }
}
