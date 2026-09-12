//
//  DocumentCache.swift
//  Where the local copies live.
//
//  **Es caché, no biblioteca** (FR-030): el directorio de cachés es el que el sistema puede vaciar
//  bajo presión de almacenamiento y el que no entra en la copia de seguridad de la persona. La base
//  de datos, en cambio, vive en Application Support. Esa separación ya estaba escrita en la
//  cabecera de `BocDatabase`: «El PDF sí irá a cachés, que es donde le toca».
//

import Foundation

protocol DocumentCache: Sendable {
    /// La copia que ya está, o `nil`.
    ///
    /// **Nunca lanza y nunca falla por una huella ilegible** (FR-024): un lateral ausente, vacío,
    /// truncado o malformado produce `OfficialDocument.unknownChecksum` y el documento se sirve
    /// igual, porque sus bytes ya se verificaron al descargarlos.
    func get(_ externalKey: String) -> OfficialDocument?

    /// La ruta del fichero temporal donde escribir. Nunca es la definitiva.
    func stage(_ externalKey: String) -> URL

    /// Hace visible lo descargado. `nil` si no se pudo.
    ///
    /// **El orden es el requisito** (FR-023): el lateral primero, el documento después. Así un
    /// documento visible implica siempre un lateral válido.
    func commit(
        _ externalKey: String,
        from part: URL,
        byteCount: Int64,
        checksum: String
    ) -> OfficialDocument?

    /// Borra un temporal. Se llama en **todos** los caminos de salida, incluido el de cancelación.
    func discard(_ part: URL)

    /// Retira lo más antiguo hasta bajar del presupuesto. **Nunca toca lo que está en uso.**
    func evict(maxBytes: Int64, keeping inUse: Set<String>)
}
