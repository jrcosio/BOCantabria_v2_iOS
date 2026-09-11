//
//  AppInfoTests.swift
//  Reading the installed version, including when it cannot be read.
//

import Testing

@testable import BOCantabria_ios

@Suite("Información del paquete")
struct AppInfoTests {

    @Test("Lee la versión del paquete de la aplicación")
    func readsTheApplicationVersion() {
        // El proceso de pruebas unitarias lo hospeda la aplicación, así que el paquete principal
        // es el suyo y lleva su MARKETING_VERSION.
        #expect(AppInfo.installedVersion != nil)
    }

    @Test("Una versión ausente o ilegible es nulo, nunca un cero que bloquearía")
    func unreadableVersionIsNilAndNotZero() {
        // Es la trampa: cero es **menor** que cualquier mínimo publicado, así que un respaldo a
        // cero haría que la aplicación se bloqueara a sí misma en el único caso en que no puede
        // saber su propia versión.
        #expect(AppInfo.version(from: nil) == nil)
        #expect(AppInfo.version(from: "") == nil)
        #expect(AppInfo.version(from: "no-es-una-versión") == nil)
        #expect(AppInfo.version(from: "1.2.3") == AppVersion(major: 1, minor: 2, patch: 3))
    }
}
