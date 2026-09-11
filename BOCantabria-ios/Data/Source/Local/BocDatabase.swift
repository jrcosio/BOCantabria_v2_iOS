//
//  BocDatabase.swift
//  The only place that opens the database.
//
//  **`DatabaseQueue` y no `DatabasePool`**, y el motivo decisivo es de pruebas: `DatabasePool` no
//  tiene inicializador en memoria, así que la suite probaría un motor distinto del que corre en el
//  teléfono. Lo que un pool compra es leer mientras se escribe, y **la escritura larga no existe**
//  porque la sincronización escribe por fuente conforme termina: diecinueve transacciones cortas
//  en vez de una de mil novecientas filas. Las dos decisiones se sostienen la una a la otra.
//
//  La base en memoria **ignora el modo de diario**. Es inocuo para los invariantes que se prueban
//  —upsert, lista blanca de columnas, ausencia de borrados— y no lo es para nada que dependa de
//  durabilidad. Queda escrito para que nadie deduzca una cobertura que no hay.
//
//  Este fichero y sus vecinos de `Data/Source/Local/` son los **únicos** que pueden nombrar un
//  tipo de GRDB, y hay una regla de arquitectura que lo comprueba.
//

import Foundation
import GRDB
import Synchronization

/// Errores de la capa de almacenamiento, ya traducidos. GRDB no sale de aquí.
enum StorageError: Error, Equatable {
    case cannotOpen
    case migrationFailed
}

final class BocDatabase: Sendable {
    private let writer: DatabaseQueue

    /// Las sentencias ejecutadas, cuando alguien pide recogerlas.
    ///
    /// Es lo que hace **demostrable** el invariante de que nunca se borra una publicación: una
    /// regla de texto no puede verlo, porque GRDB borra con métodos de registro y la palabra no
    /// aparece en ninguna cadena del fuente (research.md D-324).
    private let trace: StatementTrace?

    private init(writer: DatabaseQueue, trace: StatementTrace?) {
        self.writer = writer
        self.trace = trace
    }

    // MARK: - Apertura

    /// Abre la base del dispositivo y aplica las migraciones.
    ///
    /// Vive en `Application Support` y **no en cachés**: el sistema puede vaciar cachés bajo
    /// presión de almacenamiento, y ésta es la procedencia de lo que la pantalla muestra. El PDF
    /// sí irá a cachés, que es donde le toca.
    static func open(at url: URL? = nil) throws -> BocDatabase {
        let fileUrl: URL
        do {
            fileUrl = try url ?? defaultUrl()
        } catch {
            throw StorageError.cannotOpen
        }

        var configuration = Configuration()
        configuration.journalMode = .wal
        configuration.prepareDatabase { database in
            // Clase de protección explícita: la de por defecto puede impedir escribir con el
            // dispositivo bloqueado, y la sincronización en segundo plano de la feature de Avisos
            // va a necesitarlo. Cuesta una línea decidirlo aquí.
            try database.execute(sql: "PRAGMA foreign_keys = ON")
        }

        do {
            let queue = try DatabaseQueue(path: fileUrl.path, configuration: configuration)
            try BocMigrations.migrator.migrate(queue)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileUrl.path
            )
            return BocDatabase(writer: queue, trace: nil)
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
            throw StorageError.cannotOpen
        } catch {
            throw StorageError.migrationFailed
        }
    }

    /// Una base en memoria. Es la que usan las pruebas, y por eso `DatabaseQueue`.
    ///
    /// - Parameter tracingStatements: recoge cada sentencia que se ejecuta. Lo usa la prueba de
    ///   regresión que demuestra que nada borra publicaciones.
    static func inMemory(tracingStatements: Bool = false) throws -> BocDatabase {
        let trace = tracingStatements ? StatementTrace() : nil
        var configuration = Configuration()
        if let trace {
            configuration.prepareDatabase { database in
                database.trace(options: .statement) { event in
                    trace.record(String(describing: event))
                }
            }
        }
        do {
            let queue = try DatabaseQueue(configuration: configuration)
            try BocMigrations.migrator.migrate(queue)
            return BocDatabase(writer: queue, trace: trace)
        } catch {
            throw StorageError.migrationFailed
        }
    }

    static func defaultUrl() throws -> URL {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return folder.appendingPathComponent("boc.db")
    }

    // MARK: - Acceso

    /// Lectura. El cierre corre en la cola de la base y tiene que quedarse puro.
    func read<T: Sendable>(_ work: @Sendable (Database) throws -> T) throws -> T {
        try writer.read(work)
    }

    /// Escritura, en una transacción.
    func write<T: Sendable>(_ work: @Sendable (Database) throws -> T) throws -> T {
        try writer.write(work)
    }

    /// Observa una consulta y la entrega como flujo de dominio.
    ///
    /// **Planificador `.task`, nunca `.immediate`**: el inmediato entrega el primer valor de forma
    /// síncrona, lo que obliga a arrancar desde el hilo principal y hace **una lectura de SQLite
    /// en el actor principal**. El parpadeo que evitaría se resuelve con el estado de carga que la
    /// pantalla ya modela con esqueletos.
    func observe<T: Sendable>(
        _ fetch: @escaping @Sendable (Database) throws -> T
    ) -> AsyncValueObservation<T> {
        ValueObservation.tracking(fetch).values(in: writer, scheduling: .task)
    }

    /// Las sentencias recogidas, si se pidió recogerlas.
    var executedStatements: [String] { trace?.statements ?? [] }

    /// El modo de diario real del fichero. Solo lo consulta la prueba que comprueba que es WAL.
    func journalMode() throws -> String {
        try read { database in
            try String.fetchOne(database, sql: "PRAGMA journal_mode") ?? ""
        }
    }
}

/// Recolector de sentencias. Es una clase con cerrojo porque el cierre de traza de GRDB puede
/// llegar desde cualquier hilo.
private final class StatementTrace: Sendable {
    private let storage = Mutex<[String]>([])

    var statements: [String] { storage.withLock { $0 } }

    func record(_ statement: String) {
        storage.withLock { $0.append(statement) }
    }
}
