//
//  RootView.swift
//  The navigation host.
//
//  **La portada es un conmutador, no un destino de navegación** (research.md D-201). La raíz
//  muestra la portada *o* la pila de navegación; la portada nunca entra en la pila, así que el
//  requisito de que el retroceso no devuelva a ella (FR-007) es una propiedad de la forma del
//  árbol de vistas y no algo que haya que acordarse de hacer al navegar.
//
//  Aquí vive además el modelo de pantalla del arranque, y por eso su estado sobrevive al ciclo de
//  segundo plano sin reiniciar la preparación (FR-008).
//

import SwiftUI

struct RootView: View {
    let container: AppContainer

    @State private var splashViewModel: SplashViewModel
    @State private var path: [Route] = []

    init(container: AppContainer) {
        self.container = container
        _splashViewModel = State(initialValue: container.makeSplashViewModel())
    }

    var body: some View {
        Group {
            if splashViewModel.state == .ready {
                NavigationStack(path: $path) {
                    HomeView(viewModel: container.makeHomeViewModel())
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .home:
                                HomeView(viewModel: container.makeHomeViewModel())
                            }
                        }
                }
            } else {
                SplashView(viewModel: splashViewModel)
            }
        }
        .animation(.easeInOut, value: splashViewModel.state)
        .tint(BocTheme.colors.primary)
    }
}
