//
//  MainView.swift
//  The shell: three destinations, and a panel over all three.
//
//  El orden de anidamiento importa y es fácil equivocarse:
//
//  ```
//  RootView   → portada  ⟷  MainView          (conmutador; la portada no entra en la pila)
//  MainView   → ZStack { TabView ; velo ; panel }
//  cada Tab   → NavigationStack { … }
//  ```
//
//  Un `NavigationStack` **envolviendo** al `TabView` es el error habitual: rompe la barra de
//  pestañas y deja una sola pila para tres destinos. Y el panel va **por encima** del `TabView`,
//  no dentro de la pestaña de Inicio, porque un panel que deja la barra de pestañas pulsable es un
//  modal que no lo es.
//
//  Como la portada es hermana de esta vista y no está dentro, el panel **no la alcanza** (FR-072).
//
//  **Los modelos de pantalla se construyen en el inicializador, nunca en el cuerpo** (FR-051). El de
//  Inicio nacía dentro de la propiedad calculada `tabs`, que el sistema evalúa en cada redibujado, y
//  su inicializador registra una visita de analítica y abre un intervalo de medición. El `@State` de
//  `HomeView` se quedaba con el primero, así que en pantalla no se veía nada: se veía en el panel
//  del proveedor, con una visita por cada apertura del panel lateral. Medido: **tres redibujados,
//  tres visitas**.
//
//  La feature del detalle lo habría empeorado, porque su pila de navegación añade estado a esta
//  vista y entonces cada entrada y cada retroceso redibujan. Hay prueba de regresión, y falla si
//  alguien devuelve la construcción al cuerpo (research.md D-523).
//

import SwiftUI

struct MainView: View {
    let container: AppContainer

    @State private var viewModel: MainViewModel
    /// **Vive aquí y no en `tabs`**, que es el defecto que FR-051 corrige.
    @State private var homeViewModel: HomeViewModel
    /// Efímero y no sobrevive a nada, así que es `@State` de la vista y no de un modelo.
    @State private var isDrawerOpen = false
    /// La pila de la pestaña de Inicio. **Las tres rutas viven aquí dentro**, no en un contenedor
    /// que envuelva al `TabView`: un `NavigationStack` por encima rompería la barra de pestañas y
    /// dejaría una sola pila para tres destinos.
    @State private var homePath = NavigationPath()
    /// La pestaña se restaura **por nombre**, con su alternativa explícita detrás.
    @SceneStorage("main_tab") private var storedTab: String = MainTab.home.rawValue

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeMainViewModel())
        _homeViewModel = State(initialValue: container.makeHomeViewModel())
    }

    var body: some View {
        SectionsDrawer(
            state: viewModel.state,
            isOpen: $isDrawerOpen,
            onSelect: { viewModel.onSelect($0) },
            onToggleExpanded: { viewModel.onToggleExpanded($0) },
            onClosed: { viewModel.onDrawerClosed() }
        ) {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: tabBinding) {
            Tab(value: MainTab.home) {
                NavigationStack(path: $homePath) {
                    HomeView(
                        viewModel: homeViewModel,
                        selection: viewModel.state.selection,
                        onSelect: { viewModel.onSelect($0) },
                        onOpenSections: { isDrawerOpen = true },
                        // **Por clave, no por objeto**: el detalle observa la fila (D-512).
                        onOpen: { homePath.append(Route.publicationDetail(externalKey: $0.externalKey)) }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Route.self) { destination($0) }
                }
            } label: {
                Label {
                    Text(Strings.Nav.home)
                } icon: {
                    Image(.icHome)
                }
            }

            Tab(value: MainTab.search) {
                NavigationStack { ComingSoonMessage(title: Strings.Nav.search) }
            } label: {
                Label {
                    Text(Strings.Nav.search)
                } icon: {
                    Image(.icSearch)
                }
            }

            Tab(value: MainTab.saved) {
                NavigationStack { ComingSoonMessage(title: Strings.Nav.saved) }
            } label: {
                Label {
                    Text(Strings.Nav.saved)
                } icon: {
                    Image(.icBookmark)
                }
            }
        }
        // El fondo se declara explícitamente: por defecto la barra pinta un material translúcido, y
        // el apartado 10.1 del documento de diseño pide blanco con borde superior.
        .toolbarBackground(BocTheme.colors.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(BocTheme.colors.secondary)
    }

    /// Los tres destinos de la pila.
    ///
    /// **Cada uno construye su modelo de pantalla aquí**, y eso está bien: a diferencia de `tabs`,
    /// este cierre solo se evalúa cuando el destino entra en la pila, no en cada redibujado. Es la
    /// distinción que FR-051 corrigió arriba.
    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .publicationDetail(let externalKey):
            PublicationDetailView(
                viewModel: container.makePublicationDetailViewModel(externalKey: externalKey),
                onOpenDocument: { homePath.append(Route.pdfViewer(externalKey: externalKey)) },
                onAsk: { homePath.append(Route.ask(externalKey: externalKey)) }
            )
        case .pdfViewer(let externalKey):
            PdfViewerView(viewModel: container.makePdfViewerViewModel(externalKey: externalKey))
        case .ask(let externalKey):
            AskView(externalKey: externalKey)
        }
    }

    private var tabBinding: Binding<MainTab> {
        Binding(
            get: { MainTab.restored(from: storedTab) },
            set: { tab in
                storedTab = tab.rawValue
                viewModel.onSelectTab(tab)
            }
        )
    }
}
