//
//  SourceTree.swift
//  Reads the project's source files so the architecture rules can assert on them.
//
//  **Por qué análisis de texto y no de sintaxis** (research.md D-102): las reglas que este
//  proyecto necesita son léxicas —qué importa un fichero, dónde vive y qué tipos declara—, y un
//  analizador de sintaxis añadiría una dependencia en el camino crítico de la puerta de calidad a
//  cambio de precisión que no se usa. Se dice en voz alta que es una herramienta más pobre: por
//  eso la lista de reglas es corta y este lector tiene sus propias pruebas.
//
//  **Cómo encuentra el árbol**: con `#filePath`, que el compilador sustituye por la ruta absoluta
//  de este fichero. El proceso de pruebas del simulador lee el sistema de ficheros del anfitrión.
//  Verificado con una sonda antes de escribir esto, no supuesto.
//
//  **La diferencia con Kotlin que obliga a mirar referencias y no solo importaciones.** En Kotlin
//  cruzar de paquete exige un `import`, así que comprobar la lista de importaciones basta para
//  hacer cumplir la regla de capas. En Swift, dentro de un mismo módulo **no hace falta importar
//  nada**: un fichero de `Domain` puede nombrar un tipo de `Data` sin que aparezca una sola línea
//  de `import`. Por eso aquí hay dos comprobaciones distintas: las importaciones cazan los marcos
//  y los SDK, y las **referencias a tipos** cazan los cruces entre capas. Traducir la regla de
//  Konsist tal cual habría dado una regla que no protege nada.
//

import Foundation

/// Una capa del proyecto, deducida de la primera carpeta del fichero.
enum Layer: String, CaseIterable, Sendable {
    case core = "Core"
    case domain = "Domain"
    case data = "Data"
    case ui = "UI"
    /// Ficheros sueltos en la raíz del target, como el punto de entrada.
    case root = "."
}

/// Un tipo declarado al nivel superior de un fichero.
///
/// Solo interesan los de nivel superior: los casos anidados de un enumerado pertenecen al fichero
/// de su padre y no tienen comportamiento propio que proteger.
struct TypeDeclaration: Equatable, Sendable {
    let name: String
    let kind: String
    /// Los atributos que preceden a la declaración, como `@MainActor` o `@Observable`.
    let attributes: [String]
}

struct SourceFile: Sendable {
    /// Ruta relativa a la carpeta de fuentes, por ejemplo `Domain/Model/ContentItem.swift`.
    let path: String
    let layer: Layer
    let imports: [String]
    let topLevelTypes: [TypeDeclaration]
    /// El contenido **sin comentarios y sin el contenido de las cadenas**, que es sobre lo que se
    /// comprueban las referencias. Sin esto, un comentario que nombra un tipo de otra capa
    /// dispararía la regla, y la primera reacción de cualquiera sería dejar de escribir
    /// comentarios.
    let code: String

    /// El contenido **sin comentarios pero CON las cadenas**.
    ///
    /// Hace falta porque una sentencia SQL **es una cadena**: una regla que buscara un borrado
    /// sobre `code` no vería absolutamente nada y pasaría siempre. Es exactamente el fallo que
    /// este proyecto ya cometió al traducir la regla de capas de Konsist, y por el que añadió la
    /// comprobación por referencias (research.md D-323).
    ///
    /// Los comentarios se siguen retirando en las dos vistas: `rawCode` **se añade**, no
    /// sustituye. Cada regla elige cuál mira, y la elección tiene consecuencias.
    let rawCode: String

    /// ¿Este fichero nombra ese tipo en su código?
    func references(_ typeName: String) -> Bool {
        code.containsIdentifier(typeName)
    }
}

enum SourceTree {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Architecture
        .deletingLastPathComponent()   // BOCantabria-iosTests
        .deletingLastPathComponent()   // raíz del repositorio

    static let appSourcesRoot = repositoryRoot.appendingPathComponent("BOCantabria-ios")
    static let testSourcesRoot = repositoryRoot.appendingPathComponent("BOCantabria-iosTests")

    /// Todos los ficheros Swift del target de la aplicación.
    static let appFiles: [SourceFile] = swiftFiles(under: appSourcesRoot)

    /// Los nombres de fichero de las pruebas, sin extensión. La convención es `<Tipo>Tests`.
    static let testFileNames: Set<String> = Set(
        allSwiftPaths(under: testSourcesRoot).map {
            $0.deletingPathExtension().lastPathComponent
        }
    )

    static func files(in layer: Layer) -> [SourceFile] {
        appFiles.filter { $0.layer == layer }
    }

    /// Los tipos declarados en una capa. Es lo que permite comprobar las referencias cruzadas.
    static func declaredTypes(in layer: Layer) -> [String] {
        files(in: layer).flatMap { $0.topLevelTypes.map(\.name) }
    }

    // MARK: - Lectura

    private static func allSwiftPaths(under root: URL) -> [URL] {
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return walker
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    private static func swiftFiles(under root: URL) -> [SourceFile] {
        allSwiftPaths(under: root).compactMap { url in
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let code = raw.strippingCommentsAndStrings()
            return SourceFile(
                path: relative,
                layer: layer(ofRelativePath: relative),
                imports: importedModules(in: code),
                topLevelTypes: topLevelTypes(in: code),
                code: code,
                rawCode: raw.strippingComments()
            )
        }
    }

    private static func layer(ofRelativePath path: String) -> Layer {
        let first = path.split(separator: "/").first.map(String.init) ?? ""
        return Layer(rawValue: first) ?? .root
    }

    private static func importedModules(in code: String) -> [String] {
        code.split(separator: "\n").compactMap { line in
            guard let match = line.firstMatch(of: /^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)/)
            else { return nil }
            return String(match.1)
        }
    }

    /// Una declaración es de nivel superior cuando **empieza en la columna cero**. Los atributos
    /// pueden ir en sus propias líneas justo encima, también en la columna cero, y se recogen.
    ///
    /// No es privada a propósito: `SourceTreeTests` la ejercita con fragmentos escritos a mano,
    /// que es la única forma de comprobar que distingue lo anidado de lo que no lo está.
    static func topLevelTypes(in code: String) -> [TypeDeclaration] {
        var declarations: [TypeDeclaration] = []
        var pendingAttributes: [String] = []

        for line in code.split(separator: "\n", omittingEmptySubsequences: false) {
            // Una línea sangrada no puede declarar nada de nivel superior, y tampoco arrastra
            // atributos pendientes.
            guard let first = line.first, !first.isWhitespace else {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty { pendingAttributes = [] }
                continue
            }

            if let match = line.firstMatch(of: /^(@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s*$/) {
                pendingAttributes.append(String(match.1))
                continue
            }

            let inlineAttributes = line
                .matches(of: /@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?/)
                .map { String($0.output) }

            if let match = line.firstMatch(
                of: /^(?:(?:public|internal|private|fileprivate|open|final|indirect|@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s+)*(struct|class|enum|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)/
            ) {
                declarations.append(
                    TypeDeclaration(
                        name: String(match.2),
                        kind: String(match.1),
                        attributes: pendingAttributes + inlineAttributes
                    )
                )
            }
            pendingAttributes = []
        }
        return declarations
    }
}

// MARK: - Ayudas de texto

extension String {
    /// Quita comentarios y el contenido de las cadenas literales.
    ///
    /// Las cadenas se vacían por la misma razón que se quitan los comentarios: un mensaje de
    /// registro que mencione un tipo de otra capa no es una dependencia. Y se procesan juntos
    /// porque hay que saber si un `//` está dentro de una cadena antes de decidir que abre un
    /// comentario.
    /// Retira los comentarios y **conserva** el contenido de las cadenas.
    func strippingComments() -> String {
        stripping(strings: false)
    }

    func strippingCommentsAndStrings() -> String {
        stripping(strings: true)
    }

    private func stripping(strings stripStrings: Bool) -> String {
        var result = ""
        var index = startIndex
        var inLineComment = false
        var blockDepth = 0
        var inString = false
        // Cuando no se retiran, el contenido de la cadena se copia tal cual.
        let blankStrings = stripStrings

        while index < endIndex {
            let character = self[index]
            let next = self.index(index, offsetBy: 1, limitedBy: endIndex).flatMap {
                $0 < endIndex ? self[$0] : nil
            }

            if inLineComment {
                if character == "\n" { inLineComment = false; result.append(character) }
                index = self.index(after: index)
                continue
            }
            if blockDepth > 0 {
                if character == "*", next == "/" {
                    blockDepth -= 1
                    index = self.index(index, offsetBy: 2)
                    continue
                }
                if character == "/", next == "*" {
                    blockDepth += 1
                    index = self.index(index, offsetBy: 2)
                    continue
                }
                if character == "\n" { result.append(character) }
                index = self.index(after: index)
                continue
            }
            if inString {
                if character == "\\" {
                    if !blankStrings, let escaped = self.index(index, offsetBy: 1, limitedBy: endIndex),
                       escaped < endIndex {
                        result.append(character)
                        result.append(self[escaped])
                    }
                    index = self.index(index, offsetBy: 2, limitedBy: endIndex) ?? endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                    if !blankStrings { result.append(character) }
                } else if !blankStrings {
                    result.append(character)
                }
                index = self.index(after: index)
                continue
            }
            if character == "/", next == "/" { inLineComment = true; index = self.index(index, offsetBy: 2); continue }
            if character == "/", next == "*" { blockDepth = 1; index = self.index(index, offsetBy: 2); continue }
            if character == "\"" {
                inString = true
                if !blankStrings { result.append(character) }
                index = self.index(after: index)
                continue
            }

            result.append(character)
            index = self.index(after: index)
        }
        return result
    }

    /// ¿Aparece ese identificador como palabra completa?
    ///
    /// Con fronteras a mano y no con `\b`, porque en Swift un identificador puede llevar guion
    /// bajo y `\b` lo trataría como frontera: `Foo` casaría dentro de `Foo_Bar`.
    func containsIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }
        var searchRange = startIndex..<endIndex
        while let found = range(of: identifier, range: searchRange) {
            let beforeOK = found.lowerBound == startIndex
                || !isIdentifierCharacter(self[index(before: found.lowerBound)])
            let afterOK = found.upperBound == endIndex
                || !isIdentifierCharacter(self[found.upperBound])
            if beforeOK && afterOK { return true }
            guard found.upperBound < endIndex else { return false }
            searchRange = found.upperBound..<endIndex
        }
        return false
    }

    private func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
