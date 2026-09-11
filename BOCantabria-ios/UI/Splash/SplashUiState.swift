//
//  SplashUiState.swift
//  Everything the cover shows at a given moment.
//
//  Los cuatro estados son mutuamente excluyentes por construcción (FR-009).
//
//  **`blocked` es un caso propio y no una bandera dentro de `error`, a propósito.** Un error
//  recuperable ofrece «continuar sin conexión» y un acceso bloqueado **no puede** ofrecerlo,
//  porque saltarse el bloqueo anula su propósito. Con una bandera, la diferencia viviría en un
//  condicional dentro de la vista —que es donde estas cosas se olvidan— y existiría la combinación
//  incoherente «bloqueado pero con salida», que es justo el fallo a impedir.
//

enum SplashUiState: Equatable {
    case preparing
    case ready
    case error(DomainError)
    case blocked(BlockReason)
}

enum BlockReason: Equatable {
    case updateRequired
    case maintenance(String)
}
