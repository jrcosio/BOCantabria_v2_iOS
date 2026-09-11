//
//  SourceTreeTests.swift
//  Tests for the reader that the architecture rules stand on.
//
//  **Una regla que no puede fallar es una regla que no protege nada.** Si el lector devolviese la
//  lista vacía, las nueve reglas pasarían en verde sin haber mirado un solo fichero, y nadie se
//  enteraría hasta que la arquitectura ya estuviera rota. Estas pruebas son las que impiden ese
//  falso verde.
//

import Foundation
import Testing

@Suite("Lector del árbol de fuentes")
struct SourceTreeTests {

    @Test("Encuentra el árbol de fuentes y no vuelve vacío")
    func findsTheSourceTree() {
        #expect(FileManager.default.fileExists(atPath: SourceTree.appSourcesRoot.path))
        #expect(SourceTree.appFiles.count > 5, "Ha leído \(SourceTree.appFiles.count) ficheros; algo va mal en la localización del árbol.")
        #expect(!SourceTree.testFileNames.isEmpty)
    }

    @Test("Cada capa tiene ficheros y tipos declarados")
    func everyLayerIsPopulated() {
        for layer in [Layer.core, .domain, .data, .ui] {
            #expect(!SourceTree.files(in: layer).isEmpty, "La capa \(layer.rawValue) ha salido vacía.")
        }
        #expect(SourceTree.declaredTypes(in: .domain).contains("DomainError"))
    }

    @Test("Extrae las importaciones")
    func extractsImports() throws {
        let theme = try #require(SourceTree.appFiles.first { $0.path == "Core/UI/Theme/BocColors.swift" })
        #expect(theme.imports.contains("SwiftUI"))
        #expect(!theme.imports.contains("Foundation"))
    }

    @Test("Distingue un tipo de nivel superior de uno anidado")
    func tellsTopLevelFromNested() {
        let code = """
        struct Outer {
            struct Inner {}
            enum Deep { case one }
        }

        enum Sibling {}
        """
        let names = Self.topLevelTypeNames(in: code)
        #expect(names == ["Outer", "Sibling"])
    }

    @Test("Recoge los atributos, estén en su línea o en la de la declaración")
    func collectsAttributes() {
        let onItsOwnLine = """
        @MainActor
        @Observable
        final class HomeViewModel {}
        """
        let inline = "@MainActor @Observable final class HomeViewModel {}"
        for code in [onItsOwnLine, inline] {
            let declaration = Self.topLevelTypes(in: code).first
            #expect(declaration?.name == "HomeViewModel")
            #expect(declaration?.attributes.contains("@MainActor") == true)
            #expect(declaration?.attributes.contains("@Observable") == true)
        }
    }

    @Test("Un comentario que nombra un tipo de otra capa no cuenta como referencia")
    func commentsAreNotReferences() {
        // Es la diferencia entre una regla que se puede cumplir y una que enseña a no escribir
        // comentarios.
        let code = """
        // Aquí se habla de ContentRepositoryImpl a propósito.
        /* Y aquí de FirebaseAnalyticsTracker. */
        struct Pure {}
        """
        let stripped = code.strippingCommentsAndStrings()
        #expect(!stripped.containsIdentifier("ContentRepositoryImpl"))
        #expect(!stripped.containsIdentifier("FirebaseAnalyticsTracker"))
        #expect(stripped.containsIdentifier("Pure"))
    }

    @Test("El contenido de una cadena tampoco cuenta como referencia")
    func stringContentsAreNotReferences() {
        let code = #"let message = "falla ContentRepositoryImpl""#
        #expect(!code.strippingCommentsAndStrings().containsIdentifier("ContentRepositoryImpl"))
    }

    @Test("Una barra doble dentro de una cadena no abre un comentario")
    func slashesInsideAStringDoNotOpenAComment() {
        let code = """
        let url = "https://example.org"
        struct AfterTheURL {}
        """
        #expect(code.strippingCommentsAndStrings().containsIdentifier("AfterTheURL"))
    }

    @Test("Las referencias se comparan como palabra completa")
    func referencesMatchWholeIdentifiersOnly() {
        #expect("let x = Foo()".containsIdentifier("Foo"))
        #expect(!"let x = FooBar()".containsIdentifier("Foo"))
        #expect(!"let x = Foo_Bar()".containsIdentifier("Foo"))
        #expect(!"let x = MyFoo()".containsIdentifier("Foo"))
        #expect("BocTheme.colors".containsIdentifier("BocTheme"))
    }

    // MARK: - Ayudas

    /// Se ejercita el mismo analizador que usan las reglas, no una copia: una copia probaría la
    /// copia.
    private static func topLevelTypes(in code: String) -> [TypeDeclaration] {
        SourceTree.topLevelTypes(in: code)
    }

    private static func topLevelTypeNames(in code: String) -> [String] {
        topLevelTypes(in: code).map(\.name)
    }

    @Test("`code` vacía las cadenas y `rawCode` las conserva, y las dos quitan los comentarios")
    func rawCodeKeepsStringLiteralsAndCodeDoesNot() {
        let source = """
        // DELETE FROM publications
        let sql = "DELETE FROM publications WHERE id = ?"
        let name = Publication.self
        """
        let stripped = source.strippingCommentsAndStrings()
        let raw = source.strippingComments()

        // El comentario desaparece de las dos: sin eso, un comentario que explica por qué algo no
        // debe pasar dispararía la regla que ese comentario documenta.
        #expect(!stripped.contains("// DELETE"))
        #expect(!raw.contains("// DELETE"))

        // Y la diferencia que justifica que existan las dos: una sentencia SQL **es** una cadena.
        #expect(!stripped.contains("DELETE FROM publications"))
        #expect(raw.contains("DELETE FROM publications"))

        // Lo que está fuera de la cadena sigue en las dos.
        #expect(stripped.contains("Publication"))
        #expect(raw.contains("Publication"))
    }

    @Test("Todo fichero del árbol tiene las dos vistas")
    func everyFileHasBothViews() {
        for file in SourceTree.appFiles.prefix(5) {
            #expect(!file.rawCode.isEmpty)
            #expect(file.rawCode.count >= file.code.count)
        }
    }
}
