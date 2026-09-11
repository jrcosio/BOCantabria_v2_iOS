//
//  AppInfo.swift
//  Reads what the bundle knows about the installed application.
//
//  Vive aquí y no en `Domain` porque `AppVersion` tiene que seguir siendo Swift puro: el modelo es
//  el dato, y esto es quien lo trae (research.md D-206).
//

import Foundation

enum AppInfo {
    /// La versión instalada, la que la persona ve en la tienda.
    ///
    /// **Es opcional, y el opcional importa.** Si no se pudiera leer, devolver un cero de respaldo
    /// sería lo más cómodo y lo más peligroso: cero es *menor* que cualquier mínimo publicado, así
    /// que la aplicación se bloquearía a sí misma justo en el caso en que no sabe su propia
    /// versión. Nulo significa «no se puede comparar», y quien compara no bloquea ante la duda.
    static var installedVersion: AppVersion? {
        version(from: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// La conversión, separada de la lectura para poder probarla sin inventar un paquete.
    static func version(from text: String?) -> AppVersion? {
        guard let text else { return nil }
        return AppVersion(text)
    }
}
