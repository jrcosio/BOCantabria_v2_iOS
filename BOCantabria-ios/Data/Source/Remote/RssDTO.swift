//
//  RssDTO.swift
//  What arrives from a source, before anyone interprets it.
//
//  **Todo es anulable a propósito.** El DTO refleja lo que llega, no lo que debería llegar. Decidir
//  qué falta y qué sobra es trabajo del normalizador, y mezclarlo aquí haría que un item con un
//  campo de menos reventara el analizado del canal entero.
//

import Foundation

struct RssChannelDTO: Sendable, Equatable {
    let title: String?
    let link: String?
    let description: String?
    /// El `<size>` que declara el canal. **Es informativo**: si no coincide con el número real de
    /// nodos, mandan los nodos y se registra aviso. No implica paginación ni total histórico.
    let declaredSize: Int?
    let items: [RssItemDTO]
}

struct RssItemDTO: Sendable, Equatable {
    let title: String?
    let link: String?
    let pubDateRaw: String?
    let categoriesRaw: String?
}
