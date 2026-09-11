//
//  BocTheme.swift
//  The single entry point to the design system.
//
//  Son constantes estáticas, no un canal del entorno, y es deliberado (research.md D-106). La
//  aplicación tiene **un único tema inmutable**: no hay nada que propagar, así que no hay nada que
//  olvidar y no hay nada que sustituir a mitad del árbol de vistas. Una vista previa funciona sin
//  envolver nada.
//
//  **No hay variante oscura y no debe haberla.** El mecanismo no está puesto a un valor seguro:
//  no existe. La apariencia clara la fija además el proyecto con `UIUserInterfaceStyle = Light`.
//

enum BocTheme {
    static let colors = BocColors.boc
    static let typography = BocTypography.boc
    static let spacing = BocSpacing.boc
    static let shape = BocShape.boc
    static let elevation = BocElevation.boc
}
