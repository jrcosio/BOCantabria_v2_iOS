//
//  BocSectionRepositoryImplTests.swift
//

import Testing
@testable import BOCantabria_ios

@Suite("Repositorio de secciones")
struct BocSectionRepositoryImplTests {

    @Test("Devuelve el árbol completo y siempre el mismo")
    func returnsTheWholeTree() {
        let repository = BocSectionRepositoryImpl()
        #expect(repository.sections().count == 23)
        #expect(repository.sections() == BocSection.all)
    }
}
