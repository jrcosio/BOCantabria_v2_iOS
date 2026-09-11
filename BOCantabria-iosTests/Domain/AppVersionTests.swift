//
//  AppVersionTests.swift
//  The version comparison, which is the defence against locking everyone out.
//

import Testing

@testable import BOCantabria_ios

@Suite("Versión de la aplicación")
struct AppVersionTests {

    @Test("Acepta las tres formas que publica una tienda")
    func parsesTheThreeValidForms() {
        #expect(AppVersion("1") == AppVersion(major: 1, minor: 0, patch: 0))
        #expect(AppVersion("1.2") == AppVersion(major: 1, minor: 2, patch: 0))
        #expect(AppVersion("1.2.3") == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(AppVersion(" 1.2.3 ") == AppVersion(major: 1, minor: 2, patch: 3))
    }

    @Test("Un valor que no se entiende es nulo, nunca un cero silencioso")
    func returnsNilForAnythingElse() {
        // FR-015: esa nulidad es la que la capa de datos traduce en «no bloquea». Si aquí se
        // devolviera `.zero` en vez de nulo, un valor ilegible y un «todo permitido» serían
        // indistinguibles y nadie podría probar la diferencia.
        for text in ["", "   ", "latest", "1.2.x", "-1.0.0", "1.-2.0", "1.2.3.4", "v1.0.0",
                     "1..0", "1.0.0-beta", "+1"] {
            #expect(AppVersion(text) == nil, "«\(text)» no es una versión y no debe parsearse.")
        }
    }

    @Test("El orden es el de la terna, no el de la cadena")
    func ordersByComponentsAndNotAlphabetically() {
        // Es donde falla comparar cadenas: «1.10.0» < «1.9.0» como texto, y es al revés.
        #expect(AppVersion("1.9.0")! < AppVersion("1.10.0")!)
        #expect(AppVersion("1.0.0")! < AppVersion("2.0.0")!)
        #expect(AppVersion("1.0.0")! < AppVersion("1.0.1")!)
        #expect(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
        #expect(AppVersion("1.0.0")! == AppVersion("1.0")!)
    }

    @Test("El cero no es mayor que ninguna versión real")
    func zeroNeverBlocks() {
        // SC-006: es lo que garantiza que el valor por defecto no deje fuera a la primera versión
        // publicada.
        for text in ["0.0.1", "1.0.0", "1.0", "99.99.99"] {
            #expect(AppVersion.zero <= AppVersion(text)!)
        }
    }
}
