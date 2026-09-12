//
//  HomeContentView.swift
//  The rendering of the initial screen.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las pruebas
//  pueden recorrer los estados sin arrancar el grafo, y las vistas previas también.
//
//  **Un matiz que hasta la 004 no hacía falta**: esta vista tenía escrito que era «sin estado», y
//  ha dejado de serlo. Tiene dos propios, `collapse` y `headerCollapsible`, y los dos son
//  efímeros: describen dónde está el dedo y cuánto alto puede liberar la cabecera, no qué se está
//  mostrando. No sale de aquí, nadie más lo consulta y el
//  modelo de pantalla no podría decidirlo, porque depende de una geometría que solo conoce el
//  `ScrollView`. Es el mismo caso que el abierto/cerrado del panel lateral, que vive en
//  `MainView` por las mismas tres razones (research.md D-409, y D-319 de la 003).
//
//  De arriba abajo: barra superior clara, cabecera editorial azul, filtros rápidos —una fila o
//  dos— y listado (FR-030). **Solo el listado se desplaza** (FR-009): lo de arriba se queda, y
//  la cabecera encoge.
//

import SwiftUI

struct HomeContentView: View {
    let state: HomeUiState
    var onRefresh: () async -> Void = {}
    var onRetry: () -> Void = {}
    var onSelect: (SectionChip) -> Void = { _ in }
    var onOpenSections: () -> Void = {}
    var onSearch: () -> Void = {}
    var onInfo: () -> Void = {}
    var onShare: (Publication) -> Void = { _ in }
    var onSave: (Publication) -> Void = { _ in }

    /// Cuánto está encogida la cabecera, de 0 a 1. **Efímero, y por eso vive aquí** (D-409).
    @State private var collapse: CGFloat = 0

    /// Cuánto alto puede liberar la cabecera. Lo publica ella, medido (D-418).
    ///
    /// Es a la vez **la distancia de colapso** —en cuántos puntos de recorrido se completa— y **lo
    /// que hay que devolverle al contenido**. Que las dos cosas sean el mismo número no es
    /// casualidad: es lo que hace que el listado se mueva exactamente lo que se arrastra.
    @State private var headerCollapsible: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            fixedZone

            ScrollView {
                VStack(spacing: 0) {
                    // **El separador que devuelve lo que la cabecera libera** (D-418).
                    //
                    // Sin él, la posición visible del contenido es `altoCabecera − desplazamiento`:
                    // si la cabecera encoge mientras se desplaza, el listado se mueve **más rápido
                    // que el dedo**, y eso es lo que se siente como un salto. Con él, los dos
                    // términos se cancelan y queda `H₀ − desplazamiento`: **1:1, siempre**.
                    //
                    // Va **dentro del contenido** y no como relleno del contenedor a propósito: con
                    // `.padding(.top,)` la cuenta también sale, pero el borde del `ScrollView` se
                    // despega del divisor y deja una franja de fondo de hasta cincuenta puntos.
                    // Aquí, al desplazar queda enteramente fuera de vista.
                    Color.clear
                        .frame(height: headerCollapsible * collapse)
                        .accessibilityHidden(true)

                    listing
                }
            }
            // Sin esto, deslizar para actualizar **desaparece en los estados vacío y de error**
            // (research.md D-407). Hasta la 004 el contenedor envolvía la pantalla entera y
            // siempre rebotaba; ahora envuelve solo el listado, y hay dos estados en los que el
            // contenido cabe en la ventana. No lo caza ninguna prueba: se ve usando la aplicación.
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { await onRefresh() }
            // Se publica **una cifra continua, no un booleano** (D-418). El booleano con umbral
            // que esto sustituye no podía acompañar al gesto: cambiaba de golpe cuando el dedo ya
            // había hecho otra cosa.
            //
            // La distancia de colapso **es** el alto que la cabecera libera, y por eso el
            // encogimiento va al ritmo del dedo. Tirar hacia abajo da desplazamiento negativo, que
            // la pinza deja en cero, así que el gesto de actualizar no la toca — y por eso tampoco
            // hace falta el umbral positivo que antes lo protegía.
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                // Con animación nula: una animación implícita heredada convertiría un valor
                // continuo en una escalera, que es el defecto que esto viene a corregir.
                withTransaction(Transaction(animation: nil)) {
                    collapse = headerCollapsible > 0
                        ? min(max(offset / headerCollapsible, 0), 1)
                        : 0
                }
            }
        }
        .background(BocTheme.colors.background)
    }

    /// Lo que **no** se desplaza (FR-009).
    ///
    /// El fondo sólido y el divisor no son adorno: el apartado 14.6 del documento de diseño los
    /// pide desde el principio para los filtros fijados, y sin ellos las tarjetas pasarían por
    /// debajo de unos chips transparentes y se leerían las dos cosas a la vez (FR-013).
    private var fixedZone: some View {
        VStack(spacing: 0) {
            HomeTopBar(onOpenSections: onOpenSections, onSearch: onSearch, onInfo: onInfo)

            if let header = state.header {
                BulletinHeaderView(
                    header: header,
                    collapse: collapse,
                    onCollapsibleHeight: { headerCollapsible = $0 }
                )
            }

            SectionChipRow(
                chips: state.sectionChips,
                selectedCode: state.selection.topLevelCode ?? SectionChip.todayCode,
                style: .primary,
                onSelect: onSelect
            )
            .accessibilityIdentifier("home_section_chips")

            // La segunda fila **no existe** cuando no procede: ni vacía, ni oculta (FR-052).
            if state.hasSubsectionRow {
                SectionChipRow(
                    chips: state.subsectionChips,
                    selectedCode: state.selection.subsectionCode
                        ?? state.selection.topLevelCode,
                    style: .secondary,
                    onSelect: onSelect
                )
                .accessibilityIdentifier("home_subsection_chips")
            }

            // Va con la zona fija, y es decisión del propietario: habla de toda la pantalla —de
            // que lo que se lee es lo último descargado—, así que perderlo de vista al desplazar
            // haría creer que se está leyendo lo de hoy (FR-014).
            if state.isOffline {
                OfflineBanner()
            }
        }
        .background(BocTheme.colors.surface)
        // Un `Divider()` pintaría el color de separador **del sistema**, no el token del proyecto.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BocTheme.colors.divider)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var listing: some View {
        switch state.content {
        case .skeleton:
            // Cinco como máximo, con la forma del contenido final: un indicador giratorio grande
            // no dice qué está por venir (FR-041).
            VStack(spacing: BocTheme.spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in PublicationCardSkeleton() }
            }
            .padding(.horizontal, BocTheme.spacing.screenMargin)
            .padding(.vertical, BocTheme.spacing.sm)
            // Elemento propio, no contenedor: los marcadores están ocultos al lector de pantalla
            // —no dicen nada— así que un contenedor sin hijos accesibles no entra en el árbol.
            .accessibilityElement()
            .accessibilityLabel(Text(Strings.Home.loading))
            .accessibilityIdentifier("home_skeleton")

        case .publications(let items):
            LazyVStack(spacing: BocTheme.spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, publication in
                    PublicationCard(
                        publication: publication,
                        onShare: { onShare(publication) },
                        onSave: { onSave(publication) }
                    )
                    .accessibilityIdentifier("publication_card_\(index)")
                }
            }
            .padding(.horizontal, BocTheme.spacing.screenMargin)
            .padding(.vertical, BocTheme.spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home_content")

        case .empty:
            EmptyMessage(message: emptyMessage)
                .padding(.top, BocTheme.spacing.xxl)
                .accessibilityIdentifier("home_empty")

        case .error:
            // El error de dominio no se pinta: la pantalla nunca dice códigos. Lo que se ve es
            // siempre el mismo texto, y el detalle vive en el registro.
            ErrorMessage(
                message: Strings.Home.errorSync,
                retryTitle: Strings.Action.retry,
                retryIdentifier: "home_retry",
                onRetry: onRetry
            )
            .padding(.top, BocTheme.spacing.xxl)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home_error")
        }
    }

    /// El estado vacío dice cosas distintas según lo que se esté mirando: «no hay nada hoy» y
    /// «esta sección no tiene nada» no son el mismo mensaje.
    private var emptyMessage: LocalizedStringResource {
        switch state.selection {
        case .todaysBulletin: Strings.Home.emptyToday
        case .section: Strings.Home.emptySection
        }
    }
}

#Preview("Marcadores") {
    HomeContentView(state: HomeUiState(sectionChips: previewChips))
}

#Preview("Sin contenido") {
    HomeContentView(state: HomeUiState(sectionChips: previewChips, content: .empty))
}

#Preview("Error") {
    HomeContentView(state: HomeUiState(sectionChips: previewChips, content: .error(.network)))
}

private let previewChips: [SectionChip] =
    [SectionChip(code: SectionChip.todayCode, title: "Boletín de hoy")]
    + BocSection.topLevel.map { SectionChip(code: $0.code, title: $0.shortName) }
