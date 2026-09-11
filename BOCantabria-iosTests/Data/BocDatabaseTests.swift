//
//  BocDatabaseTests.swift
//
//  La base en memoria **ignora el modo de diario**, así que esa comprobación va sobre un fichero
//  temporal real. Es inocuo para los invariantes que se prueban aquí —upsert, lista blanca,
//  ausencia de borrados— y no lo es para nada que dependa de durabilidad; queda escrito para que
//  nadie deduzca una cobertura que no hay.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Base de datos del boletín")
struct BocDatabaseTests {

    private func makeSource(tracing: Bool = false) -> PublicationLocalDataSource {
        let provider = BocDatabaseProvider.inMemory(
            crashReporter: NoOpCrashReporter(), tracingStatements: tracing
        )
        _ = provider.database()
        return PublicationLocalDataSource(provider: provider, crashReporter: NoOpCrashReporter())
    }

    @Test("La migración v1 deja las dos tablas listas")
    func theFirstMigrationCreatesEverything() {
        let source = makeSource()
        #expect(!source.hasAnyPublication())
        #expect(source.lastSuccess() == nil)
        #expect(source.knownBodyHash(feedId: "6802081") == nil)
    }

    @Test("Un fichero real se abre en WAL")
    func aRealFileUsesWriteAheadLogging() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("boc-test-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: url) }

        let database = try BocDatabase.open(at: url)
        #expect(try database.journalMode().lowercased() == "wal")
    }

    @Test("Una publicación conocida se actualiza, no se duplica (FR-020)")
    func aKnownPublicationIsUpdatedNotDuplicated() {
        let source = makeSource()
        let original = publication(title: "Título original")
        let updated = publication(title: "Título corregido")

        _ = source.store([original], bodyHash: "a", feedId: "6802081", at: .now)
        let second = source.store([updated], bodyHash: "b", feedId: "6802081", at: .now)

        #expect(second.inserted == 0)
        #expect(second.updated == 1)
        let stored = source.publications(for: .todaysBulletin)
        #expect(stored.count == 1)
        #expect(stored.first?.title == "Título corregido")
    }

    @Test("`first_seen_at` no se mueve al actualizar; `last_seen_at` sí")
    func firstSeenAtIsNeverTouchedAgain() {
        // Es la lista blanca de columnas en acción. `first_seen_at` no está en el UPDATE, así que
        // no depende de que nadie se acuerde de protegerla.
        let source = makeSource(tracing: true)
        let first = Date(timeIntervalSince1970: 1_000_000)
        let later = Date(timeIntervalSince1970: 2_000_000)

        _ = source.store([publication()], bodyHash: "a", feedId: "6802081", at: first)
        _ = source.store([publication(title: "Otro")], bodyHash: "b", feedId: "6802081", at: later)

        let updates = source.executedStatements.filter { $0.uppercased().contains("UPDATE PUBLICATIONS") }
        #expect(!updates.isEmpty)
        let mentionsFirstSeen = updates.contains { $0.contains("first_seen_at") }
        #expect(!mentionsFirstSeen, "El UPDATE es una lista blanca y first_seen_at no está en ella")
    }

    @Test("La huella del cuerpo se guarda y se recupera (FR-022)")
    func theBodyHashIsRemembered() {
        let source = makeSource()
        _ = source.store([publication()], bodyHash: "huella", feedId: "6802081", at: .now)
        #expect(source.knownBodyHash(feedId: "6802081") == "huella")
        #expect(source.knownBodyHash(feedId: "6802085") == nil)
    }

    @Test("Un fallo no borra la huella conocida ni la marca de éxito")
    func aFailureKeepsWhatWasKnown() {
        let source = makeSource()
        let success = Date(timeIntervalSince1970: 1_000_000)
        _ = source.store([publication()], bodyHash: "huella", feedId: "6802081", at: success)

        source.recordFailure(feedId: "6802081")

        #expect(source.knownBodyHash(feedId: "6802081") == "huella")
        #expect(source.lastSuccess() == success)
    }

    @Test("La marca de última sincronización es la más reciente de todas las fuentes")
    func theLastSuccessIsTheMostRecentOne() {
        let source = makeSource()
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        _ = source.store([], bodyHash: "a", feedId: "6802081", at: older)
        _ = source.store([], bodyHash: "b", feedId: "6802085", at: newer)
        #expect(source.lastSuccess() == newer)
    }
}
