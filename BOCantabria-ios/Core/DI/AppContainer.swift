//
//  AppContainer.swift
//  The composition root: the whole dependency graph, declared in one place.
//
//  Todo se recibe **por inicializador** y detrás de un protocolo. La consecuencia es la garantía
//  que el proyecto Android tenía que comprobar en ejecución: aquí **un cableado incompleto no
//  compila**. La prueba que construye este contenedor cubre lo que el compilador no ve —que se
//  construye sin efectos de arranque y que los ámbitos son los previstos—.
//
//  **Este fichero no importa ningún SDK de terceros**, y no es casualidad: la decisión de qué
//  telemetría se usa la toma `TelemetryBundle`, en la capa de datos.
//

import Foundation

@MainActor
final class AppContainer {
    private let telemetry: TelemetryBundle
    private let clock: AppClock

    /// Compartidos en todo el proceso: el origen local es una caché y tener dos sería tener dos
    /// verdades.
    private let localDataSource: ContentLocalDataSource
    private let remoteDataSource: ContentRemoteDataSource
    private let contentRepository: ContentRepository

    init(
        telemetry: TelemetryBundle,
        clock: AppClock = SystemClock(),
        contentScenario: StubContentRemoteDataSource.Scenario = .items
    ) {
        self.telemetry = telemetry
        self.clock = clock
        self.localDataSource = InMemoryContentLocalDataSource()
        self.remoteDataSource = StubContentRemoteDataSource(clock: clock, scenario: contentScenario)
        self.contentRepository = ContentRepositoryImpl(
            remote: remoteDataSource,
            local: localDataSource
        )
    }

    /// Nuevo en cada llamada: un modelo de pantalla tiene el ciclo de vida de su pantalla.
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getContentItems: GetContentItemsUseCase(repository: contentRepository),
            analytics: telemetry.analytics
        )
    }
}
