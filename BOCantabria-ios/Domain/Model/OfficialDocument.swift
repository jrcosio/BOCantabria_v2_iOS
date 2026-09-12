//
//  OfficialDocument.swift
//  The local copy of a publication's official document.
//
//  **Es caché, no biblioteca.** Puede desaparecer sin que se pierda nada: el sistema vacía el
//  directorio de cachés cuando le hace falta espacio, y la aplicación lo vuelve a traer. Por eso no
//  hay ninguna fila en la base de datos que lo represente: una fila que sobrevive al fichero es una
//  mentira que luego hay que reconciliar (research.md D-501).
//
//  **No lleva la dirección de origen**, aunque la tentación es evidente. La tiene la `Publication`,
//  y duplicarla aquí crearía una segunda verdad que puede quedarse atrás.
//

import Foundation

struct OfficialDocument: Sendable, Hashable {
    /// A qué publicación pertenece. Es su identidad.
    let externalKey: String

    /// Dónde está en el dispositivo.
    ///
    /// **`String` y no `URL`, a propósito.** `URL` es un tipo con semántica de sistema de ficheros,
    /// y el dominio no debe tener opinión sobre rutas. `Publication.documentUrl` **sí** es `URL`
    /// porque una dirección de red es un concepto del problema, no del dispositivo.
    let localPath: String

    /// Lo que ocupa. Es la base del tope de la caché.
    let byteCount: Int64

    /// La huella de lo recibido, en hexadecimal. O `unknownChecksum`.
    let checksum: String

    /// Cuándo se usó por última vez. Base de la retirada por antigüedad.
    let lastUsedAt: Date

    /// La huella que se usa cuando el lateral falta o no se puede leer.
    ///
    /// **Es pública y es parte del contrato** (FR-024). Un lateral ausente, vacío, truncado o
    /// malformado produce este valor, **no** un fallo: los bytes del documento ya se verificaron al
    /// descargarlos, y solo se hizo visible cuando estaban completos.
    ///
    /// La aplicación de origen aprendió esto de la peor manera. Allí el lateral se leía con «lo que
    /// haya, y si no hay nada, el valor vacío»; un lateral **presente pero vacío** devuelve la
    /// cadena vacía, que no es «nada», así que el respaldo no se aplicaba nunca al caso que
    /// importaba, la comprobación de sesenta y cuatro caracteres saltaba y **la aplicación se
    /// cerraba al abrir esa publicación**, y otra vez en cada reintento (research.md D-506).
    static let unknownChecksum = String(repeating: "0", count: 64)

    /// Exactamente sesenta y cuatro hexadecimales en minúscula. Nada más.
    ///
    /// Estricta a propósito: una huella en mayúsculas no concuerda con la que se escribió, y
    /// aceptarla convertiría una comparación en un «a veces».
    static func isValidChecksum(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// `true` cuando la huella se perdió y el documento se sirve igualmente.
    var hasUnknownChecksum: Bool { checksum == Self.unknownChecksum }
}
