//
//  BocSectionTests.swift
//
//  El árbol de secciones es un dato que se transcribe del servicio oficial, así que lo que hay
//  que proteger es que **siga siendo esa transcripción** y que nadie se deje una fila.
//

import Testing
@testable import BOCantabria_ios

@Suite("Árbol de secciones del BOC")
struct BocSectionTests {

    @Test("Nueve secciones y catorce subsecciones, veintitrés filas (SC-006)")
    func theTreeHasTwentyThreeRows() {
        #expect(BocSection.all.count == 23)
        #expect(BocSection.topLevel.count == 9)
        #expect(BocSection.all.filter { !$0.isTopLevel }.count == 14)
    }

    @Test("Los códigos no se repiten y cada subsección cuelga de una sección que existe")
    func codesAreUniqueAndParentsExist() {
        #expect(Set(BocSection.all.map(\.code)).count == BocSection.all.count)
        for section in BocSection.all {
            guard let parent = section.parentCode else { continue }
            #expect(BocSection.named(parent) != nil, "\(section.code) cuelga de \(parent), que no existe")
            #expect(BocSection.named(parent)?.isTopLevel == true)
            #expect(section.code.hasPrefix(parent + "."), "\(section.code) no cuelga de \(parent)")
        }
    }

    @Test("Las cuatro secciones sin fuente propia son las que tienen subsecciones")
    func onlyFourSectionsHaveChildren() {
        let withChildren = BocSection.topLevel
            .filter { !BocSection.children(of: $0.code).isEmpty }
            .map(\.code)
        #expect(withChildren == ["2", "4", "7", "8"])
        #expect(BocSection.children(of: "2").map(\.code) == ["2.1", "2.2", "2.3"])
        #expect(BocSection.children(of: "4").map(\.code) == ["4.1", "4.2", "4.3", "4.4"])
        #expect(BocSection.children(of: "7").map(\.code) == ["7.1", "7.2", "7.3", "7.4", "7.5"])
        #expect(BocSection.children(of: "8").map(\.code) == ["8.1", "8.2"])
        // Y las otras cinco no tienen ninguna, que es lo que decide si hay segunda fila de chips.
        for code in ["1", "3", "5", "6", "9"] {
            #expect(BocSection.children(of: code).isEmpty)
        }
    }

    @Test("El orden es el oficial, del uno al nueve")
    func topLevelOrderIsOfficial() {
        #expect(BocSection.topLevel.map(\.code) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    }

    @Test("Cada sección tiene color y ninguna se queda fuera del reparto de cinco (D-326)")
    func everySectionMapsToOneOfFiveGroups() {
        // Nueve secciones sobre cinco grupos. El color agrupa; el texto identifica.
        let expected: [String: SectionColorGroup] = [
            "1": .general, "2": .personnel, "3": .contracting, "4": .economy,
            "5": .announcements, "6": .economy, "7": .announcements, "8": .announcements,
            "9": .general,
        ]
        for section in BocSection.topLevel {
            #expect(section.colorGroup == expected[section.code])
        }
        // Y una subsección hereda el grupo de su madre: son la misma sección para el ojo.
        for section in BocSection.all where !section.isTopLevel {
            let parent = BocSection.named(section.parentCode!)
            #expect(section.colorGroup == parent?.colorGroup)
        }
        #expect(Set(BocSection.all.map(\.colorGroup)).count == 5)
    }

    @Test("Nombre corto y nombre oficial: ninguno vacío, y el corto cabe en un chip")
    func namesAreUsable() {
        for section in BocSection.all {
            #expect(!section.name.isEmpty)
            #expect(!section.shortName.isEmpty)
            #expect(section.shortName.count <= 20, "«\(section.shortName)» no cabe en un chip")
        }
    }
}
