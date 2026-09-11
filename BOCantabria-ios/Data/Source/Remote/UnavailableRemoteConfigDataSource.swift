//
//  UnavailableRemoteConfigDataSource.swift
//  The configuration source for a machine without the provider's configuration file.
//
//  Devuelve vacío y **no lanza**, que es lo que hace que el arranque termine en «se puede
//  continuar» y no en la pantalla de error. Es la misma promesa que la telemetría de no operación
//  de la feature 001: sin secretos, la aplicación se construye, arranca y pasa las pruebas
//  (SC-010). Si esto fallara, la pantalla de error sería lo normal en desarrollo, que es la forma
//  más rápida de que una pantalla de error deje de mirarse.
//

struct UnavailableRemoteConfigDataSource: RemoteConfigDataSource {
    func fetchValues() async throws -> RemoteConfigValues { .empty }
}
