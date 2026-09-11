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
    var onSelect: (HomeSelection) -> Void = { _ in }
    var onOpenSections: () -> Void = {}

    init(
        viewModel: HomeViewModel,
        selection: HomeSelection = .todaysBulletin,
        onSelect: @escaping (HomeSelection) -> Void = { _ in },
        onOpenSections: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.selection = selection
        self.onSelect = onSelect
        self.onOpenSections = onOpenSections
    }

    /// Lo que todavía no existe **lo dice**, en vez de no responder (FR-073, FR-076).
    @State private var comingSoon: String?

    var body: some View {
        HomeContentView(
            state: viewModel.state,
            onRefresh: { await viewModel.onRefresh() },
            // Sin `Task` suelta: la cancelación la gobierna la vista. Una tarea sin dueño
            // sobrevive a la pantalla y escribe en un estado que ya no se ve.
            onRetry: { Task { await viewModel.onRetry() } },
            onSelect: { chip in onSelect(Self.selection(for: chip)) },
            onOpenSections: onOpenSections,
            onSearch: { comingSoon = String(localized: Strings.Nav.search) },
            onSave: { _ in comingSoon = String(localized: Strings.Card.save) }
        )
        .alert(
            Text(Strings.Common.comingSoon),
            isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })
        ) {
            Button("OK") { comingSoon = nil }
        } message: {
            if let comingSoon { Text(comingSoon) }
        }
        // Marca la pantalla entera, **en cualquiera de sus estados**. Es lo que permite que las
        // pruebas del arranque afirmen «se llegó al contenido principal» sin atarse a si el
        // listado está vacío, con publicaciones o en error.
        //
        // **`.contain` no es opcional aquí.** Sin él, un identificador puesto sobre un contenedor
        // se propaga a **todos** sus descendientes y les machaca el suyo: el volcado del árbol
        // mostraba `home_menu`, `home_search` y `home_info` convertidos los tres en `home_root`.
        // Y la otra mitad, que también costó: **no se anidan dos contenedores declarados**, porque
        // entonces el de dentro desaparece.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_root")
        // `.task(id:)` cancela la consulta anterior al cambiar de selección, que es justo lo que
        // se quiere, y mantiene la tarea con dueño.
        .task(id: selection) { await viewModel.apply(selection) }
        .task { await viewModel.onAppear() }
    }

    /// Tocar un chip de sección con subsecciones hace **las dos cosas a la vez**: la lista pasa a
    /// la sección completa y la segunda fila se despliega. El caso común es querer ver la sección;
    /// afinar es la excepción, y cobrar dos toques por el caso común sería el reparto equivocado.
    static func selection(for chip: SectionChip) -> HomeSelection {
        guard chip.code != SectionChip.todayCode else { return .todaysBulletin }
        guard let section = BocSection.named(chip.code) else { return .todaysBulletin }
        if let parent = section.parentCode {
            return .section(code: parent, subsectionCode: section.code)
        }
        return .section(code: section.code, subsectionCode: nil)
    }
}
