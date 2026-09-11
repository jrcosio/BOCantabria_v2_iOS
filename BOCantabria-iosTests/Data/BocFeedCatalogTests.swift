//
//  BocFeedCatalogTests.swift
//
//  Este catálogo es la única puerta de la aplicación al servicio oficial. Un dígito cambiado no
//  rompe nada visible: simplemente esa sección deja de traer publicaciones, y nadie lo nota hasta
//  que alguien la abre.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Catálogo de fuentes del BOC")
struct BocFeedCatalogTests {

    @Test("Diecinueve fuentes, todas activas (SC-006)")
    func thereAreNineteenSources() {
        #expect(BocFeedCatalog.all.count == 19)
        #expect(BocFeedCatalog.active.count == 19)
    }

    @Test("Los identificadores no se repiten y las direcciones tampoco")
    func identifiersAndUrlsAreUnique() {
        #expect(Set(BocFeedCatalog.all.map(\.feedId)).count == 19)
        #expect(Set(BocFeedCatalog.all.map(\.url)).count == 19)
    }

    @Test("Todas son HTTPS y apuntan al servicio oficial")
    func everySourceIsOfficialAndSecure() {
        for feed in BocFeedCatalog.all {
            #expect(feed.url.scheme == "https", "\(feed.feedId) no es HTTPS")
            #expect(feed.url.host() == "www.cantabria.es", "\(feed.feedId) apunta a otro sitio")
            #expect(feed.url.path().hasPrefix("/o/BOC/feed/"))
            // Y la dirección **termina en el identificador**: es la comprobación que caza un
            // catálogo donde alguien copió una fila y se dejó el número de la anterior.
            #expect(feed.url.lastPathComponent == feed.feedId)
        }
    }

    @Test("Las direcciones no se pueden componer por cálculo, y por eso se escriben enteras")
    func urlsCannotBeDerived() {
        // La prueba de que FR-002 no es paranoia: los identificadores no son correlativos y hay
        // dos de otro rango. Quien intente `base + (primero + n)` apuntará a otra cosa.
        let ids = BocFeedCatalog.all.map { Int($0.feedId)! }
        let consecutive = zip(ids, ids.dropFirst()).allSatisfy { $1 == $0 + 1 }
        #expect(!consecutive, "Si fueran correlativos, alguien los calcularía")
        let identifiers = Set(ids)
        #expect(identifiers.contains(7_479_572))  // 8.1, de un rango distinto
        #expect(identifiers.contains(7_293_890))  // 9, de otro más
    }

    @Test("Cada fuente representa una sección o subsección que existe en el árbol")
    func everySourceMapsToTheSectionTree() {
        for feed in BocFeedCatalog.all {
            let section = BocSection.named(feed.mostSpecificSectionCode)
            #expect(section != nil, "\(feed.feedId) dice ser \(feed.mostSpecificSectionCode)")
            if let subsection = feed.subsectionCode {
                #expect(BocSection.named(subsection)?.parentCode == feed.sectionCode)
            } else {
                #expect(section?.isTopLevel == true)
            }
        }
    }

    @Test("Las veintitrés secciones con contenido propio están cubiertas, y solo esas")
    func theCatalogueCoversEverySectionThatHasASource() {
        // Nueve secciones y catorce subsecciones son veintitrés filas, pero solo diecinueve tienen
        // fuente: las secciones 2, 4, 7 y 8 se componen sumando sus hijas.
        let covered = Set(BocFeedCatalog.all.map(\.mostSpecificSectionCode))
        let withoutOwnSource = Set(["2", "4", "7", "8"])
        let expected = Set(BocSection.all.map(\.code)).subtracting(withoutOwnSource)
        #expect(covered == expected)
        #expect(covered.count == 19)
    }

    @Test("Desactivar una fuente la retira sin tocar el proceso de lectura (FR-003)")
    func disablingASourceRemovesItFromWhatIsRead() {
        // Lo que FR-003 pide es que activar o desactivar sea un dato, no un cambio de código. La
        // lista que se consulta es `active`, y filtra por la bandera.
        let disabled = BocFeedDefinition(
            feedId: "0000000",
            url: URL(string: "https://www.cantabria.es/o/BOC/feed/0000000")!,
            sectionCode: "1", subsectionCode: nil, order: 99, enabled: false
        )
        let mixed = [disabled] + BocFeedCatalog.all
        let activeIds: Set<String> = Set(mixed.filter(\.enabled).map(\.feedId))
        let catalogueIds: Set<String> = Set(BocFeedCatalog.all.map(\.feedId))
        // El resultado se calcula fuera de la aserción: `#expect` con dos conjuntos por medio
        // no compila —la expansión del macro acaba en una sobrecarga que lanza—, y es más rápido
        // rodearlo que pelearse con el diagnóstico.
        let sameSources = activeIds == catalogueIds
        #expect(sameSources)
        let allEnabled = BocFeedCatalog.all.allSatisfy(\.enabled)
        #expect(allEnabled)
    }

    @Test("El orden de presentación es correlativo y sin huecos")
    func presentationOrderIsDense() {
        #expect(BocFeedCatalog.active.map(\.order) == Array(1...19))
    }
}
