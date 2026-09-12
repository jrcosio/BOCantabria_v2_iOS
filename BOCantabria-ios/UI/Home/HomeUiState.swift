//
//  HomeUiState.swift
//  Everything the initial screen draws, in one immutable value.
//
//  El contenido es un enumerado y no una estructura con banderas, a propósito (research.md D-105):
//  una estructura con `isLoading`, `items` y `errorMessage` permite combinaciones imposibles
//  —«cargando y con error a la vez»— y entonces la pantalla tiene que decidir a cuál hace caso.
//
//  Pero **`isRefreshing` e `isOffline` sí son banderas**, y también a propósito. Son ejes
//  independientes del contenido: se puede estar actualizando con contenido a la vista, y se puede
//  estar sin conexión con contenido a la vista. Meterlos en el enumerado daría doce estados que
//  nadie sabe leer.
//

struct HomeUiState: Equatable {
    var selection: HomeSelection = .todaysBulletin
    var header: BulletinHeader?
    var sectionChips: [SectionChip] = []
    /// Vacía cuando la selección no tiene subsecciones. Entonces la fila **no existe** (FR-052).
    var subsectionChips: [SectionChip] = []
    var content: HomeContent = .skeleton
    /// Hay una actualización en curso. El contenido **permanece visible** mientras dura (FR-026).
    var isRefreshing: Bool = false
    /// No hay conexión. El aviso **no oculta el contenido** (FR-043).
    var isOffline: Bool = false
    /// Qué se ha decidido compartir, y por qué.
    ///
    /// **Gana un campo, y el plan decía que no lo ganaría.** Aquella previsión suponía que la
    /// tarjeta derivaría su destino de `isOffline` y lo llevaría dentro; al implementarlo se vio
    /// que decidir entre documento y enlace exige el caso de uso —que puede tener que descargar—,
    /// y una vista sin estado no puede llamarlo. Así que la tarjeta emite el evento y esta
    /// pantalla resuelve, exactamente igual que el detalle: es lo que hace que FR-038 se cumpla
    /// por construcción (research.md D-518, corregida al implementar).
    var share: ShareState = .idle

    var hasSubsectionRow: Bool { !subsectionChips.isEmpty }
}

enum HomeContent: Equatable {
    /// Primera carga con la base vacía. Marcadores con la forma del contenido final, **cinco como
    /// máximo**, nunca un indicador giratorio grande (FR-041).
    case skeleton
    case publications([Publication])
    /// La selección no tiene publicaciones. **No es un error** (FR-042).
    case empty
    /// No hay nada que mostrar **y** la sincronización falló.
    case error(DomainError)
}

/// Un chip de cualquiera de las dos filas.
struct SectionChip: Equatable, Identifiable {
    /// `today` para el primero; el código de la sección o subsección para los demás.
    let code: String
    let title: String

    var id: String { code }

    static let todayCode = "today"
}
