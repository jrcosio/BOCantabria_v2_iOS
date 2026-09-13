//
//  ScenarioDatabaseSeeder.swift
//  The seam the UI tests use, and nothing more.
//
//  **Sustituye a la costura de la feature 001, no la amplía.** Aquélla escribió que
//  `-boc-content-scenario=` «se sustituye cuando la feature del boletín traiga el origen real»:
//  ésta es esa feature, aquel argumento ha desaparecido y en su lugar queda éste. Siguen siendo
//  dos argumentos, los mismos que había.
//
//  **Las publicaciones se sintetizan en código, no se leen de las muestras XML.** No es una
//  preferencia: las muestras viajan **solo en el bundle de pruebas**, y esto es código de la
//  aplicación, que corre en otro proceso y no las ve. Las dos salidas eran embarcar muestras de
//  prueba en el binario que se publica —justo lo que la promesa de costura acotada evita— o
//  construirlas aquí. La consecuencia se acepta: el analizador **no** queda ejercitado desde la
//  prueba de interfaz, sino desde sus pruebas unitarias, que es donde tiene que estar.
//
//  Los escenarios se nombran por **el desenlace que la pantalla tiene que pintar**, no por un
//  detalle del transporte. Es lo que los hace sustituibles cuando el mecanismo cambie.
//

import Foundation

enum DataScenario: String, Sendable, CaseIterable {
    /// Contenido guardado y nada que traer.
    case today
    /// Todo responde y no hay publicaciones. Es la 8.1.
    case empty
    /// Ninguna fuente responde y no hay nada guardado.
    case failing
    /// Ninguna fuente responde **pero** hay contenido guardado.
    case offline
    /// Las fuentes tardan. Sirve para ver el estado de carga sin correr contra el arranque.
    case slow
    /// Sin escenario: la aplicación de verdad.
    case live

    // Los cuatro del documento. **Los cuatro siembran contenido y sus fuentes responden**: lo que
    // cambia es qué devuelve el enlace del documento.
    /// Un documento válido de una página.
    case documentReady
    /// Código 200 cuyo contenido no es el documento.
    case documentRejected
    /// Un cuerpo que pasa del tope.
    case documentTooLarge
    /// La descarga falla por red y no hay copia.
    case documentUnavailable

    var seedsContent: Bool {
        self == .today || self == .offline || documentOutcome != nil
    }

    var networkFails: Bool { self == .failing || self == .offline }

    /// Qué devuelve el enlace del documento, o `nil` si este escenario no habla de documentos.
    ///
    /// **Este enumerado pasa a llevar dos ejes** —el del boletín y el del documento— y se dice en
    /// voz alta. Con cuatro casos es aceptable; si algún día apareciera un tercer eje, hay que
    /// partirlo (research.md D-524).
    /// Dónde guarda sus documentos este escenario, o `nil` para el directorio de producción.
    ///
    /// **Uno por escenario**, para que una prueba no herede la caché de la anterior.
    var documentCacheDirectory: URL? {
        guard documentOutcome != nil else { return nil }
        let caches = (try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )) ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("documents-\(rawValue)", isDirectory: true)
    }

    var documentOutcome: DocumentOutcome? {
        switch self {
        case .documentReady: .ready
        case .documentRejected: .rejected
        case .documentTooLarge: .tooLarge
        case .documentUnavailable: .unavailable
        default: nil
        }
    }
}

enum ScenarioDatabaseSeeder {
    /// Diez publicaciones deterministas, repartidas entre secciones y fechas, con una anomalía
    /// incluida para que el estado con contenido no sea sospechosamente limpio.
    static func seed(_ local: PublicationLocalDataSource, at instant: Date) {
        _ = local.store(
            sample(), bodyHash: "scenario", feedId: "6802081", at: instant
        )
    }

    static func sample() -> [Publication] {
        [
            make(id: 500_001, section: "1", subsection: nil, date: "2026-08-27",
                 issuer: "Ayuntamiento de Santander",
                 title: "AYUNTAMIENTO DE SANTANDER: Aprobación definitiva de la Ordenanza Fiscal reguladora del Impuesto sobre Bienes Inmuebles."),
            make(id: 500_002, section: "1", subsection: nil, date: "2026-08-27",
                 issuer: "Ayuntamiento de Torrelavega",
                 title: "AYUNTAMIENTO DE TORRELAVEGA: Aprobación inicial del Presupuesto General para el ejercicio 2027."),
            make(id: 500_003, section: "2", subsection: "2.2", date: "2026-08-27",
                 issuer: "Consejería de Salud",
                 title: "CONSEJERÍA DE SALUD: Convocatoria de concurso-oposición para el acceso a plazas de Enfermería."),
            make(id: 500_004, section: "2", subsection: "2.1", date: "2026-08-26",
                 issuer: "Ayuntamiento de Camargo",
                 title: "AYUNTAMIENTO DE CAMARGO: Nombramiento de funcionario de carrera del Cuerpo de Policía Local."),
            make(id: 500_005, section: "3", subsection: nil, date: "2026-08-26",
                 issuer: "Consejería de Fomento",
                 title: "CONSEJERÍA DE FOMENTO: Licitación del contrato de conservación de carreteras autonómicas."),
            make(id: 500_006, section: "6", subsection: nil, date: "2026-08-25",
                 issuer: "Consejería de Educación",
                 title: "CONSEJERÍA DE EDUCACIÓN: Convocatoria de subvenciones para actividades extraescolares."),
            make(id: 500_007, section: "7", subsection: "7.1", date: "2026-08-24",
                 issuer: "Ayuntamiento de Piélagos",
                 title: "AYUNTAMIENTO DE PIÉLAGOS: Información pública de la modificación puntual del Plan General de Ordenación Urbana."),
            make(id: 500_008, section: "7", subsection: "7.2", date: "2026-08-21",
                 issuer: "Consejería de Medio Ambiente",
                 title: "CONSEJERÍA DE MEDIO AMBIENTE: Información pública del expediente de autorización ambiental integrada."),
            make(id: 500_009, section: "9", subsection: nil, date: "2024-06-20",
                 issuer: "Junta Electoral de Cantabria",
                 title: "JUNTA ELECTORAL DE CANTABRIA: Proclamación de candidaturas."),
            // Con una advertencia, para que el estado con contenido no sea más limpio que la vida.
            make(id: 500_010, section: "4", subsection: "4.3", date: "2021-03-26",
                 issuer: "Fraternidad Muprespa",
                 title: "FRATERNIDAD MUPRESPA MATEPSS Nº 275: Citación para notificación de expediente.",
                 warnings: [.categoryOrderUnreliable]),
        ]
    }

    private static func make(
        id: Int,
        section: String,
        subsection: String?,
        date: String,
        issuer: String,
        title: String,
        warnings: Set<ParserWarning> = []
    ) -> Publication {
        Publication(
            externalKey: "boc:\(id)",
            blobId: String(id),
            idSource: .blobId,
            feedId: "6802081",
            sectionCode: section,
            subsectionCode: subsection,
            title: title,
            issuer: issuer,
            organizationPath: [issuer],
            editionType: .ordinary,
            publicationDate: BocDate(iso: date)!,
            documentUrl: URL(
                string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=\(id)"
            )!,
            rawCategories: nil,
            warnings: warnings
        )
    }
}

/// Descargador de escenario: responde lo que el desenlace pide, sin tocar la red.
struct ScenarioFeedDownloader: FeedDownloader {
    let scenario: DataScenario
    let clock: AppClock

    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult {
        if scenario == .slow {
            // Una latencia que se nota, para poder ver el estado de carga. Subir el tiempo de
            // espera de la prueba no arreglaría nada: el problema es el contrario, que la
            // aplicación tarda más en lanzarse de lo que tardaba el origen.
            try? await clock.sleep(seconds: 3)
        }
        if scenario.networkFails { return .failed(.offline) }
        return .notModified
    }
}
