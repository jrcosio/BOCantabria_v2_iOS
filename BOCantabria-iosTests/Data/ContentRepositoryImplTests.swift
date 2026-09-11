//
//  ContentRepositoryImplTests.swift
//
//  La tabla de política de `contracts/internal-contracts.md` §2 **es el contrato**, y cada fila
//  tiene aquí su prueba. Más la que importa de verdad: que ningún error escapa del repositorio.
//

import Testing
@testable import BOCantabria_ios

@Suite("Repositorio de contenido")
struct ContentRepositoryImplTests {

    @Test("El remoto responde: traduce, guarda en local y devuelve éxito")
    func remoteResponds() async {
        let local = FakeContentLocalDataSource()
        let repository = ContentRepositoryImpl(
            remote: FakeContentRemoteDataSource(.responds([contentItemDTO(id: "1", label: "Título")])),
            local: local
        )

        let result = await repository.contentItems()

        #expect(result == .success([ContentItem(id: "1", title: "Título")]))
        let stored = await local.stored
        #expect(stored == [contentItemRecord(id: "1", title: "Título")])
    }

    @Test("El remoto falla y local tiene datos: devuelve lo local como respaldo")
    func remoteFailsWithLocalFallback() async {
        let repository = ContentRepositoryImpl(
            remote: FakeContentRemoteDataSource(.fails),
            local: FakeContentLocalDataSource(stored: [contentItemRecord(id: "7", title: "Guardado")])
        )

        let result = await repository.contentItems()

        #expect(result == .success([ContentItem(id: "7", title: "Guardado")]))
    }

    @Test("El remoto falla y local está vacío: fallo de red")
    func remoteFailsWithoutFallback() async {
        let repository = ContentRepositoryImpl(
            remote: FakeContentRemoteDataSource(.fails),
            local: FakeContentLocalDataSource()
        )

        let result = await repository.contentItems()

        #expect(result == .failure(.network))
    }

    @Test("El remoto responde con lista vacía: éxito vacío y se limpia lo local")
    func remoteRespondsEmpty() async {
        let local = FakeContentLocalDataSource(stored: [contentItemRecord(id: "viejo")])
        let repository = ContentRepositoryImpl(
            remote: FakeContentRemoteDataSource(.responds([])),
            local: local
        )

        let result = await repository.contentItems()

        #expect(result == .success([]))
        let stored = await local.stored
        #expect(stored.isEmpty, "Una respuesta vacía debe limpiar lo local, no dejar lo viejo.")
    }

    @Test("Ningún error escapa del repositorio")
    func noErrorEscapes() async {
        let repository = ContentRepositoryImpl(
            remote: FakeContentRemoteDataSource(.fails),
            local: FakeContentLocalDataSource()
        )

        // Si algo se lanzara, esta prueba no compilaría sin `try`. Que no haga falta es la
        // afirmación.
        let result = await repository.contentItems()

        #expect(result == .failure(.network))
    }
}
