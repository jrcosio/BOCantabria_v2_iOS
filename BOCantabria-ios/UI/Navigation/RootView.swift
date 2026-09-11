//
//  RootView.swift
//  The navigation host.
//
//  Hoy hay un solo destino. El armazón está montado para que añadir el siguiente sea una entrada
//  más en `Route` y un caso más en el `switch`, sin rediseñar nada (FR-006).
//

import SwiftUI

struct RootView: View {
    let container: AppContainer

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(viewModel: container.makeHomeViewModel())
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .home:
                        HomeView(viewModel: container.makeHomeViewModel())
                    }
                }
        }
        .tint(BocTheme.colors.primary)
    }
}
