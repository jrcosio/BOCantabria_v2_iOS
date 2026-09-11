//
//  ConnectivityRepository.swift
//  Whether the device has a usable network path.
//
//  **Léase esto antes de apoyarse en él.** Dice si hay camino de red, **no si hay internet**: un
//  portal cautivo de hotel responde que sí. Por eso la comprobación que manda en el arranque es
//  que la configuración remota se obtenga, y esto solo elige **cuál de los dos mensajes de error**
//  se muestra. Usarlo para decidir si merece la pena intentar una petición sería escribir un fallo
//  que solo aparece en hoteles y aeropuertos.
//

protocol ConnectivityRepository: Sendable {
    func isOnline() async -> Bool
}
