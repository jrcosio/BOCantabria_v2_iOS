//
//  ContentItem.swift
//  What the initial screen shows.
//
//  **Deliberadamente trivial.** Existe para demostrar que el recorrido entre capas funciona y para
//  ser el patrón de referencia de las features siguientes; lo sustituye el modelo real del boletín.
//

struct ContentItem: Equatable, Identifiable, Sendable {
    /// No vacío y **estable entre cargas**: identifica al elemento, no a su posición.
    let id: String
    /// No vacío, visible.
    let title: String
}
