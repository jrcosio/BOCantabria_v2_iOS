//
//  ContentRepositoryImpl.swift
//  Remote with local fallback.
//
//  La política de cuatro casos está en `contracts/internal-contracts.md` §2 y **cada fila tiene su
//  prueba**. Se implementa entera aquí, aunque los orígenes de esta feature sean de mentira,
//  porque es la política que heredan las features reales: si se dejara para entonces, habría que
//  escribirla con la presión de una funcionalidad encima.
//

struct ContentRepositoryImpl: ContentRepository {
    private let remote: ContentRemoteDataSource
    private let local: ContentLocalDataSource

    init(remote: ContentRemoteDataSource, local: ContentLocalDataSource) {
        self.remote = remote
        self.local = local
    }

    func contentItems() async -> AppResult<[ContentItem]> {
        do {
            let fetched = try await remote.fetchContentItems()
            let items = fetched.map { $0.toDomain() }
            // Una respuesta vacía también se guarda: limpia lo local, que es lo que evita servir
            // un archivo fantasma cuando el origen ya no lo tiene.
            await local.writeContentItems(items.map(ContentItemRecord.init))
            return .success(items)
        } catch {
            // **La cancelación no se trata aquí, y es deliberado.** En Kotlin había que
            // repropagar `CancellationException` a mano porque se colaba entre los `catch` y se
            // publicaba como un fallo de red que nunca ocurrió. En Swift la cancelación es
            // cooperativa: esta función no lanza, así que lo correcto es que quien espera el
            // resultado compruebe `Task.isCancelled` antes de publicar nada. Lo hace
            // `HomeViewModel`.
            let cached = await local.readContentItems()
            guard cached.isEmpty else {
                return .success(cached.map { $0.toDomain() })
            }
            return .failure(.network)
        }
    }
}
