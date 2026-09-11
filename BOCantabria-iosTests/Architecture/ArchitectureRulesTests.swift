//
//  ArchitectureRulesTests.swift
//  The rules that fail the build when someone breaks the architecture.
//
//  Son el mecanismo que hace verificable el criterio SC-004: el **100 %** de las violaciones se
//  detectan automáticamente antes de llegar a un dispositivo. Sin ellas, la separación de capas y
//  la coherencia visual son un acuerdo de caballeros que dura hasta el primer día con prisa.
//
//  Ocupan el sitio que en el proyecto Android ocupaba Konsist (research.md D-102). Nueve reglas:
//  las seis que tuvo su feature 001, con la primera partida en dos porque en Swift las
//  importaciones no bastan —ver la cabecera de `SourceTree`—, más las dos que protegen el aspecto,
//  que aquí entra en esta feature.
//

import Testing

@Suite("Reglas de arquitectura")
struct ArchitectureRulesTests {

    /// Lo que nunca puede entrar en el dominio. Se comprueba por prefijo, así que `Firebase` cubre
    /// `FirebaseAnalytics`, `FirebaseCrashlytics` y cualquier otro módulo de la familia.
    static let forbiddenInDomain = ["SwiftUI", "UIKit", "GRDB", "Firebase", "PDFKit"]

    /// Tipos de dominio sin comportamiento que proteger, exentos de la regla del fichero de
    /// prueba.
    ///
    /// **Mantén esta lista corta: cada entrada es un agujero en SC-012**, el criterio que dice que
    /// toda pieza de reglas de negocio y todo modelo de pantalla tiene su prueba. (En la feature
    /// 001 ese criterio se numeraba SC-002; el número es de cada feature, el compromiso es el
    /// mismo.)
    ///
    /// Los cuatro enumerados del boletín entraron aquí **en frío**, al planificar, y no cuando la
    /// build estuviera roja y hubiera prisa: son vocabularios cerrados sin comportamiento y su
    /// semántica se prueba donde vive, en `PublicationNormalizerTests` y en `BocSectionTests`.
    /// `Publication`, `BocDate`, `BocSection`, `HomeSelection` y `SyncSummary` **no** se eximieron:
    /// los cinco tienen comportamiento de verdad.
    static let domainTypesWithoutBehaviour: Set<String> = [
        "ContentItem", "DomainError",
        // Tres casos sin comportamiento. Lo único que podría afirmar un fichero propio es
        // que el compilador funciona; su semántica se prueba donde vive, en
        // `PrepareStartupUseCaseTests`. Declarado en el Complexity Tracking de la 002.
        "StartupStatus",
        // Los cuatro del boletín (research.md D-325).
        "EditionType", "IdSource", "ParserWarning", "SectionColorGroup",
    ]

    // MARK: - Regla de capas

    @Test("1 · Domain no importa marcos de plataforma ni SDK de proveedores")
    func domainImportsNothingFromThePlatform() {
        for file in SourceTree.files(in: .domain) {
            for module in file.imports {
                let offender = Self.forbiddenInDomain.first { module.hasPrefix($0) }
                #expect(
                    offender == nil,
                    "\(file.path) importa «\(module)». El dominio es Swift puro: no puede depender de la plataforma ni de un proveedor."
                )
            }
        }
    }

    @Test("2 · Domain no nombra ningún tipo de Data ni de UI")
    func domainReferencesNoOuterLayer() {
        let outerTypes = SourceTree.declaredTypes(in: .data) + SourceTree.declaredTypes(in: .ui)
        for file in SourceTree.files(in: .domain) {
            for type in outerTypes where file.references(type) {
                Issue.record(
                    "\(file.path) nombra «\(type)», que vive fuera del dominio. Las dependencias apuntan siempre hacia dentro."
                )
            }
        }
    }

    @Test("3 · UI no nombra ningún tipo de Data")
    func uiReferencesNoData() {
        for file in SourceTree.files(in: .ui) {
            for type in SourceTree.declaredTypes(in: .data) where file.references(type) {
                Issue.record(
                    "\(file.path) nombra «\(type)», que es de la capa de datos. La presentación solo habla con casos de uso."
                )
            }
        }
    }

    // MARK: - Ubicación y forma

    @Test("4 · Los casos de uso viven en Domain/UseCase")
    func useCasesLiveInTheirPackage() {
        for file in SourceTree.appFiles {
            for type in file.topLevelTypes where type.name.hasSuffix("UseCase") {
                #expect(
                    file.path.hasPrefix("Domain/UseCase/"),
                    "\(type.name) está en \(file.path). Los casos de uso viven en Domain/UseCase."
                )
            }
        }
    }

    @Test("5 · Los modelos de pantalla viven en UI y son @MainActor @Observable")
    func viewModelsLiveInUIAndAreObservable() {
        for file in SourceTree.appFiles {
            for type in file.topLevelTypes where type.name.hasSuffix("ViewModel") {
                #expect(
                    file.layer == .ui,
                    "\(type.name) está en \(file.path). Los modelos de pantalla viven en UI."
                )
                #expect(
                    type.attributes.contains("@MainActor"),
                    "\(type.name) no está marcado @MainActor."
                )
                #expect(
                    type.attributes.contains("@Observable"),
                    "\(type.name) no está marcado @Observable. El principio III lo exige."
                )
            }
        }
    }

    // MARK: - Proveedores

    @Test("6 · Solo Data importa los módulos de proveedores: Firebase y GRDB")
    func onlyDataImportsFirebase() {
        // GRDB entra aquí con la feature del boletín: es el segundo proveedor con SDK propio, y
        // la razón de encerrarlo es la misma que con Firebase.
        let providerModules = ["Firebase", "GRDB"]
        for file in SourceTree.appFiles where file.layer != .data {
            for module in file.imports where providerModules.contains(where: module.hasPrefix) {
                Issue.record(
                    "\(file.path) importa «\(module)». Los SDK del proveedor solo se tocan desde Data, detrás de AnalyticsTracker y CrashReporter."
                )
            }
        }
    }

    // MARK: - Aspecto

    @Test("7 · Solo el tema construye colores")
    func onlyTheThemeDeclaresColours() {
        // Se comprueba la **construcción** de un color, no cualquier mención: una regla que grita
        // lobo es una regla que la gente aprende a esquivar.
        for file in SourceTree.appFiles where !file.path.hasPrefix("Core/UI/Theme/") {
            for pattern in ["Color(", "UIColor("] where file.code.contains(pattern) {
                Issue.record(
                    "\(file.path) construye un color con «\(pattern)». Los colores solo se declaran en Core/UI/Theme; en el punto de uso se consumen de BocTheme.colors."
                )
            }
        }
    }

    @Test("8 · Nada hace depender la apariencia del tema del sistema")
    func nothingDependsOnTheSystemAppearance() {
        // La aplicación tiene una apariencia única (FR-015). Estas son las puertas por las que el
        // ajuste del dispositivo podría entrar.
        let gateways = ["colorScheme", "userInterfaceStyle", "preferredColorScheme"]
        for file in SourceTree.appFiles {
            for gateway in gateways where file.code.containsIdentifier(gateway) {
                Issue.record(
                    "\(file.path) usa «\(gateway)». La apariencia es única y no responde al ajuste claro/oscuro del dispositivo."
                )
            }
        }
    }

    // MARK: - Persistencia y tiempo

    @Test("10 · Nadie fuera de Data/Source/Local nombra un tipo de GRDB")
    func onlyTheLocalSourceNamesGRDBTypes() {
        // **Lo que esta regla añade a la 6, comprobado provocando las dos violaciones.** La 6
        // para en la capa: permite GRDB en cualquier punto de `Data`. Ésta lo encierra en la
        // carpeta donde vive la base, que es lo que impide que un repositorio o el coordinador de
        // sincronización acaben hablando SQL.
        //
        // Y una corrección al razonamiento con el que se propuso: **no** es cierto que dentro de
        // un módulo Swift baste un `import` en un fichero para nombrar el tipo en los demás. Eso
        // vale para los tipos declarados en el propio módulo —que es lo que cazan las reglas 2 y
        // 3— pero no para un módulo externo: sin `import GRDB` en el fichero, `DatabaseQueue` ni
        // siquiera compila. Se comprobó intentándolo.
        let grdbTypes = [
            "DatabaseQueue", "DatabasePool", "DatabaseWriter", "DatabaseReader",
            "Database", "ValueObservation", "DatabaseMigrator", "Row",
        ]
        let allowed = "Data/Source/Local/"
        for file in SourceTree.appFiles where !file.path.hasPrefix(allowed) {
            for type in grdbTypes where file.references(type) {
                Issue.record(
                    "\(file.path) nombra «\(type)», que es de GRDB. La persistencia vive encerrada en \(allowed)."
                )
            }
        }
    }

    @Test("11 · Nadie construye el reloj, el idioma ni el calendario del dispositivo")
    func nobodyReachesForTheDeviceClockOrLocale() {
        // La constitución exige pruebas «sin reloj del sistema», y hasta esta feature **nada lo
        // comprobaba**. Un `Date()` en un repositorio hace intermitente una prueba de caducidad y
        // nadie se entera hasta que falla en otra máquina.
        //
        // Son las cuatro puertas por las que el dispositivo se cuela en un resultado: la hora, el
        // idioma, el calendario y la zona. Todas viven encerradas en `Core/Util`, que es donde se
        // inyectan.
        let gateways = ["Date()", "Locale.current", "Calendar.current", "TimeZone.current", "DateFormatter("]
        let allowed = "Core/Util/"
        for file in SourceTree.appFiles where !file.path.hasPrefix(allowed) {
            for gateway in gateways where file.code.contains(gateway) {
                Issue.record(
                    "\(file.path) usa «\(gateway)». El tiempo y el idioma se inyectan; su sitio es \(allowed)."
                )
            }
        }
    }

    @Test("12 · Ninguna tarea se desprende de su padre")
    func nobodyDetachesATask() {
        // `Task.detached` pierde la prioridad, los valores de tarea y la cancelación estructurada.
        // Es lo que se escribe cuando lo correcto es `@concurrent`, que sí salta al pool sin
        // romper el árbol de tareas.
        for file in SourceTree.appFiles where file.code.contains("Task.detached") {
            Issue.record(
                "\(file.path) usa «Task.detached». Para salir del actor principal, `@concurrent`; para vivir más que su llamante, un actor que la posea."
            )
        }
    }

    @Test("13 · Ninguna consulta declara un borrado sobre las publicaciones")
    func noQueryDeletesAPublication() {
        // Se mira `rawCode`, **con las cadenas dentro**: una sentencia SQL es una cadena, así que
        // sobre `code` esta regla no vería nada y pasaría siempre (research.md D-323).
        //
        // Y es la capa barata, no la garantía: GRDB también borra con métodos de registro, sin
        // que la palabra aparezca en ninguna cadena. Lo que de verdad lo demuestra es
        // `NoDeleteRegressionTests`, que recoge las sentencias que se ejecutan.
        for file in SourceTree.appFiles where file.rawCode.contains("publications") {
            let sql = file.rawCode.uppercased()
            if sql.contains("DELETE FROM PUBLICATIONS") || sql.contains("DELETEALL") {
                Issue.record(
                    "\(file.path) borra publicaciones. Nunca se borra una publicación guardada: una fuente solo publica sus últimos cien anuncios."
                )
            }
        }
    }

    // MARK: - Cobertura

    @Test("9 · Todo tipo de dominio y todo modelo de pantalla tiene fichero de prueba")
    func everyDomainTypeAndViewModelHasATestFile() {
        let testFiles = SourceTree.testFileNames
        for file in SourceTree.appFiles {
            for type in file.topLevelTypes {
                // Los protocolos quedan fuera por principio, no por indulgencia: un contrato no
                // tiene implementación que probar. Lo que se prueba es quien lo implementa.
                let isDomain = file.layer == .domain
                    && type.kind != "protocol"
                    && !Self.domainTypesWithoutBehaviour.contains(type.name)
                let isViewModel = type.name.hasSuffix("ViewModel")
                guard isDomain || isViewModel else { continue }
                #expect(
                    testFiles.contains("\(type.name)Tests"),
                    "\(type.name) no tiene \(type.name)Tests. Es lo que hace verificable el criterio SC-012."
                )
            }
        }
    }
}
