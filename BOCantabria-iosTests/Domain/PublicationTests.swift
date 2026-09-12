//
//  PublicationTests.swift
//
//  Los invariantes de la publicación no los impone el tipo —los impone el normalizador, que es
//  quien puede rechazar—, así que lo que se comprueba aquí es que **lo que se construye los
//  cumple** y que tener advertencias no es romper ninguno.
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Publicación")
struct PublicationTests {

    @Test("Una publicación normalizada cumple sus cuatro invariantes")
    func aNormalisedPublicationHoldsItsInvariants() {
        let publication = publication()
        #expect(!publication.externalKey.isEmpty)
        #expect(!publication.title.isEmpty)
        #expect(publication.documentUrl.scheme == "https")
        let pathIsClean = publication.organizationPath.allSatisfy { !$0.isEmpty }
        #expect(pathIsClean)
    }

    @Test("Tener advertencias NO es romper un invariante")
    func warningsAreNotAnInvariantViolation() {
        // FR-015: el desorden de categorías del feed 4.3 se anota y **no descarta** la publicación.
        let anomalous = publication(warnings: [.categoryOrderUnreliable, .categoryDoesNotMatchFeed])
        #expect(anomalous.warnings.count == 2)
        #expect(!anomalous.title.isEmpty)
        #expect(anomalous.documentUrl.scheme == "https")
    }

    @Test("La identidad es la clave externa, no el título")
    func identityIsTheExternalKey() {
        // Los títulos se repiten entre ayuntamientos: identificar por título sería duplicar o
        // fundir publicaciones distintas.
        let one = publication(externalKey: "boc:1", title: "Aprobación definitiva del presupuesto")
        let other = publication(externalKey: "boc:2", title: "Aprobación definitiva del presupuesto")
        #expect(one.id != other.id)
        #expect(Set([one, other]).count == 2)
    }

    @Test("El código más específico es la subsección cuando la hay, y la sección cuando no")
    func mostSpecificCodePrefersTheSubsection() {
        #expect(publication(sectionCode: "2", subsectionCode: "2.2").mostSpecificSectionCode == "2.2")
        #expect(publication(sectionCode: "1", subsectionCode: nil).mostSpecificSectionCode == "1")
    }

    // MARK: - El organismo, que el BOC publica dos veces

    @Test("El título pierde el prefijo cuando repite exactamente el organismo")
    func theTitleDropsARedundantIssuerPrefix() {
        // Es el caso real y el más frecuente: el organismo llega por la ruta de clasificación y
        // otra vez al principio del título, en mayúsculas.
        let subject = publication(
            title: "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva del presupuesto"
        )
        #expect(subject.titleWithoutIssuer == "Aprobación definitiva del presupuesto")
        // Y lo almacenado no cambia: compartir y buscar siguen viendo el título entero.
        #expect(subject.title == "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva del presupuesto")
    }

    @Test("Un prefijo que solo se parece al organismo NO se recorta")
    func aMerelySimilarPrefixSurvives() {
        // «FRATERNIDAD MUPRESPA MATEPSS Nº 275» no es «Fraternidad Muprespa». Recortar por
        // parecido mutilaría títulos oficiales; ante la duda, el título entero.
        let subject = publication(
            title: "AYUNTAMIENTO DE PIÉLAGOS Y COMARCA: Aprobación definitiva"
        )
        #expect(subject.titleWithoutIssuer == subject.title)
    }

    @Test("Un título sin dos puntos se queda como está")
    func aTitleWithoutAColonIsUntouched() {
        let subject = publication(title: "Aprobación definitiva del presupuesto")
        #expect(subject.titleWithoutIssuer == subject.title)
    }

    @Test("Un título que solo es el organismo conserva el título entero")
    func aTitleThatIsOnlyTheIssuerKeepsIt() {
        // Recortarlo dejaría la tarjeta sin título, que es peor que repetir el organismo.
        let subject = publication(title: "Ayuntamiento de Piélagos:")
        #expect(subject.titleWithoutIssuer == "Ayuntamiento de Piélagos:")
    }

    @Test("Sin organismo no hay nada que recortar")
    func withoutAnIssuerNothingIsTrimmed() {
        let subject = Publication(
            externalKey: "boc:1", blobId: "1", idSource: .blobId, feedId: "6802081",
            sectionCode: "1", subsectionCode: nil,
            title: "ALGO: Aprobación definitiva", issuer: nil, organizationPath: [],
            editionType: .ordinary, publicationDate: BocDate(iso: "2026-08-26")!,
            documentUrl: URL(string: "https://boc.cantabria.es/x")!,
            rawCategories: "", warnings: []
        )
        #expect(subject.titleWithoutIssuer == "ALGO: Aprobación definitiva")
    }

    private func publication(
        externalKey: String = "boc:439765",
        title: String = "AYUNTAMIENTO DE PIÉLAGOS: Aprobación definitiva",
        sectionCode: String = "1",
        subsectionCode: String? = nil,
        warnings: Set<ParserWarning> = []
    ) -> Publication {
        Publication(
            externalKey: externalKey,
            blobId: "439765",
            idSource: .blobId,
            feedId: "6802081",
            sectionCode: sectionCode,
            subsectionCode: subsectionCode,
            title: title,
            issuer: "Ayuntamiento de Piélagos",
            organizationPath: ["Ayuntamiento de Piélagos"],
            editionType: .ordinary,
            publicationDate: BocDate(iso: "2026-08-26")!,
            documentUrl: URL(string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=439765")!,
            rawCategories: "1.Disposiciones Generales|Ayuntamiento de Piélagos|ORD",
            warnings: warnings
        )
    }
}
