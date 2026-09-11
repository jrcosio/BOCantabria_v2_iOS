//
//  PublicationQueriesTests.swift
//
//  Las consultas son donde vive el significado de «boletín del día» y de «sección», y las dos
//  cosas se pueden escribir mal sin que nada falle: simplemente saldrían otras publicaciones.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Consultas del boletín")
struct PublicationQueriesTests {

    private func sourceWithSample() -> PublicationLocalDataSource {
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let source = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        _ = source.store(
            [
                // Sección 1, la fecha más reciente
                publication(externalKey: "boc:100", sectionCode: "1", date: "2026-08-27"),
                // Sección 2.2, misma fecha: el boletín del día es de TODAS las secciones
                publication(externalKey: "boc:101", sectionCode: "2", subsectionCode: "2.2",
                            date: "2026-08-27"),
                // Sección 2.1, fecha anterior
                publication(externalKey: "boc:102", sectionCode: "2", subsectionCode: "2.1",
                            date: "2026-08-20"),
                // Sección 1, mucho más antigua
                publication(externalKey: "boc:103", sectionCode: "1", date: "2021-03-26"),
            ],
            bodyHash: "a", feedId: "6802081", at: .now
        )
        return source
    }

    @Test("El boletín del día es la fecha máxima, de todas las secciones (FR-037)")
    func todaysBulletinIsTheLatestDateAcrossEverySection() {
        let keys = sourceWithSample().publications(for: .todaysBulletin).map(\.externalKey)
        #expect(keys == ["boc:101", "boc:100"])
    }

    @Test("Una sección principal recoge también a sus subsecciones")
    func aTopLevelSectionIncludesItsChildren() {
        // Las secciones 2, 4, 7 y 8 no tienen fuente propia: su contenido es la unión del de sus
        // subsecciones. Filtrar por igualdad con el código más específico las dejaría vacías.
        let keys = sourceWithSample()
            .publications(for: .section(code: "2", subsectionCode: nil))
            .map(\.externalKey)
        #expect(Set(keys) == ["boc:101", "boc:102"])
    }

    @Test("Una subsección no recoge a su hermana")
    func aSubsectionDoesNotIncludeItsSibling() {
        let keys = sourceWithSample()
            .publications(for: .section(code: "2", subsectionCode: "2.2"))
            .map(\.externalKey)
        #expect(keys == ["boc:101"])
    }

    @Test("Una sección NO se limita a una fecha (FR-038)")
    func aSectionIsNotRestrictedToOneDate() {
        // Es la diferencia con el boletín del día, y la razón de que el rótulo de la cabecera sea
        // otro: una sección puede no haber publicado desde 2021.
        let keys = sourceWithSample()
            .publications(for: .section(code: "1", subsectionCode: nil))
            .map(\.externalKey)
        #expect(keys == ["boc:100", "boc:103"])
    }

    @Test("El orden es fecha descendente, y el desempate es determinista (FR-028)")
    func theOrderIsStableAndDeterministic() {
        // Sin el tercer criterio, dos ejecuciones pueden dar órdenes distintos porque las fuentes
        // responden en orden distinto. Y eso se ve: la lista cambia sola al refrescar.
        let provider = BocDatabaseProvider.inMemory(crashReporter: NoOpCrashReporter())
        _ = provider.database()
        let source = PublicationLocalDataSource(
            provider: provider, crashReporter: NoOpCrashReporter()
        )
        _ = source.store(
            [
                publication(externalKey: "boc:1", date: "2026-08-26"),
                publication(externalKey: "boc:3", date: "2026-08-26"),
                publication(externalKey: "boc:2", date: "2026-08-26"),
            ],
            bodyHash: "a", feedId: "6802081", at: .now
        )
        let first = source.publications(for: .todaysBulletin).map(\.externalKey)
        let second = source.publications(for: .todaysBulletin).map(\.externalKey)
        #expect(first == second)
        #expect(first == ["boc:3", "boc:2", "boc:1"])
    }

    @Test("Una selección sin publicaciones devuelve una lista vacía, no un error")
    func anEmptySelectionIsEmptyNotAnError() {
        // Es la 8.1: responde bien y no trae nada.
        let empty = sourceWithSample().publications(for: .section(code: "8", subsectionCode: "8.1"))
        #expect(empty.isEmpty)
    }
}
