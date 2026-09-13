//
//  Route.swift
//  The typed destinations inside a tab.
//
//  Los tres viajan **por clave, nunca por objeto**, y es la decisión que más se paga después. Si la
//  publicación viajara entera, el detalle mostraría una foto del instante en que se tocó la
//  tarjeta: una sincronización que corrigiera el título no se vería, y «esta publicación ya no
//  está» habría que inventárselo. Observando la fila, las dos cosas salen gratis (research.md
//  D-512).
//
//  `ask` lleva la clave aunque su marcador de posición todavía no la lea: añadir el argumento
//  después obligaría a cambiar una ruta que ya estaría en la calle.
//

enum Route: Hashable {
    /// El detalle de una publicación.
    case publicationDetail(externalKey: String)
    /// El visor del documento oficial. Pantalla propia, con su sitio en la pila (FR-033).
    case pdfViewer(externalKey: String)
    /// Preguntar sobre la publicación. Todavía anuncia «Próximamente» (FR-044).
    case ask(externalKey: String)
}
