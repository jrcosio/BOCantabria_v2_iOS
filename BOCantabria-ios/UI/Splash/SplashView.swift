//
//  SplashView.swift
//  The cover screen.
//
//  **El modelo de pantalla no se posee aquí: lo posee la raíz** (`RootView`). Es lo que hace que
//  el arranque no se reinicie ni se duplique al volver de segundo plano (FR-008) y lo que permite
//  que la raíz sepa cuándo conmutar al contenido principal sin que esta vista navegue a ningún
//  sitio.
//

import SwiftUI

struct SplashView: View {
    let viewModel: SplashViewModel

    var body: some View {
        SplashContentView(
            state: viewModel.state,
            onRetry: { Task { await viewModel.onRetry() } },
            onContinueOffline: { viewModel.onContinueOffline() }
        )
        // La barra de estado no se ve durante el arranque, ni aquí ni en la pantalla de
        // lanzamiento del sistema (FR-022 enmendado, research.md D-213). Que sea la misma decisión
        // en los dos sitios es lo que evita un cambio visible justo en la transición.
        .statusBarHidden(true)
        .task { await viewModel.onAppear() }
    }
}
