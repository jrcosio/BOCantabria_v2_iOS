//
//  ContentRemoteDataSource.swift
//  The remote source of content.
//
//  **Puede lanzar**: el repositorio es quien captura y traduce. Es la frontera donde los errores
//  del mundo exterior dejan de serlo.
//

protocol ContentRemoteDataSource: Sendable {
    func fetchContentItems() async throws -> [ContentItemDTO]
}

/// Origen en memoria mientras no hay red (research.md D-104).
///
/// Mantiene la latencia porque es lo que hace visible el estado de carga, y la pide al reloj
/// inyectado para que las pruebas no esperen de verdad.
struct StubContentRemoteDataSource: ContentRemoteDataSource {
    /// Qué debe hacer el origen. Los escenarios existen para poder recorrer los cuatro estados de
    /// la pantalla desde una prueba de interfaz, que corre en otro proceso y no puede sustituir
    /// nada por dentro. Ver `LaunchConfiguration`.
    enum Scenario: String, Sendable {
        case items
        case empty
        case failing
        /// Como `items`, pero con una espera larga. Existe para que la prueba de interfaz del
        /// estado de carga no sea una carrera contra el arranque de la aplicación.
        case slow
    }

    struct Unavailable: Error {}

    private let clock: AppClock
    private let latencySeconds: Double
    private let scenario: Scenario

    init(clock: AppClock, latencySeconds: Double = 0.6, scenario: Scenario = .items) {
        self.clock = clock
        self.latencySeconds = latencySeconds
        self.scenario = scenario
    }

    func fetchContentItems() async throws -> [ContentItemDTO] {
        try await clock.sleep(seconds: scenario == .slow ? 20 : latencySeconds)
        switch scenario {
        case .items, .slow:
            return [
                ContentItemDTO(id: "1", label: "Disposiciones generales"),
                ContentItemDTO(id: "2", label: "Autoridades y personal"),
                ContentItemDTO(id: "3", label: "Contratación administrativa"),
            ]
        case .empty:
            return []
        case .failing:
            throw Unavailable()
        }
    }
}
