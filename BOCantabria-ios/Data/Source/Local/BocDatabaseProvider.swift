//
//  BocDatabaseProvider.swift
//  Holds the database, and opens it exactly once.
//
//  El contenedor lo construye **sin abrir nada**: construirlo no puede disparar trabajo, y hay una
//  prueba que lo comprueba. Quien fuerza la apertura es la comprobación previa de la portada, que
//  es la que sabe enseñar un fallo.
//

import Foundation
import GRDB
import Synchronization

final class BocDatabaseProvider: StoragePreparing, Sendable {
    private let opener: @Sendable () throws -> BocDatabase
    private let outcome = Mutex<Result<BocDatabase, StorageError>?>(nil)
    private let crashReporter: CrashReporter

    init(
        crashReporter: CrashReporter,
        opener: @escaping @Sendable () throws -> BocDatabase = { try BocDatabase.open() }
    ) {
        self.crashReporter = crashReporter
        self.opener = opener
    }

    /// Una base en memoria, para pruebas y para los escenarios de las pruebas de interfaz.
    static func inMemory(
        crashReporter: CrashReporter,
        tracingStatements: Bool = false
    ) -> BocDatabaseProvider {
        BocDatabaseProvider(crashReporter: crashReporter) {
            try BocDatabase.inMemory(tracingStatements: tracingStatements)
        }
    }

    func prepare() async -> AppResult<Void> {
        switch resolved() {
        case .success: .success(())
        case .failure: .failure(.storage)
        }
    }

    /// La base, si se pudo abrir. Quien la pide después del arranque ya sabe que está.
    func database() -> BocDatabase? {
        try? resolved().get()
    }

    private func resolved() -> Result<BocDatabase, StorageError> {
        outcome.withLock { cached in
            if let cached { return cached }
            let result: Result<BocDatabase, StorageError>
            do {
                result = .success(try opener())
            } catch let error as StorageError {
                // Un fallo que no se escribe es un misterio. Nunca el contenido, solo el motivo.
                crashReporter.log("storage: could not open the database: \(error)")
                result = .failure(error)
            } catch {
                crashReporter.log("storage: could not open the database: \(error)")
                result = .failure(.migrationFailed)
            }
            cached = result
            return result
        }
    }
}
