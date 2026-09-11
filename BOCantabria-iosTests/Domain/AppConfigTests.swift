//
//  AppConfigTests.swift
//  The normalisation that stops anyone having to check two things.
//

import Testing

@testable import BOCantabria_ios

@Suite("Configuración de la aplicación")
struct AppConfigTests {

    @Test("Un mensaje de mantenimiento vacío o en blanco es «sin mantenimiento»")
    func emptyMaintenanceMessageBecomesNil() {
        for text in ["", "   ", "\n", "\t  \n"] {
            let config = AppConfig(minSupportedVersion: .zero, maintenanceMessage: text)
            #expect(config.maintenanceMessage == nil, "«\(text.debugDescription)» no es un aviso.")
        }
        #expect(AppConfig(minSupportedVersion: .zero, maintenanceMessage: nil)
            .maintenanceMessage == nil)
    }

    @Test("Un mensaje real se conserva, sin los espacios de los bordes")
    func realMaintenanceMessageSurvives() {
        let config = AppConfig(
            minSupportedVersion: .zero,
            maintenanceMessage: "  Volvemos a las 18:00.  "
        )
        #expect(config.maintenanceMessage == "Volvemos a las 18:00.")
    }

    @Test("El valor por defecto no bloquea a nadie")
    func defaultBlocksNobody() {
        // FR-014 y SC-006. Es «todo permitido», y es la única declaración de ese valor.
        #expect(AppConfig.default.minSupportedVersion == .zero)
        #expect(AppConfig.default.maintenanceMessage == nil)
    }
}
