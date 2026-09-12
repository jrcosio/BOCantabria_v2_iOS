//
//  FileDocumentCache.swift
//  The local copies on disk, and the two things that go wrong with them.
//
//  ## El nombre del fichero es una huella de la clave, no la clave
//
//  `externalKey` vale `boc:439765` cuando el enlace trae identificador, y **una dirección entera**
//  cuando no lo trae. Los dos puntos y las barras dentro de un nombre de fichero son, en el mejor
//  caso, un fichero que no se puede abrir y, en el peor, una escritura fuera del directorio
//  previsto. Y la clave viene **de la red** (research.md D-505).
//
//  ## El lateral va primero, y se valida al leer
//
//  ```text
//  <huella>.pdf            visible SOLO si está completo
//  <huella>.pdf.part       descarga en curso
//  <huella>.sha256         64 hexadecimales en minúscula
//  <huella>.sha256.part    escritura en curso
//  ```
//
//  Invariante: **documento visible ⇒ lateral válido**. En la aplicación de origen el orden era el
//  contrario y el lateral se leía con «lo que haya, y si no hay nada, el valor vacío»; un lateral
//  **presente pero vacío** devuelve la cadena vacía, que no es «nada», así que el respaldo no se
//  aplicaba nunca al caso que importaba y **la aplicación se cerraba al abrir esa publicación**, y
//  otra vez en cada reintento. Era el hallazgo de severidad alta de su auditoría (D-506).
//
//  El orden importa porque **la huella tiene consumidor**: decide si un resumen guardado sigue
//  correspondiendo al documento, y regenerarlo cuesta cuota. Con el orden contrario existe una
//  ventana —documento visible, lateral aún sin escribir— en la que un resumen bueno se declara
//  obsoleto.
//

import CryptoKit
import Foundation

struct FileDocumentCache: DocumentCache {
    /// Cien mebibytes. Es la cifra que la aplicación de origen midió.
    static let defaultBudget: Int64 = 100 * 1024 * 1024

    private let directory: URL
    private let clock: AppClock
    private let crashReporter: CrashReporter

    /// **Calculado y no almacenado**: `FileManager` no es `Sendable`, así que guardarlo haría que
    /// este tipo dejara de serlo, y la caché la comparte todo el proceso. `FileManager.default` es
    /// seguro entre hilos para lo que aquí se usa.
    private var fileManager: FileManager { .default }

    /// - Parameter directory: por defecto, `<cachés>/documents`. Las pruebas pasan un temporal.
    init(directory: URL? = nil, clock: AppClock, crashReporter: CrashReporter) {
        self.directory = directory ?? Self.defaultDirectory()
        self.clock = clock
        self.crashReporter = crashReporter
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    static func defaultDirectory() -> URL {
        let caches = fileManagerCachesDirectory()
        return caches.appendingPathComponent("documents", isDirectory: true)
    }

    private static func fileManagerCachesDirectory() -> URL {
        (try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
    }

    // MARK: - Lectura

    func get(_ externalKey: String) -> OfficialDocument? {
        let document = documentUrl(externalKey)
        guard fileManager.fileExists(atPath: document.path) else { return nil }

        let size = (try? fileManager.attributesOfItem(atPath: document.path)[.size] as? NSNumber)??.int64Value
        guard let size, size > 0 else {
            // Un fichero visible y vacío no es un documento: se trata como ausente y la descarga
            // lo repara.
            crashReporter.log("document: cache entry has no bytes")
            return nil
        }

        // Se toca para que la retirada por antigüedad sepa que se ha usado. El instante lo da el
        // reloj **inyectado**: la regla 11 prohíbe el del dispositivo fuera de `Core/Util`.
        let now = clock.now()
        try? fileManager.setAttributes([.modificationDate: now], ofItemAtPath: document.path)

        return OfficialDocument(
            externalKey: externalKey,
            localPath: document.path,
            byteCount: size,
            checksum: readChecksum(externalKey) ?? OfficialDocument.unknownChecksum,
            lastUsedAt: now
        )
    }

    /// La huella, **o `nil` si no se puede creer**.
    ///
    /// Se recorta el espacio en blanco y se exige el formato exacto. Vacío, truncado, en mayúsculas
    /// o con basura son todos lo mismo que ausente: **huella perdida** (FR-024).
    private func readChecksum(_ externalKey: String) -> String? {
        let sidecar = checksumUrl(externalKey)
        guard let raw = try? String(contentsOf: sidecar, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard OfficialDocument.isValidChecksum(trimmed) else {
            crashReporter.log("document: checksum sidecar unreadable, served without checksum")
            return nil
        }
        return trimmed
    }

    // MARK: - Escritura

    func stage(_ externalKey: String) -> URL {
        documentUrl(externalKey).appendingPathExtension("part")
    }

    func commit(
        _ externalKey: String,
        from part: URL,
        byteCount: Int64,
        checksum: String
    ) -> OfficialDocument? {
        let document = documentUrl(externalKey)
        let sidecar = checksumUrl(externalKey)
        let sidecarPart = sidecar.appendingPathExtension("part")

        do {
            // 1 y 2 · El lateral, **antes** que el documento. Escribir y renombrar, para que nunca
            // exista un lateral a medias con el nombre bueno.
            try Data(checksum.utf8).write(to: sidecarPart, options: .atomic)
            try? fileManager.removeItem(at: sidecar)
            try fileManager.moveItem(at: sidecarPart, to: sidecar)

            // 3 · El documento. El renombrado dentro del mismo volumen es atómico.
            try? fileManager.removeItem(at: document)
            try fileManager.moveItem(at: part, to: document)
        } catch {
            // 4 · Si el documento no llegó a hacerse visible, el lateral **sobra**: dejarlo
            // apuntaría a un documento que no existe.
            crashReporter.log("document: commit failed: \(type(of: error))")
            try? fileManager.removeItem(at: sidecarPart)
            try? fileManager.removeItem(at: sidecar)
            try? fileManager.removeItem(at: part)
            return nil
        }

        let now = clock.now()
        try? fileManager.setAttributes([.modificationDate: now], ofItemAtPath: document.path)
        return OfficialDocument(
            externalKey: externalKey, localPath: document.path,
            byteCount: byteCount, checksum: checksum, lastUsedAt: now
        )
    }

    func discard(_ part: URL) {
        try? fileManager.removeItem(at: part)
    }

    // MARK: - Retirada

    func evict(maxBytes: Int64, keeping inUse: Set<String>) {
        let protegidos = Set(inUse.map { fingerprint($0) })
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        // Los temporales huérfanos se van siempre: no son caché, son restos.
        for entry in entries where entry.pathExtension == "part" {
            try? fileManager.removeItem(at: entry)
        }

        struct Entry {
            let url: URL
            let stem: String
            let size: Int64
            let usedAt: Date
        }

        let documentos: [Entry] = entries
            .filter { $0.pathExtension == "pdf" }
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let stem = url.deletingPathExtension().lastPathComponent
                return Entry(
                    url: url,
                    stem: stem,
                    size: Int64(values?.fileSize ?? 0),
                    usedAt: values?.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.usedAt < $1.usedAt }  // lo más antiguo primero

        var total = documentos.reduce(Int64(0)) { $0 + $1.size }
        for entry in documentos where total > maxBytes {
            // **Lo que está en uso no se retira, aunque sea lo más antiguo** (FR-030). Retirarlo
            // dejaría al visor leyendo un fichero que acaba de desaparecer.
            guard !protegidos.contains(entry.stem) else { continue }
            try? fileManager.removeItem(at: entry.url)
            try? fileManager.removeItem(at: entry.url.deletingPathExtension().appendingPathExtension("sha256"))
            total -= entry.size
        }
    }

    // MARK: - Rutas

    private func fingerprint(_ externalKey: String) -> String {
        SHA256.hash(data: Data(externalKey.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func documentUrl(_ externalKey: String) -> URL {
        directory.appendingPathComponent(fingerprint(externalKey)).appendingPathExtension("pdf")
    }

    private func checksumUrl(_ externalKey: String) -> URL {
        directory.appendingPathComponent(fingerprint(externalKey)).appendingPathExtension("sha256")
    }
}
