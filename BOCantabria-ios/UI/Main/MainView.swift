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

import SwiftUI

struct MainView: View {
    let container: AppContainer

    @State private var viewModel: MainViewModel
    /// Efímero y no sobrevive a nada, así que es `@State` de la vista y no de un modelo.
    @State private var isDrawerOpen = false
    /// La pestaña se restaura **por nombre**, con su alternativa explícita detrás.
    @SceneStorage("main_tab") private var storedTab: String = MainTab.home.rawValue

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeMainViewModel())
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
                NavigationStack {
                    HomeView(
                        viewModel: container.makeHomeViewModel(),
                        selection: viewModel.state.selection,
                        onSelect: { viewModel.onSelect($0) },
                        onOpenSections: { isDrawerOpen = true }
                    )
                    .toolbar(.hidden, for: .navigationBar)
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
