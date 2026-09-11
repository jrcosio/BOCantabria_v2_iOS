//
//  HomeSelectionStore.swift
//  Where the current selection survives the process being killed.
//
//  Es un protocolo de dominio y no un envoltorio de preferencias a propósito: la pantalla no tiene
//  por qué saber dónde se guarda, y así el modelo de pantalla se prueba con un doble en memoria
//  sin necesitar simulador.
//

import Foundation

protocol HomeSelectionStore: Sendable {
    /// Devuelve la selección guardada **resuelta contra el catálogo**. Un código que ya no existe
    /// devuelve «Boletín de hoy» en silencio.
    func load() -> HomeSelection
    func save(_ selection: HomeSelection)
}
