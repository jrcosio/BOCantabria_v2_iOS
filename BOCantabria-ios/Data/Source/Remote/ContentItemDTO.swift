//
//  ContentItemDTO.swift
//  What the remote source returns.
//
//  **El campo se llama `label` y no `title` a propósito.** Los nombres son deliberadamente
//  distintos de los del dominio para que la traducción sea real y no una copia de campos: si un
//  día el origen cambia de forma, el compilador señala el único sitio donde hay que tocar.
//

struct ContentItemDTO: Equatable, Sendable {
    let id: String
    let label: String
}

extension ContentItemDTO {
    func toDomain() -> ContentItem {
        ContentItem(id: id, title: label)
    }
}
