//
//  PublicationRepository.swift
//  What the domain needs from whoever keeps the bulletin.
//
//  **Nunca lanza.** El error viaja como `DomainError` dentro de `AppResult`, así que el `switch`
//  de la pantalla es exhaustivo y el compilador avisa al añadir un caso. Una lista vacía es
//  `success([])`, no un fallo: «vacío» y «error» se distinguen en la capa de presentación.
//
//  Fíjate en que `refresh` **no devuelve publicaciones**. Escribe y devuelve un resumen; las
//  publicaciones llegan por la observación. Es lo que hace que no exista ningún camino por el que
//  un dato recién traído de la red alcance una vista sin pasar por lo guardado.
//

import Foundation

protocol PublicationRepository: Sendable {
    /// Emite una publicación concreta cada vez que lo guardado cambia.
    ///
    /// **Emite `.success(nil)` cuando ya no está guardada, y eso NO es un fallo**: es la
    /// información que el detalle necesita para explicarlo y ofrecer volver (FR-004). Confundirlo
    /// con un error haría que una publicación retirada se pintara como «algo ha ido mal».
    ///
    /// Que el detalle **observe** en vez de recibir la publicación por la ruta es lo que hace que
    /// una sincronización posterior corrija la pantalla sola (FR-003), y lo que evita que exista
    /// una segunda copia del dato viajando por la navegación (research.md D-512).
    func observePublication(externalKey: String) -> AsyncStream<AppResult<Publication?>>

    /// Emite la lista completa de la selección cada vez que lo guardado cambia.
    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>>

    /// Emite la cabecera editorial de la selección: denominación, fecha —opcional— y recuento.
    func observeHeader(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>>

    /// `true` si lo guardado tiene más de la ventana de caducidad, o si no hay marca todavía.
    func isCacheStale() async -> Bool

    /// - Parameter force: `true` en el gesto de deslizar, que **siempre** sale a la red; `false`
    ///   en el arranque, que respeta la caducidad.
    func refresh(force: Bool) async -> AppResult<SyncSummary>
}
