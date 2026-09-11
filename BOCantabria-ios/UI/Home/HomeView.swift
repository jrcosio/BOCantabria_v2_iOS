//
//  HomeView.swift
//  The initial screen.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        HomeContentView(state: viewModel.state) {
            // Sin `Task` suelta: la cancelación la gobierna la vista. Una tarea sin dueño
            // sobrevive a la pantalla y escribe en un estado que ya no se ve.
            Task { await viewModel.onRetry() }
        }
        .navigationTitle(Text(Strings.Home.title))
        .navigationBarTitleDisplayMode(.inline)
        .background(BocTheme.colors.background)
        .task { await viewModel.onAppear() }
    }
}
