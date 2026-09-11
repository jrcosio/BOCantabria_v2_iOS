//
//  StoragePreparing.swift
//  Opening the local store is a startup step, not a side effect of building the graph.
//
//  Abrir un fichero y migrarlo puede fallar, y un fallo tiene que poder **contarse**. Hoy el único
//  sitio de la aplicación con indicador de progreso, límite de espera y estado de error con
//  reintento es la portada, así que ahí es donde ocurre (research.md D-305).
//
//  Si se abriera perezosamente, ese fallo aparecería con Inicio ya pintado y habría que inventarle
//  un sitio donde contarse. Si se abriera al construir el contenedor, metería E/S de disco en el
//  camino crítico del arranque **sin indicador ninguno** y un fallo no tendría más salida que
//  cerrarse.
//

import Foundation

protocol StoragePreparing: Sendable {
    /// Abre y migra el almacén local. **Nunca lanza**: el fallo viaja como `DomainError.storage`.
    func prepare() async -> AppResult<Void>
}
