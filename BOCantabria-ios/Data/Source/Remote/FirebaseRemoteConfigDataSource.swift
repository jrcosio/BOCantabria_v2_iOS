//
//  FirebaseRemoteConfigDataSource.swift
//  The one place in the project that talks to the remote-configuration SDK.
//
//  Es un `actor` porque el cliente del proveedor no es `Sendable` y no puede cruzar fronteras de
//  concurrencia. **Nunca un interceptor de registro a nivel de cuerpo**, y nada de lo que llegue
//  del servicio se escribe en el registro.
//

import FirebaseRemoteConfig
import Foundation

actor FirebaseRemoteConfigDataSource: RemoteConfigDataSource {
    private let client: RemoteConfig

    init() {
        client = RemoteConfig.remoteConfig()
        #if DEBUG
        // En desarrollo se quiere ver al momento lo que se acaba de publicar en la consola. En
        // producción manda el intervalo del proveedor, que es de horas: pedir configuración en
        // cada arranque no aporta nada y gasta batería y datos de quien abre la aplicación.
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        client.configSettings = settings
        #endif
    }

    func fetchValues() async throws -> RemoteConfigValues {
        _ = try await client.fetchAndActivate()
        return RemoteConfigValues(
            minSupportedVersion: client[RemoteConfigKey.minSupportedVersion].stringValue,
            maintenanceMessage: client[RemoteConfigKey.maintenanceMessage].stringValue
        )
    }
}
