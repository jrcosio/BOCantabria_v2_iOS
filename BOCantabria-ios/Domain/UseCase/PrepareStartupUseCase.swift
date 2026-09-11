//
//  PrepareStartupUseCase.swift
//  Runs the three startup checks and decides which one wins.
//
//  **Aquí vive la política del arranque**, y por eso es Swift puro y se prueba sin levantar una
//  pantalla: qué se comprueba, en qué orden y qué manda cuando fallan dos cosas a la vez. Si esto
//  lo orquestara el modelo de pantalla, la regla de precedencia viviría en presentación, donde no
//  se puede probar sola (research.md D-204).
//
//  **No impone el tiempo mínimo en pantalla**: eso es una decisión de presentación. Un caso de uso
//  que durmiera un segundo sería un caso de uso imposible de reutilizar.
//

struct PrepareStartupUseCase: Sendable {
    private let appConfig: AppConfigRepository
    private let connectivity: ConnectivityRepository
    private let storage: StoragePreparing
    private let installedVersion: AppVersion?

    init(
        appConfig: AppConfigRepository,
        connectivity: ConnectivityRepository,
        storage: StoragePreparing,
        installedVersion: AppVersion?
    ) {
        self.appConfig = appConfig
        self.connectivity = connectivity
        self.storage = storage
        self.installedVersion = installedVersion
    }

    /// **Nunca lanza.** La tabla completa está en `data-model.md` y cada fila tiene su prueba.
    func callAsFunction() async -> AppResult<StartupStatus> {
        // **El almacén, primero.** Si no se puede abrir o migrar, no hay aplicación que enseñar:
        // lo guardado es la procedencia de todo lo que la pantalla muestra. Falla aquí, con
        // mensaje y reintento, en vez de con Inicio ya pintado (research.md D-305).
        if case .failure = await storage.prepare() { return .failure(.storage) }

        switch await appConfig.loadConfig() {
        case let .failure(error):
            return .failure(error)

        case let .success(config):
            // **La falta de conexión manda, y se comprueba DESPUÉS de pedir la configuración, no
            // antes.** No se cortocircuita —eso haría que el resultado dependiera de un monitor
            // que puede ir por detrás de la red real—, pero el cliente del proveedor puede
            // entregar valores **de su caché** estando sin conexión, y esos valores no dicen lo que
            // hay publicado hoy. Bloquear a alguien por una versión mínima de hace una semana,
            // sin forma de comprobarla, es exactamente lo que FR-016 impide.
            guard await connectivity.isOnline() else { return .failure(.network) }

            if let installedVersion, installedVersion < config.minSupportedVersion {
                // Manda sobre el mantenimiento: de nada sirve informar de una incidencia temporal
                // a quien no va a poder usar la aplicación de todos modos.
                return .success(.updateRequired)
            }

            if let message = config.maintenanceMessage {
                return .success(.maintenance(message))
            }

            return .success(.ready)
        }
    }
}
