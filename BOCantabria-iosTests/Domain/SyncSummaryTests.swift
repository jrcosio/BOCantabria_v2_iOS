//
//  SyncSummaryTests.swift
//
//  Las dos derivadas son las que la pantalla consulta para decidir entre contenido, aviso de
//  falta de conexión y mensaje de error. Por eso este tipo no es exento de la regla 9.
//

import Testing
@testable import BOCantabria_ios

@Suite("Resumen de sincronización")
struct SyncSummaryTests {

    @Test("Todas las fuentes fallan: ninguna respondió y ninguna estaba sin cambios")
    func allFailedMeansNobodyAnswered() {
        #expect(SyncSummary(failedFeeds: 19).allFailed)
        #expect(!SyncSummary(succeededFeeds: 1, failedFeeds: 18).allFailed)
        // Una fuente sin cambios **sí** respondió: su huella coincidía. No es un fallo.
        #expect(!SyncSummary(unchangedFeeds: 19).allFailed)
    }

    @Test("Un resumen vacío no es «todas fallaron»: es que no se llegó a pedir nada")
    func anEmptySummaryIsNotAFailure() {
        // Es lo que devuelve `refresh(force: false)` con la caché fresca. Decir que todo falló
        // encendería el aviso de falta de conexión sin haber tocado la red.
        #expect(!SyncSummary.skipped.allFailed)
        #expect(SyncSummary.skipped.isComplete)
    }

    @Test("Está completa cuando ninguna fuente falló, aunque alguna no trajera novedades")
    func completeMeansNobodyFailed() {
        #expect(SyncSummary(succeededFeeds: 19).isComplete)
        #expect(SyncSummary(succeededFeeds: 11, unchangedFeeds: 8).isComplete)
        #expect(!SyncSummary(succeededFeeds: 18, failedFeeds: 1).isComplete)
    }
}
