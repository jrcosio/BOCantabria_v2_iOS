//
//  ConnectivityRepositoryImplTests.swift
//  The repository hands through what the device says, and nothing more.
//

import Testing

@testable import BOCantabria_ios

@Suite("Repositorio de conectividad")
struct ConnectivityRepositoryImplTests {

    @Test("Traslada lo que dice el dispositivo, sin interpretarlo")
    func passesThroughWhatTheDeviceSays() async {
        // No interpreta a propósito: este valor solo elige el mensaje de error, y prometer más
        // —«hay internet»— sería escribir en el contrato una garantía que el monitor del sistema
        // no da (research.md D-205).
        let online = ConnectivityRepositoryImpl(dataSource: FakeConnectivityDataSource(online: true))
        let offline = ConnectivityRepositoryImpl(dataSource: FakeConnectivityDataSource(online: false))
        #expect(await online.isOnline())
        #expect(await offline.isOnline() == false)
    }
}
