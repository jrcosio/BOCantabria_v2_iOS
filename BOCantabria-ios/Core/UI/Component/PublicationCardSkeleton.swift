//
//  PublicationCardSkeleton.swift
//  A placeholder with the shape of the card that is coming.
//
//  **Anima sin fin por diseño**, y eso tiene una consecuencia que hay que saber: una espera de
//  prueba de interfaz que exija que la interfaz llegue a reposo **se cuelga en lugar de fallar**.
//  Las pruebas sobre el estado de carga esperan por existencia (research.md D-328).
//

import SwiftUI

struct PublicationCardSkeleton: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.xs) {
            bar(widthFactor: 0.45, height: 12)
            bar(widthFactor: 0.95, height: 16)
            bar(widthFactor: 0.75, height: 16)
            bar(widthFactor: 0.30, height: 12)
        }
        .padding(BocTheme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BocTheme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.medium))
        .opacity(isPulsing ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { isPulsing = true }
        .accessibilityHidden(true)
    }

    private func bar(widthFactor: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: BocTheme.shape.extraSmall)
                .fill(BocTheme.colors.surfaceStrong)
                .frame(width: proxy.size.width * widthFactor, height: height)
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: BocTheme.spacing.sm) {
        PublicationCardSkeleton()
        PublicationCardSkeleton()
    }
    .padding()
    .background(BocTheme.colors.background)
}
