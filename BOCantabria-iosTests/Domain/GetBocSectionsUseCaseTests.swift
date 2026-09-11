//
//  GetBocSectionsUseCaseTests.swift
//

import Testing
@testable import BOCantabria_ios

@Suite("Obtener las secciones")
struct GetBocSectionsUseCaseTests {

    @Test("Devuelve el árbol completo, veintitrés filas")
    func returnsTheWholeTree() {
        let sections = GetBocSectionsUseCase(repository: BocSectionRepositoryImpl())()
        #expect(sections.count == 23)
        #expect(sections.first?.code == "1")
    }
}
