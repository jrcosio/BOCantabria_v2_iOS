//
//  HomeUiState.swift
//  The four states of the initial screen.
//
//  Un enumerado y no una estructura con banderas, a propósito (research.md D-105). Una estructura
//  con `isLoading`, `items` y `errorMessage` permite combinaciones imposibles —«cargando y con
//  error a la vez»— y entonces la pantalla tiene que decidir a cuál hace caso. Aquí **los estados
//  imposibles no compilan**, y el `switch` de la vista es exhaustivo.
//

enum HomeUiState: Equatable {
    case loading
    case content([ContentItem])
    case empty
    case error(DomainError)
}
