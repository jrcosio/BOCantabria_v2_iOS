//
//  DocumentStatus.swift
//  Where the local copy of a document stands.
//
//  **Es lo ÚNICO que el detalle, el visor y compartir observan**, y de ahí viene el invariante más
//  importante de la feature: todo camino de error tiene que publicar un estado de éstos. Devolver
//  un fallo a quien pidió la descarga **y no publicarlo** deja las pantallas cargando para siempre,
//  porque no leen el resultado: leen el estado (research.md D-507, FR-029).
//

import Foundation

enum DocumentStatus: Sendable, Equatable {
    /// Nunca se pidió, se retiró de la caché, **o se canceló**.
    ///
    /// Que cancelar acabe aquí y no en `failed` es deliberado (FR-027): quien canceló ya no está
    /// mirando, y la próxima visita no debe encontrarse un error que nadie provocó.
    case absent

    /// `totalBytes` es opcional **a propósito**: el servicio puede no declarar la longitud, y
    /// entonces la barra tiene que ser indeterminada, que es la verdad. Un `-1` disfrazado de total
    /// pintaría una barra llena.
    case downloading(bytesRead: Int64, totalBytes: Int64?)

    case available(OfficialDocument)

    case failed(DomainError)

    /// Todo menos «obteniéndose».
    ///
    /// Existe para que la prueba de FR-029 pueda afirmar **una sola cosa** sobre los siete caminos
    /// de error en vez de enumerarlos: el último estado es terminal.
    var isTerminal: Bool {
        if case .downloading = self { return false }
        return true
    }

    /// El documento, cuando lo hay.
    var document: OfficialDocument? {
        if case .available(let document) = self { return document }
        return nil
    }
}
