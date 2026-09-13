//
//  PdfViewerView.swift
//  The viewer screen.
//
//  **La página visible vive en el almacenamiento de escena**, como la pestaña del armazón. FR-034
//  habla de segundo plano y de muerte del proceso, **no de rotación**: la aplicación es solo
//  vertical, así que el caso que en Android era «cambio de configuración» aquí no existe. Lo que sí
//  existe es que el sistema mate el proceso, y eso es lo que el almacenamiento de escena sobrevive
//  y `@State` no (research.md D-515).
//

import SwiftUI

struct PdfViewerView: View {
    @State private var viewModel: PdfViewerViewModel
    /// La clave entra en el nombre para que dos documentos no se pisen la página.
    @SceneStorage("pdf_page") private var storedPage: Int = 0
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PdfViewerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        PdfViewerContentView(
            state: viewModel.state,
            pageIndex: $storedPage,
            onBack: { dismiss() },
            onRetry: { Task { await viewModel.onRetry() } },
            onShare: { Task { await viewModel.onShare() } }
        )
        .toolbar(.hidden, for: .navigationBar)
        // FR-006: el visor no muestra la barra de pestañas de la aplicación.
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.onAppear() }
        .shareSheet(state: viewModel.share, onConsumed: { viewModel.onShareConsumed() })
    }
}
