//
//  HomeContentView.swift
//  The rendering of the initial screen.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las pruebas
//  pueden recorrer los estados sin arrancar el grafo, y las vistas previas también.
//
//  **Un matiz que hasta la 004 no hacía falta**: esta vista tenía escrito que era «sin estado», y
//  ha dejado de serlo. Tiene exactamente uno propio, `isHeaderCompact`, y es efímero: describe
//  dónde está el dedo, no qué se está mostrando. No sale de aquí, nadie más lo consulta y el
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

    /// La cabecera está encogida. **Efímero, y por eso vive aquí** (research.md D-409).
    @State private var isHeaderCompact = false

    /// Los dos umbrales del desplazamiento, en puntos.
    ///
    /// **Son dos y no uno, y esa es la decisión** (research.md D-408). La cabecera está *fuera*
    /// del `ScrollView`, así que compactarla no cambia el contenido pero **agranda el
    /// contenedor**: con un listado apenas más alto que la pantalla, el desplazamiento máximo baja,
    /// el sistema recorta el actual, el valor cae por debajo del umbral y la cabecera vuelve a
    /// crecer. La secuencia termina —no es un bucle—, pero es un salto visible, y FR-012 pide lo
    /// contrario. Con una banda entre los dos, el retorno no alcanza al de bajada.
    ///
    /// **El de subida es positivo a propósito**: `refreshable` hace negativo el desplazamiento al
    /// tirar hacia abajo, y con el umbral en cero la cabecera parpadearía en mitad del gesto.
    ///
    /// No salen de `BocTheme` porque no son tamaños del sistema de diseño: son un umbral de gesto,
    /// no describen nada que se vea y el documento de diseño no los declara.
    private static let compactAbove: CGFloat = 24
    private static let expandBelow: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            fixedZone

            ScrollView {
                listing
            }
            // Sin esto, deslizar para actualizar **desaparece en los estados vacío y de error**
            // (research.md D-407). Hasta la 004 el contenedor envolvía la pantalla entera y
            // siempre rebotaba; ahora envuelve solo el listado, y hay dos estados en los que el
            // contenido cabe en la ventana. No lo caza ninguna prueba: se ve usando la aplicación.
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { await onRefresh() }
            // Se publica **un booleano, no el desplazamiento**: el cierre se evalúa en cada
            // fotograma, y una cifra invalidaría la cabecera sesenta veces por segundo para decir
            // lo mismo. Con un `Equatable`, SwiftUI solo entrega cuando el valor cambia.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > (isHeaderCompact ? Self.expandBelow : Self.compactAbove)
            } action: { _, isPast in
                isHeaderCompact = isPast
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
                BulletinHeaderView(header: header, isCompact: isHeaderCompact)
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
