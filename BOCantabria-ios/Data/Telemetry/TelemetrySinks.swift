//
//  TelemetrySinks.swift
//  The seam between our wrappers and the provider's SDK.
//
//  Existe por la misma razón por la que el proyecto Android inyectaba el cliente de Firebase en su
//  envoltorio: **para poder afirmar exactamente qué nombre y qué parámetros se envían sin invocar
//  el servicio** (FR-027). Sin esta costura, lo único comprobable sería que el envoltorio no se
//  cae, que no es lo que hay que proteger de regresiones.
//

import Foundation

/// Lo mínimo que el envoltorio necesita del proveedor de analítica.
protocol AnalyticsSink: Sendable {
    func logEvent(_ name: String, parameters: [String: String]) throws
}

/// Lo mínimo que el envoltorio necesita del proveedor de informes de fallo.
protocol CrashSink: Sendable {
    func record(_ error: Error) throws
    func log(_ message: String) throws
}
