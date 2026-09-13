//
//  PublicationDetailView.swift
//  The detail screen.
//

import SwiftUI

struct PublicationDetailView: View {
    @State private var viewModel: PublicationDetailViewModel
    /// La pestaña sobrevive al segundo plano y a la muerte del proceso, y se restaura **por nombre
    /// y con respaldo**: `"ask"` fue pestaña y hoy es pantalla (FR-017).
    @SceneStorage("detail_tab") private var storedTab: String = DetailTab.document.rawValue
    @State private var comingSoon: String?

    var onOpenDocument: () -> Void = {}
    var onAsk: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: PublicationDetailViewModel,
        onOpenDocument: @escaping () -> Void = {},
        onAsk: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenDocument = onOpenDocument
        self.onAsk = onAsk
    }

    var body: some View {
        PublicationDetailContentView(
            state: viewModel.state,
            onBack: { dismiss() },
            // Guardar todavía anuncia que llegará (FR-045), igual que en la tarjeta.
            onSave: { comingSoon = String(localized: Strings.Card.save) },
            onShare: { Task { await viewModel.onShare() } },
            onSelectTab: {
                storedTab = $0.rawValue
                viewModel.onSelectTab($0)
            },
            onDocumentTabShown: { Task { await viewModel.onDocumentTabShown() } },
            onRetryDocument: { Task { await viewModel.onRetryDocument() } },
            onOpenDocument: onOpenDocument,
            onAsk: onAsk
        )
        .toolbar(.hidden, for: .navigationBar)
        // FR-006: el detalle tiene su propia barra de acciones.
        .toolbar(.hidden, for: .tabBar)
        .alert(
            Text(Strings.Common.comingSoon),
            isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })
        ) {
            Button("OK") { comingSoon = nil }
        } message: {
            if let comingSoon { Text(comingSoon) }
        }
        .task {
            viewModel.onSelectTab(DetailTab.restored(from: storedTab))
            await viewModel.onAppear()
        }
        .shareSheet(state: viewModel.state.share, onConsumed: { viewModel.onShareConsumed() })
    }
}
