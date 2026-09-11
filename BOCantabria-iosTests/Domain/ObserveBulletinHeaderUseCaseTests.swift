//
//  ObserveBulletinHeaderUseCaseTests.swift
//

import Testing
@testable import BOCantabria_ios

@Suite("Observar la cabecera")
struct ObserveBulletinHeaderUseCaseTests {

    @Test("Devuelve la cabecera del repositorio tal cual")
    func forwardsTheHeader() async {
        let expected = BulletinHeader(
            title: "Boletín de hoy",
            date: BocDate(iso: "2026-08-26"),
            count: 48,
            dateMeaning: .edition
        )
        let repository = FakePublicationRepository(header: .success(expected))
        let observe = ObserveBulletinHeaderUseCase(repository: repository)

        var received: BulletinHeader?
        for await result in observe(.todaysBulletin) {
            if case .success(let header) = result { received = header }
        }
        #expect(received == expected)
    }
}
