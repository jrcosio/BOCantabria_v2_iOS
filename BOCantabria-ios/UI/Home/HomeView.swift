//
//  HomeView.swift
//  The initial screen.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    /// La selección la posee el armazón y llega como valor. Es estado de interfaz, no una
    /// dependencia: mezclarla con el entorno invitaría a que el siguiente en viajar así fuera un
    /// caso de uso (research.md D-321).
    let selection: HomeSelection

    init(viewModel: HomeViewModel, selection: HomeSelection = .todaysBulletin) {
        _viewModel = State(initialValue: viewModel)
        self.selection = selection
    }

    var body: some View {
        HomeContentView(state: viewModel.state) {
            // Sin `Task` suelta: la cancelación la gobierna la vista. Una tarea sin dueño
            // sobrevive a la pantalla y escribe en un estado que ya no se ve.
            Task { await viewModel.onRetry() }
        }
        // Marca la pantalla entera, **en cualquiera de sus estados**. Es lo que permite que las
        // pruebas del arranque afirmen «se llegó al contenido principal» sin atarse a si el
        // listado está vacío, con publicaciones o en error.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_root")
        .navigationTitle(Text(Strings.AppBar.title))
        .navigationBarTitleDisplayMode(.inline)
        .background(BocTheme.colors.background)
        // `.task(id:)` cancela la consulta anterior al cambiar de selección, que es justo lo que
        // se quiere, y mantiene la tarea con dueño.
        .task(id: selection) { await viewModel.apply(selection) }
    }
}
