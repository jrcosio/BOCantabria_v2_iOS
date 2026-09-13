//
//  DetailTab.swift
//  The two tabs of the detail screen.
//
//  **Dos, no tres.** «Preguntar» dejó de ser pestaña y pasó a ser pantalla propia: una conversación
//  sobre un boletín de cuarenta páginas necesita la pantalla entera y su sitio en la pila de
//  retroceso, que no es lo que da una pestaña junto a una ficha de metadatos (FR-014, FR-044).
//
//  Vive en `Domain` porque las dos pestañas son parte de lo que la feature promete, no una decisión
//  de dibujo.
//

enum DetailTab: String, Sendable, CaseIterable {
    case document
    case aiSummary
}

extension DetailTab {
    /// La pestaña guardada se restaura **por nombre y con respaldo**, nunca con `init(rawValue:)`
    /// a secas.
    ///
    /// **Y el valor que hay que probar es `"ask"`**: fue pestaña y hoy es pantalla. Un valor
    /// guardado que ya no existe tumbaría el detalle al volver de la muerte del proceso, en el
    /// único camino que nadie recorre a mano. Es la misma lección que `MainTab.restored(from:)`.
    static func restored(from raw: String) -> DetailTab {
        DetailTab(rawValue: raw) ?? .document
    }
}
