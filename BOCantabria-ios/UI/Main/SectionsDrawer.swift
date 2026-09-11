//
//  SectionsDrawer.swift
//  The sections panel, built by hand.
//
//  **Se abre solo con el botón.** No hay gesto de apertura desde el borde, y es una decisión, no
//  una omisión: en iPhone ese borde ya lo usan el gesto de retroceso interactivo y los del
//  sistema, y una banda de arrastre ahí compite con los dos. Se cierra deslizando, tocando fuera y
//  con la flecha de la cabecera.
//
//  **Se mantiene montado con el panel cerrado**, para conservar la animación y el arrastre. Eso
//  obliga a `.accessibilityHidden(!isOpen)` **además** de `.allowsHitTesting(isOpen)`: lo segundo
//  a secas solo quita la pulsabilidad, y el contenido del panel seguiría encontrándose en el árbol
//  de accesibilidad con el panel cerrado.
//
//  Y hay que reponer a mano lo que una hoja nativa traería gratis: el rasgo modal, para que el
//  lector de pantalla ignore lo de detrás, y la acción de escape.
//

import SwiftUI

struct SectionsDrawer<Content: View>: View {
    let state: MainUiState
    @Binding var isOpen: Bool
    let onSelect: (HomeSelection) -> Void
    let onToggleExpanded: (String) -> Void
    let onClosed: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0

    private let width: CGFloat = 300

    var body: some View {
        ZStack(alignment: .leading) {
            content()

            if isOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .background(BocTheme.colors.scrim.ignoresSafeArea())
                    .accessibilityIdentifier("sections_drawer_scrim")
                    .accessibilityLabel(Text(Strings.Sections.close))
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
            }

            // **Se desmonta cuando está cerrado.** Se intentó mantenerlo montado y ocultarlo con
            // `.accessibilityHidden`, que es lo que conserva la animación de entrada: no funciona.
            // Ni antes ni después de declarar el contenedor: el contenido del panel cerrado se
            // sigue encontrando en el árbol, y una prueba que buscara una sección con el panel
            // cerrado la encontraría. La animación se conserva igual con una transición.
            if isOpen {
                panel
                    .frame(width: width)
                    .offset(x: max(dragOffset, -width))
                    .transition(.move(edge: .leading))
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, offset, _ in
                                offset = min(value.translation.width, 0)
                            }
                            .onEnded { value in
                                if value.translation.width < -60 { close() }
                            }
                    )
            }
        }
        .animation(.easeOut(duration: 0.25), value: isOpen)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(BocTheme.colors.divider)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.sections) { row in
                        SectionsDrawerRow(
                            row: row,
                            isExpanded: state.expanded.contains(row.id),
                            selection: state.selection,
                            onSelect: { selection in
                                onSelect(selection)
                                close()
                            },
                            onToggle: { onToggleExpanded(row.id) }
                        )
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(BocTheme.colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sections_drawer")
        // El rasgo modal le dice al lector de pantalla que ignore todo lo que hay detrás. Es lo
        // que una hoja nativa daría hecho y aquí hay que reponer. Solo se aplica cuando el panel
        // está montado, que es cuando está abierto.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private var header: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            Image(.icEscudoCantabria)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .accessibilityHidden(true)

            Text(Strings.AppBar.title)
                .bocTextStyle(BocTheme.typography.titleLarge)
                .foregroundStyle(BocTheme.colors.primary)

            Spacer(minLength: 0)

            // Una flecha de volver y no una equis: en esta aplicación la equis cierra un campo de
            // texto o una hoja. Para un panel que se retira lateralmente, la flecha y el
            // movimiento coinciden.
            Button { close() } label: {
                Image(.icArrowBack)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(BocTheme.colors.primary)
            .accessibilityLabel(Text(Strings.Sections.close))
            .accessibilityIdentifier("sections_drawer_dismiss")
        }
        .padding(.horizontal, BocTheme.spacing.md)
        .frame(minHeight: 72)
    }

    /// Recoger el panel **no navega y no cambia la selección** (FR-062).
    private func close() {
        isOpen = false
        onClosed()
    }
}
