//
//  ContentView.swift
//  BOCantabria-ios
//
//  ANDAMIAJE PROVISIONAL. Se sustituye por la portada y el armazón de navegación
//  en la feature 001-esqueleto-arquitectura. No añadas lógica aquí: el código de
//  producto solo se escribe desde un tasks.md aprobado (constitución, principio I).
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("BOC Cantabria")
                .font(.title2.weight(.semibold))
            Text("Proyecto inicializado. Pendiente de la feature 001.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
