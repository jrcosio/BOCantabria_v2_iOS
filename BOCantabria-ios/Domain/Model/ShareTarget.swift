//
//  ShareTarget.swift
//  What sharing ended up offering, and why.
//
//  **El motivo forma parte del dato.** FR-040 exige explicar el caso degradado, y un booleano no
//  puede decir por qué. Sin esto, compartir un enlace en lugar del documento sorprendería sin que
//  la pantalla tuviera nada que contar.
//

import Foundation

enum ShareTarget: Sendable, Equatable {
    /// Lo normal.
    case document(SharedDocument)

    /// El caso degradado, con su motivo.
    case link(url: URL, reason: LinkReason)

    /// Por qué se acabó ofreciendo el enlace en vez del documento.
    ///
    /// **Va anidado y no suelto**: solo existe para el caso `.link`, y ahí es donde se lee. De
    /// rebote deja de ser un tipo de dominio de nivel superior, así que la regla 9 no pide un
    /// fichero de prueba propio para un enumerado de un caso sin comportamiento — que es lo que
    /// habría obligado a ampliar la lista de exentos, y cada entrada de esa lista es un agujero en
    /// la garantía que la regla da.
    ///
    /// **Un solo caso, y es una decisión.** Cualquier fallo que no sea la falta de conexión **no se
    /// disfraza de enlace**: se informa como error. Un arreglo que convierte un error en otro es
    /// peor que no arreglar nada — la aplicación de origen lo aprendió reintentando un resumen
    /// vacío contra la cuota del mismo minuto, y la persona acababa leyendo el mensaje equivocado.
    enum LinkReason: Sendable, Equatable {
        case noConnection
    }
}
