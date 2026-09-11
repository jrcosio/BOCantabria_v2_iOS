//
//  StartupScenario.swift
//  The startup scenarios a UI test can ask the application to launch into.
//
//  **Es una costura en código de producción, y se mantiene acotada.** Existe porque una prueba de
//  interfaz corre en otro proceso y no puede sustituir nada por dentro: el único mecanismo de esta
//  plataforma son los argumentos de lanzamiento. Sin ella, tres de los cuatro estados del arranque
//  —sin conexión, versión obsoleta y mantenimiento— no serían alcanzables desde una prueba
//  automática, y son justo los que nadie mira hasta que fallan (research.md D-212).
//
//  Es un enumerado y no una cadena para que una errata sea un error de compilación de este lado.
//

enum StartupScenario: String, Sendable, CaseIterable {
    /// Preparación correcta. Es el valor por defecto y el de producción.
    case ready
    /// Sin conexión: error recuperable con sus dos salidas.
    case offline
    /// Versión instalada por debajo de la mínima soportada.
    case updateRequired
    /// Mensaje de mantenimiento publicado.
    case maintenance
    /// Preparación que no responde, para ver el estado de carga y el límite de espera.
    case slow
}
