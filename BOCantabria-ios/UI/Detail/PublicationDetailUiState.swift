//
//  PublicationDetailUiState.swift
//  What the detail screen shows.
//
//  **`document` y `share` van fuera de un enumerado único**, y es la misma decisión que tomó
//  `HomeUiState`: son ejes **ortogonales**. Se puede estar preparando algo para compartir mientras
//  el documento ya está disponible, y meterlo todo en una jerarquía multiplicaría los casos sin que
//  ninguno aportara nada.
//

import Foundation

struct PublicationDetailUiState: Equatable {
    /// `nil` mientras carga **o** si ya no está guardada. Los dos casos se distinguen con
    /// `isMissing`, porque «todavía no» y «ya no» piden pantallas distintas.
    var publication: Publication?
    var section: BocSection?
    /// Ya no está entre lo guardado (FR-004). **No es un error.**
    var isMissing: Bool = false
    /// No se pudo leer lo guardado. **Esto sí es un error**, y es otra cosa.
    ///
    /// **Va en su propio campo y no dentro de `document`**, y eso lo destapó una prueba. Escribir
    /// `document` desde la observación de la publicación **y** desde la del documento es una
    /// carrera aunque las dos escrituras sean correctas: la segunda pisa a la primera y el fallo de
    /// lectura desaparece un instante después de aparecer. Es literalmente la trampa que la feature
    /// del boletín dejó anotada —«escribir dos veces el mismo estado desde dos sitios»— y aquí
    /// volvió a morder.
    var loadFailed: Bool = false
    var selectedTab: DetailTab = .document
    var document: DocumentStatus = .absent
    var share: ShareState = .idle

    /// El nombre de la sección para la etiqueta de la cabecera.
    var sectionName: String {
        section?.shortName ?? publication?.mostSpecificSectionCode ?? ""
    }
}

/// **Un evento de un solo uso**: se consume y vuelve a `idle`.
///
/// Si no se consumiera, volver a la pantalla reabriría la hoja de compartir sin que nadie la
/// hubiera pedido.
enum ShareState: Equatable {
    case idle
    case preparing
    case ready(ShareTarget)
}
