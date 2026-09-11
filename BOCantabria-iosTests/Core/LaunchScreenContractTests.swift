//
//  LaunchScreenContractTests.swift
//  The launch screen is configuration, and configuration rots in silence.
//
//  Lo que aquí se comprueba no lo mira ningún compilador: si alguien vuelve a activar la
//  generación automática, o renombra el recurso del escudo, la aplicación **sigue compilando** y
//  el destello blanco vuelve. Se vería en un vídeo del arranque, mirándolo despacio, y no antes.
//

import Foundation
import Testing

@testable import BOCantabria_ios

@Suite("Contrato de la pantalla de lanzamiento")
struct LaunchScreenContractTests {

    /// El proceso de pruebas unitarias lo hospeda la aplicación, así que el paquete principal es
    /// el suyo y su `Info.plist` es el compilado de verdad, no el fuente.
    private var launchScreen: [String: Any]? {
        Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any]
    }

    @Test("El lanzamiento pinta el azul institucional, no el fondo por defecto")
    func launchScreenUsesTheInstitutionalBlue() throws {
        let dictionary = try #require(launchScreen, "Sin UILaunchScreen vuelve el destello blanco.")
        #expect(dictionary["UIColorName"] as? String == "AccentColor")
    }

    @Test("El lanzamiento pinta el escudo, y es el recurso con el desplazamiento dentro")
    func launchScreenShowsTheEmblem() throws {
        // No vale `ic_escudo_cantabria` ni `ic_splash_emblem`: el primero se dibuja a 32 pt y el
        // segundo es el icono de arranque de la otra plataforma, con el escudo a 192. Solo
        // `ic_launch_emblem` cae donde la portada lo dibuja (research.md D-203).
        let dictionary = try #require(launchScreen)
        #expect(dictionary["UIImageName"] as? String == "ic_launch_emblem")
    }

    @Test("La barra de estado está oculta desde el primer fotograma")
    func statusBarIsHiddenFromTheFirstFrame() {
        // Si esto se pusiera a falso, la barra aparecería durante el lanzamiento y desaparecería
        // al entrar la portada: un cambio visible justo en la transición que FR-002 protege.
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIStatusBarHidden") as? Bool == true)
    }
}
