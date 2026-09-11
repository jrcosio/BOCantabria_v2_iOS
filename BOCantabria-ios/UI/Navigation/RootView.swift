//
//  RootView.swift
//  The navigation host.
//
//  **La portada es un conmutador, no un destino de navegación** (research.md D-201). La raíz
//  muestra la portada *o* el armazón; la portada nunca entra en una pila, así que el requisito de
//  que el retroceso no devuelva a ella (FR-078) es una propiedad de la forma del árbol de vistas y
//  no algo que haya que acordarse de hacer al navegar.
//
//  Y como la portada es **hermana** del armazón y no está dentro, el panel de secciones no la
//  alcanza (FR-072).
//
//  Aquí vive además el modelo de pantalla del arranque, y por eso su estado sobrevive al ciclo de
//  segundo plano sin reiniciar la preparación.
//

import SwiftUI

struct RootView: View {
    let container: AppContainer

    @State private var splashViewModel: SplashViewModel

    init(container: AppContainer) {
        self.container = container
        _splashViewModel = State(initialValue: container.makeSplashViewModel())
    }

    var body: some View {
        Group {
            if splashViewModel.state == .ready {
                MainView(container: container)
            } else {
                SplashView(viewModel: splashViewModel)
            }
        }
        .animation(.easeInOut, value: splashViewModel.state)
        .tint(BocTheme.colors.primary)
    }
}
