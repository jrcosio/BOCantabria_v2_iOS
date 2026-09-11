//
//  BocFeedCatalog.swift
//  The nineteen official sources, written out one by one.
//
//  **Las direcciones se escriben enteras y no se componen por cálculo** (FR-002). No es un
//  capricho de estilo: los identificadores que el servicio asignó no son correlativos —faltan
//  varios en medio— y dos pertenecen a un rango completamente distinto. Una dirección construida
//  sumando números apuntaría a otra cosa, o a nada, y el fallo no se vería hasta producción.
//
//  Esto vive en `Data` y el árbol de secciones vive en `Domain`, y la frontera importa: las nueve
//  secciones son conocimiento de negocio; una dirección es un detalle de procedencia. El día que
//  haya un servicio propio que agregue las fuentes, esto desaparece y las secciones no cambian.
//

import Foundation

struct BocFeedDefinition: Sendable, Hashable, Identifiable {
    let feedId: String
    let url: URL
    /// La sección que esta fuente representa **de forma autoritativa** (FR-012).
    let sectionCode: String
    let subsectionCode: String?
    let order: Int
    let enabled: Bool

    var id: String { feedId }

    /// El código más específico que la fuente representa.
    var mostSpecificSectionCode: String { subsectionCode ?? sectionCode }
}

enum BocFeedCatalog {
    /// Las diecinueve fuentes, en orden oficial.
    ///
    /// Observadas el 27 de agosto de 2026. Los recuentos y las fechas de aquella observación
    /// **no se codifican**: la 4.3 tenía nueve entradas y la 8.1 ninguna, y las dos cosas son
    /// resultados válidos que pueden cambiar mañana.
    static let all: [BocFeedDefinition] = [
        feed("6802081", "https://www.cantabria.es/o/BOC/feed/6802081", "1", nil, 1),
        feed("6802084", "https://www.cantabria.es/o/BOC/feed/6802084", "2", "2.1", 2),
        feed("6802085", "https://www.cantabria.es/o/BOC/feed/6802085", "2", "2.2", 3),
        feed("6802086", "https://www.cantabria.es/o/BOC/feed/6802086", "2", "2.3", 4),
        feed("6802087", "https://www.cantabria.es/o/BOC/feed/6802087", "3", nil, 5),
        feed("6802089", "https://www.cantabria.es/o/BOC/feed/6802089", "4", "4.1", 6),
        feed("6802090", "https://www.cantabria.es/o/BOC/feed/6802090", "4", "4.2", 7),
        feed("6802091", "https://www.cantabria.es/o/BOC/feed/6802091", "4", "4.3", 8),
        feed("6802092", "https://www.cantabria.es/o/BOC/feed/6802092", "4", "4.4", 9),
        feed("6802094", "https://www.cantabria.es/o/BOC/feed/6802094", "5", nil, 10),
        feed("6802095", "https://www.cantabria.es/o/BOC/feed/6802095", "6", nil, 11),
        feed("6802097", "https://www.cantabria.es/o/BOC/feed/6802097", "7", "7.1", 12),
        feed("6802098", "https://www.cantabria.es/o/BOC/feed/6802098", "7", "7.2", 13),
        feed("6802099", "https://www.cantabria.es/o/BOC/feed/6802099", "7", "7.3", 14),
        feed("6802100", "https://www.cantabria.es/o/BOC/feed/6802100", "7", "7.4", 15),
        feed("6802301", "https://www.cantabria.es/o/BOC/feed/6802301", "7", "7.5", 16),
        feed("7479572", "https://www.cantabria.es/o/BOC/feed/7479572", "8", "8.1", 17),
        feed("6802303", "https://www.cantabria.es/o/BOC/feed/6802303", "8", "8.2", 18),
        feed("7293890", "https://www.cantabria.es/o/BOC/feed/7293890", "9", nil, 19),
    ]

    /// Las que se consultan. Desactivar una entrada la retira de aquí **sin tocar el proceso de
    /// lectura**, que es lo que FR-003 pide.
    static var active: [BocFeedDefinition] {
        all.filter(\.enabled).sorted { $0.order < $1.order }
    }

    static func named(_ feedId: String) -> BocFeedDefinition? {
        all.first { $0.feedId == feedId }
    }

    private static func feed(
        _ feedId: String,
        _ url: String,
        _ sectionCode: String,
        _ subsectionCode: String?,
        _ order: Int,
        enabled: Bool = true
    ) -> BocFeedDefinition {
        BocFeedDefinition(
            feedId: feedId,
            // Forzar aquí es correcto: son constantes escritas a mano en este mismo fichero y su
            // validez la comprueba una prueba. Si alguna dejara de serlo, la prueba se pone roja
            // antes de que nadie la ejecute contra el servicio.
            url: URL(string: url)!,
            sectionCode: sectionCode,
            subsectionCode: subsectionCode,
            order: order,
            enabled: enabled
        )
    }
}
