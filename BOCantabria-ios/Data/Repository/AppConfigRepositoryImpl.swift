//
//  AppConfigRepositoryImpl.swift
//  Translates what the service publishes into what the domain understands.
//
//  La política entera está en `contracts/internal-contracts.md` §2 y **cada fila tiene su prueba**.
//  Ningún error escapa de aquí, y todo camino de fallo deja constancia del motivo (FR-018): la
//  pantalla no dice códigos a propósito, así que el registro es el único sitio donde se distingue
//  qué pasó.
//

import Foundation

struct AppConfigRepositoryImpl: AppConfigRepository {
    private let remote: RemoteConfigDataSource
    private let connectivity: ConnectivityRepository
    private let crashReporter: CrashReporter

    init(
        remote: RemoteConfigDataSource,
        connectivity: ConnectivityRepository,
        crashReporter: CrashReporter
    ) {
        self.remote = remote
        self.connectivity = connectivity
        self.crashReporter = crashReporter
    }

    func loadConfig() async -> AppResult<AppConfig> {
        do {
            let values = try await remote.fetchValues()
            return .success(translate(values))
        } catch {
            // **La cancelación no se trata aquí, igual que en `ContentRepositoryImpl`.** Esta
            // función no lanza, así que lo correcto es que quien espera el resultado compruebe
            // `Task.isCancelled` antes de publicar nada; lo hace `SplashViewModel`. Tratarla aquí
            // obligaría a inventar un caso de `DomainError` para algo que nadie ha sufrido.
            // `.network` o `.unknown` según haya camino de red, y es lo único para lo que la
            // conectividad se consulta: elige el mensaje, no el comportamiento.
            let online = await connectivity.isOnline()
            crashReporter.log(
                "startup: remote config fetch failed (online: \(online), error: \(type(of: error)))"
            )
            return .failure(online ? .unknown : .network)
        }
    }

    /// Traducción real, no una copia: el servicio devuelve cadena vacía para lo que no está
    /// publicado, y el dominio quiere un valor por defecto y un opcional.
    private func translate(_ values: RemoteConfigValues) -> AppConfig {
        let minimum = AppVersion(values.minSupportedVersion)
        if minimum == nil, !values.minSupportedVersion.trimmingCharacters(in: .whitespaces).isEmpty {
            // FR-015: un valor ilegible **no bloquea**, pero sí se cuenta. Es el fallo más caro
            // posible de esta feature —dejar fuera a todo el mundo por una errata en la consola— y
            // sin esta línea sería invisible.
            crashReporter.log("startup: unreadable minimum version, falling back to zero")
        }
        return AppConfig(
            minSupportedVersion: minimum ?? AppConfig.default.minSupportedVersion,
            maintenanceMessage: values.maintenanceMessage
        )
    }
}
