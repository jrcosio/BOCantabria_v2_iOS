//
//  PublicationDetailContentView.swift
//  The detail's rendering, which does not know the view model.
//
//  ## La cabecera se va y las pestañas se quedan
//
//  Es FR-011, y es **lo contrario** de lo que hizo la feature anterior en Inicio, donde la cabecera
//  se queda y encoge. Los dos motivos son buenos y opuestos: allí la cabecera dice **dónde estás**
//  y perderla era el problema; aquí dice **qué es esto**, ya se ha leído, y un título sin recortar
//  ocupa seis líneas — si se queda, el contenido vive en una franja estrecha para siempre.
//
//  Y por eso el mecanismo también es el contrario: **un encabezado fijado**, que es lo que el
//  sistema hace solo. Reutilizar la medición del desplazamiento de la 004 porque «ya estaba
//  resuelto» sería reimplementar a mano lo que el sistema regala, para obtener un comportamiento
//  distinto del que se necesita (research.md D-520).
//
//  **Tres trampas del mecanismo**, y las tres están cerradas abajo: el encabezado necesita fondo
//  opaco o el contenido se lee por debajo; necesita orden de dibujado explícito o el contenido
//  perezoso se pinta encima al desplazar; y tiene que haber **una sola sección**, porque dos
//  desmontarían el encabezado al cambiar de pestaña y el desplazamiento daría un salto.
//

import SwiftUI

struct PublicationDetailContentView: View {
    let state: PublicationDetailUiState
    var onBack: () -> Void = {}
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}
    var onSelectTab: (DetailTab) -> Void = { _ in }
    var onDocumentTabShown: () -> Void = {}
    var onRetryDocument: () -> Void = {}
    var onOpenDocument: () -> Void = {}
    var onAsk: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if state.isMissing {
                MissingPublication(onBack: onBack)
            } else if state.loadFailed {
                // No se pudo leer lo guardado. **Esto sí tiene reintento**, a diferencia de una
                // publicación retirada: aquí volver a intentarlo puede salir bien.
                ErrorMessage(
                    message: Strings.Home.errorSync,
                    retryTitle: Strings.Action.retry,
                    retryIdentifier: "detail_retry",
                    onRetry: onRetryDocument
                )
                .background(BocTheme.colors.background)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("detail_error")
            } else if let publication = state.publication {
                scrollingContent(publication)
                DetailActionBar(onOpen: onOpenDocument, onAsk: onAsk)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BocTheme.colors.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_root")
    }

    // MARK: - Barra superior (§18.1)

    private var topBar: some View {
        HStack(spacing: BocTheme.spacing.xxs) {
            iconButton(.icArrowBack, label: Strings.Detail.back, id: "detail_back", action: onBack)

            Image(.icEscudoCantabria)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(Strings.Detail.title)
                .bocTextStyle(BocTheme.typography.titleMedium)
                .foregroundStyle(BocTheme.colors.onPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, BocTheme.spacing.xxs)

            iconButton(.icBookmark, label: Strings.Card.save, id: "detail_save", action: onSave)
            iconButton(.icShare, label: Strings.Detail.share, id: "detail_share", action: onShare)
        }
        .padding(.horizontal, BocTheme.spacing.xs)
        .background(BocTheme.colors.primary)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Lo que se desplaza

    private func scrollingContent(_ publication: Publication) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                // **Fuera de la sección**: es lo que hace que se vaya con el contenido.
                DetailHeader(publication: publication, sectionName: state.sectionName)

                Section {
                    // **Una sola sección**, con el contenido conmutado dentro.
                    switch state.selectedTab {
                    case .document:
                        documentTab(publication)
                    case .aiSummary:
                        ComingSoonMessage(title: Strings.Detail.tabSummary)
                            .frame(minHeight: 320)
                    }
                } header: {
                    DetailTabBar(selected: state.selectedTab, onSelect: onSelectTab)
                        // Sin esto, el contenido que la pila crea al desplazar se dibuja **encima**
                        // del encabezado fijado: aparece y desaparece, y parece un fallo de render.
                        .zIndex(1)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("detail_scroll")
    }

    private func documentTab(_ publication: Publication) -> some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.md) {
            MetadataCard(publication: publication, sectionName: state.sectionName)
            DocumentFirstPagePreview(status: state.document, onRetry: onRetryDocument)
        }
        .padding(BocTheme.spacing.screenMargin)
        .task(id: publication.externalKey) { onDocumentTabShown() }
    }

    private func iconButton(
        _ icon: ImageResource,
        label: LocalizedStringResource,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BocTheme.colors.onPrimary)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }
}
