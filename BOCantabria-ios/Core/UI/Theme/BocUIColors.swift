//
//  BocUIColors.swift
//  The handful of tokens that UIKit interoperation needs.
//
//  **Existe para obedecer a la regla 7, no para rodearla.** Esa regla falla la build si alguien
//  construye un color fuera de `Core/UI/Theme/`, y la vista que envuelve al visor de documentos
//  necesita darle a su propiedad de fondo un color **de UIKit**, no de SwiftUI. La salida correcta
//  es poner la construcción donde la regla la permite (research.md D-522).
//
//  La incorrecta, y es la tentadora: dejar el fondo transparente. Compila, pasa todas las pruebas,
//  y el visor pinta sobre el fondo que le toque, incumpliendo el apartado 24.2 del documento de
//  diseño **en silencio**.
//
//  **La lista es corta a propósito.** Solo entra un color cuando una API de UIKit lo exige. No es
//  una segunda paleta: es la misma, traducida en el único sitio donde se puede.
//

import UIKit

enum BocUIColors {
    /// El gris neutro sobre el que se lee el documento (§24.2, `#D9DEE2`).
    ///
    /// Es el gemelo de `BocTheme.colors.readerSurface`, y hay una prueba que afirma que los dos
    /// valen lo mismo: dos definiciones del mismo color se separan en cuanto alguien retoca una.
    static let readerSurface = UIColor(red: 0xD9 / 255, green: 0xDE / 255, blue: 0xE2 / 255, alpha: 1)
}
