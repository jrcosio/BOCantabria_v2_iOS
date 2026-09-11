//
//  BocSectionRepository.swift
//  The official section tree, as the screens consume it.
//
//  No lee de la base: es catálogo. Existe como protocolo porque la pantalla no tiene por qué
//  saber que hoy es una constante, y porque el día que las secciones vengan de un servicio esto
//  no cambia.
//

import Foundation

protocol BocSectionRepository: Sendable {
    /// El árbol completo, ordenado. Veintitrés filas.
    func sections() -> [BocSection]
}
