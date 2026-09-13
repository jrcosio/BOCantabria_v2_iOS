//
//  MainViewModelTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: armazón")
@MainActor
struct MainViewModelTests {

    private func makeViewModel(stored: String? = nil) -> (MainViewModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "boc-main-\(UUID().uuidString)")!
        if let stored { defaults.set(stored, forKey: UserDefaultsSelectionStore.key) }
        let viewModel = MainViewModel(
            store: UserDefaultsSelectionStore(defaults: defaults),
            sections: BocSection.all
        )
        return (viewModel, defaults)
    }

    @Test("El panel presenta las nueve secciones en orden, con sus hijas")
    func theDrawerShowsTheNineSections() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.state.sections.count == 9)
        #expect(viewModel.state.sections.map(\.id) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
        #expect(viewModel.state.sections.filter(\.isExpandable).map(\.id) == ["2", "4", "7", "8"])
    }

    @Test("Elegir guarda la selección")
    func selectingStoresIt() {
        let (viewModel, defaults) = makeViewModel()
        viewModel.onSelect(.section(code: "2", subsectionCode: "2.2"))
        #expect(viewModel.state.selection == .section(code: "2", subsectionCode: "2.2"))
        #expect(defaults.string(forKey: UserDefaultsSelectionStore.key) == "2.2")
    }

    @Test("Al nacer restaura lo guardado")
    func itRestoresOnBirth() {
        let (viewModel, _) = makeViewModel(stored: "7.3")
        #expect(viewModel.state.selection == .section(code: "7", subsectionCode: "7.3"))
    }

    @Test("Un valor guardado inválido no tumba nada")
    func anInvalidStoredValueIsHarmless() {
        let (viewModel, _) = makeViewModel(stored: "2.9")
        #expect(viewModel.state.selection == .todaysBulletin)
    }

    @Test("Desplegar y contraer una sección")
    func expandingAndCollapsing() {
        let (viewModel, _) = makeViewModel()
        viewModel.onToggleExpanded("4")
        #expect(viewModel.state.expanded == ["4"])
        viewModel.onToggleExpanded("4")
        #expect(viewModel.state.expanded.isEmpty)
    }

    @Test("Cerrar el panel lo deja contraído para la próxima vez")
    func closingTheDrawerCollapsesEverything() {
        let (viewModel, _) = makeViewModel()
        viewModel.onToggleExpanded("2")
        viewModel.onToggleExpanded("7")
        viewModel.onDrawerClosed()
        #expect(viewModel.state.expanded.isEmpty)
    }

    @Test("La pestaña se restaura por nombre, nunca por índice", arguments: [
        (nil, MainTab.home), ("search", .search), ("saved", .saved),
        ("avisos", .home), ("", .home), ("2", .home),
    ])
    func theTabIsRestoredByName(stored: String?, expected: MainTab) {
        // «Preguntar» fue pestaña y hoy es pantalla: un valor guardado que ya no existe tumbaría
        // la aplicación al volver de la muerte del proceso.
        #expect(MainTab.restored(from: stored) == expected)
    }
}

// MARK: - El armazón no puede fabricar modelos de pantalla al redibujarse

/// **Prueba de regresión de un defecto real, encontrado al inventariar qué toca la feature 005.**
///
/// `MainView` construía el modelo de pantalla de Inicio dentro de una propiedad calculada que el
/// sistema evalúa **en cada redibujado**, y el inicializador de ese modelo registra una visita de
/// pantalla y abre un intervalo de medición. El `@State` de `HomeView` conservaba el primero, así
/// que no se veía en pantalla: se veía en el panel de analítica, con una visita por cada apertura
/// del panel lateral.
///
/// Entra en esta feature porque **esta feature lo empeora**: la pila de navegación del detalle
/// añade estado al armazón, y entonces cada entrada y cada retroceso redibujan y registran
/// (research.md D-523, FR-051).
///
/// Se descubrió **leyendo el fichero**, no por ninguna prueba: ninguna miraba ese lado. Es el mismo
/// patrón por el que se descubrió que faltaba `-ObjC` en el enlazador.
@Suite("Armazón: los modelos de pantalla no nacen al redibujar")
@MainActor
struct MainViewScreenViewRegressionTests {

    @Test("Redibujar el armazón no registra visitas de Inicio que nadie hizo")
    func redrawingTheShellDoesNotRecordPhantomScreenViews() {
        let analytics = RecordingAnalyticsTracker()
        let container = AppContainer(
            telemetry: TelemetryBundle(analytics: analytics, crashReporter: NoOpCrashReporter()),
            clock: ImmediateClock(),
            connectivity: FixedConnectivityDataSource(online: true)
        )

        let view = MainView(container: container)
        // Tres redibujados: abrir el panel, cerrarlo, y cualquier cambio de estado del armazón.
        // `SectionsDrawer` llama a su contenido al evaluar su cuerpo, que es donde vivía el
        // `makeHomeViewModel()`.
        for _ in 0..<3 { _ = view.body.body }

        let deInicio = analytics.screenViews.filter { $0 == HomeViewModel.screenName }
        #expect(
            deInicio.count == 1,
            Comment(rawValue: "Inicio se ha registrado \(deInicio.count) veces. El modelo de "
                + "pantalla nace en el cuerpo del armazón en vez de en su inicializador (FR-051).")
        )
    }
}
