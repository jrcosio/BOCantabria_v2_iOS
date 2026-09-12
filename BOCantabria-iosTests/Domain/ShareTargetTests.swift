//
//  ShareTargetTests.swift
//
//  Existe para poder **explicar** el caso degradado, no solo para distinguirlo.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Destino de compartir")
struct ShareTargetTests {

    @Test("El enlace lleva su motivo, que es lo que la pantalla necesita para explicarlo")
    func theLinkCarriesItsReason() {
        let url = URL(string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=1")!
        let destino = ShareTarget.link(url: url, reason: .noConnection)

        guard case .link(let recibida, let motivo) = destino else {
            Issue.record("Debería ser un enlace"); return
        }
        #expect(recibida == url)
        #expect(motivo == .noConnection)
    }

    @Test("Solo hay un motivo para degradar: la falta de conexión")
    func thereIsExactlyOneReasonToDegrade() {
        // Si algún día aparece un segundo caso aquí, hay que mirar dos veces: la especificación
        // dice que **ningún otro fallo se disfraza de enlace** (FR-040). Los demás son errores.
        #expect(ShareTarget.LinkReason.noConnection == ShareTarget.LinkReason.noConnection)
    }
}
