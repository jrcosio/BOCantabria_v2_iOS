//
//  DocumentRepository.swift
//  What the domain needs from whoever keeps the local copies of the official documents.
//
//  **Nunca lanza**, como el resto de repositorios: el error viaja como `DomainError` dentro de
//  `AppResult`, así que el `switch` de la pantalla es exhaustivo y el compilador avisa al añadir un
//  caso.
//
//  Fíjate en que `observeDocument` **no** devuelve `AppResult`. `DocumentStatus` ya lleva su propio
//  caso de fallo, y envolverlo daría dos formas de decir lo mismo — y, peor, dos sitios donde
//  mirar para saber si algo fue mal.
//

import Foundation

protocol DocumentRepository: Sendable {
    /// Emite el estado de la copia local cada vez que cambia.
    ///
    /// **Lo primero que recibe quien se suscribe es el estado vigente**, no el siguiente cambio.
    /// Sin esa reproducción, el visor que se abre con el documento ya disponible no recibe nada y
    /// se queda cargando para siempre: un cuelgue silencioso, sin excepción y sin nada en el
    /// registro (research.md D-510).
    func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus>

    /// Devuelve la copia local, obteniéndola si hace falta.
    ///
    /// Dos llamadas simultáneas para la misma publicación producen **una** descarga (FR-026), y
    /// quien espera **no hereda la cancelación** de quien la inició (FR-028).
    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument>

    /// Retira de la caché lo más antiguo hasta bajar del presupuesto. **Nunca toca lo que está en
    /// uso** (FR-030).
    func releaseUnused() async
}
