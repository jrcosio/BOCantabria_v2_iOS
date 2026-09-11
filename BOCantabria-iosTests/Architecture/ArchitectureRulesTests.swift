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
    /// **Mantén esta lista corta: cada entrada es un agujero en SC-002.** Hoy son dos portadores
    /// de datos puros: `ContentItem` son dos cadenas y `DomainError` es un enumerado de dos casos
    /// sin nada que ejecutar. Probarlos sería probar al compilador.
    static let domainTypesWithoutBehaviour: Set<String> = [
        "ContentItem", "DomainError",
        // Tres casos sin comportamiento. Lo único que podría afirmar un fichero propio es
        // que el compilador funciona; su semántica se prueba donde vive, en
        // `PrepareStartupUseCaseTests`. Declarado en el Complexity Tracking de la 002.
        "StartupStatus",
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

    @Test("6 · Solo Data importa los módulos de Firebase")
    func onlyDataImportsFirebase() {
        for file in SourceTree.appFiles where file.layer != .data {
            for module in file.imports where module.hasPrefix("Firebase") {
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
                    "\(type.name) no tiene \(type.name)Tests. Es lo que hace verificable el criterio SC-002."
                )
            }
        }
    }
}
