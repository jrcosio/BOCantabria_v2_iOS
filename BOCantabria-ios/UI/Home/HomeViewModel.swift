//
//  HomeViewModel.swift
//  The screen model of the initial screen.
//
//  **No pide publicaciones: las observa.** `refresh` escribe y devuelve un resumen; lo que se
//  pinta llega por el flujo de lo guardado. Es lo que hace que no exista ningún camino por el que
//  un dato recién traído de la red alcance esta pantalla sin pasar por la base.
//

import Foundation
import OSLog
import Synchronization

@MainActor
@Observable
final class HomeViewModel {
    /// El identificador de pantalla que viaja a analítica.
    static let screenName = "home"

    private(set) var state = HomeUiState()

    private let observePublications: ObservePublicationsUseCase
    private let observeHeader: ObserveBulletinHeaderUseCase
    private let refreshPublications: RefreshPublicationsUseCase
    private let analytics: AnalyticsTracker

    /// Las dos observaciones vivas. **Tienen dueño**: se cancelan al cambiar de selección y al
    /// morir el modelo. Una tarea suelta sobreviviría a la pantalla y seguiría observando la base
    /// para escribir en un estado que ya no se ve.
    ///
    /// Viven en una caja `nonisolated` porque el `deinit` de una clase `@MainActor` **no lo es**,
    /// y sin la caja no habría forma de cancelarlas al morir el modelo: solo dejarían de tener a
    /// quién escribir, que no es lo mismo que dejar de observar.
    private let observations = ObservationBox()

    /// Las tres cosas de las que depende qué se pinta. **El contenido se deriva de ellas en un
    /// solo sitio**, y no se escribe desde dos.
    ///
    /// La primera versión lo escribía desde la sincronización y desde la observación, y las dos
    /// llegaban en orden imprevisible: con todas las fuentes caídas, el error se publicaba y la
    /// observación lo pisaba con «no hay nada» un instante después. El escenario de error enseñaba
    /// el estado vacío.
    private var latestItems: [Publication] = []
    private var hasSynced = false
    /// El intervalo que mide SC-001: desde que la pantalla nace hasta que hay publicaciones.
    private var timeToContent: OSSignpostIntervalState?
    private var lastSyncError: DomainError?
    private var isRefreshing = false

    init(
        observePublications: ObservePublicationsUseCase,
        observeHeader: ObserveBulletinHeaderUseCase,
        refreshPublications: RefreshPublicationsUseCase,
        analytics: AnalyticsTracker
    ) {
        self.observePublications = observePublications
        self.observeHeader = observeHeader
        self.refreshPublications = refreshPublications
        self.analytics = analytics
        // Exactamente una vez por instancia, no una por aparición de la vista: la vista aparece
        // otra vez al volver de segundo plano, y eso no es una visita nueva.
        analytics.trackScreenView(Self.screenName)
        state.sectionChips = Self.chips(for: BocSection.topLevel)
        timeToContent = AppSignposts.timeToContent.beginInterval(AppSignposts.timeToContentName)
    }

    deinit {
        observations.cancelAll()
    }

    // MARK: - Entradas

    /// La primera sincronización, si toca. Respeta la ventana de caducidad (FR-023).
    func onAppear() async {
        await sync(force: false)
    }

    /// El gesto de deslizar hacia abajo. **Siempre** sale a la red (FR-024).
    func onRefresh() async {
        await sync(force: true)
    }

    func onRetry() async {
        await sync(force: true)
    }

    /// Aplica una selección y empieza a observarla.
    ///
    /// **No retorna hasta publicar el primer estado**, para que la prueba pueda afirmar en la
    /// línea siguiente.
    func apply(_ selection: HomeSelection) async {
        observations.cancelAll()

        state.selection = selection
        state.subsectionChips = Self.subsectionChips(for: selection)
        analytics.track(.sectionSelected(code: selection.storedCode ?? SectionChip.todayCode))

        // La cabecera se observa por su cuenta: su recuento y su fecha cambian con lo guardado,
        // igual que la lista, pero no al mismo ritmo.
        observations.header = Task { [weak self] in
            guard let stream = self?.observeHeader(selection) else { return }
            for await result in stream {
                guard let self, !Task.isCancelled else { return }
                if case .success(let header) = result { state.header = header }
            }
        }

        var publishedFirst = false
        let stream = observePublications(selection)
        observations.publications = Task { [weak self] in
            for await result in stream {
                guard let self, !Task.isCancelled else { return }
                publish(result)
            }
        }

        // Esperar al primer valor hace afirmable la prueba y evita un fotograma con el estado de
        // la selección anterior.
        for await result in observePublications(selection) {
            publish(result)
            publishedFirst = true
            break
        }
        if !publishedFirst { state.content = hasSynced ? .empty : .skeleton }
    }

    // MARK: - Dentro

    private func sync(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        state.isRefreshing = true
        defer {
            isRefreshing = false
            state.isRefreshing = false
        }

        let result = await refreshPublications(force: force)

        guard !Task.isCancelled else { return }
        hasSynced = true

        switch result {
        case .success(let summary):
            analytics.track(.bulletinSync(summary))
            lastSyncError = nil
            // Sin conexión **con** contenido guardado no es un error: es un resultado correcto que
            // enciende el aviso y deja el contenido donde está (FR-027).
            state.isOffline = summary.allFailed
        case .failure(let error):
            lastSyncError = error
            state.isOffline = error == .network
        }
        renderContent()
    }

    private func publish(_ result: AppResult<[Publication]>) {
        switch result {
        case .success(let items):
            latestItems = items
        case .failure(let error):
            latestItems = []
            lastSyncError = error
        }
        renderContent()
    }

    /// **El único sitio que decide qué se pinta.**
    ///
    /// El orden de las tres preguntas es la política entera: con contenido, se enseña el
    /// contenido —aunque la última sincronización fallara, porque entonces lo que hay es un aviso
    /// y no un error—; sin contenido y con un fallo, el error; y sin ninguna de las dos cosas,
    /// marcadores mientras no se sepa y estado vacío cuando ya se sepa.
    private func renderContent() {
        if !latestItems.isEmpty {
            state.content = .publications(latestItems)
            if let interval = timeToContent {
                AppSignposts.timeToContent.endInterval(AppSignposts.timeToContentName, interval)
                timeToContent = nil
            }
        } else if let lastSyncError {
            state.content = .error(lastSyncError)
        } else {
            state.content = hasSynced ? .empty : .skeleton
        }
    }

    private static func chips(for sections: [BocSection]) -> [SectionChip] {
        [SectionChip(code: SectionChip.todayCode, title: String(localized: Strings.Chip.todaysBulletin))]
            + sections.map { SectionChip(code: $0.code, title: $0.shortName) }
    }

    /// La segunda fila: `Toda la sección` más las subsecciones. **Vacía** con el boletín del día y
    /// con una sección que no las tiene (FR-052).
    private static func subsectionChips(for selection: HomeSelection) -> [SectionChip] {
        guard let code = selection.topLevelCode else { return [] }
        let children = BocSection.children(of: code)
        guard !children.isEmpty else { return [] }
        return [SectionChip(code: code, title: String(localized: Strings.Chip.wholeSection))]
            + children.map { SectionChip(code: $0.code, title: $0.shortName) }
    }
}

/// Caja `nonisolated` para las tareas de observación.
///
/// Existe solo porque el `deinit` de una clase `@MainActor` es `nonisolated` y no puede tocar sus
/// propiedades aisladas. Sin ella, las observaciones sobrevivirían al modelo de pantalla.
private final class ObservationBox: Sendable {
    private let storage = Mutex<(publications: Task<Void, Never>?, header: Task<Void, Never>?)>((nil, nil))

    var publications: Task<Void, Never>? {
        get { storage.withLock { $0.publications } }
        set { storage.withLock { $0.publications = newValue } }
    }

    var header: Task<Void, Never>? {
        get { storage.withLock { $0.header } }
        set { storage.withLock { $0.header = newValue } }
    }

    func cancelAll() {
        storage.withLock { tasks in
            tasks.publications?.cancel()
            tasks.header?.cancel()
            tasks = (nil, nil)
        }
    }
}
