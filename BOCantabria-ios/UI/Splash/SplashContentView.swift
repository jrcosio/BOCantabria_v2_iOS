//
//  SplashContentView.swift
//  The stateless rendering of the cover.
//
//  **No conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que las vistas
//  previas recorren los cuatro estados sin arrancar el grafo.
//
//  La composición es la del apartado 13 del documento de diseño y la de
//  `contracts/internal-contracts.md` §6. Ni un color, ni un tamaño, ni un espaciado escritos a
//  mano: todo sale de `BocTheme`.
//

import SwiftUI

struct SplashContentView: View {
    let state: SplashUiState
    let onRetry: () -> Void
    let onContinueOffline: () -> Void

    var body: some View {

        ZStack {
            BocTheme.colors.primary
                .ignoresSafeArea()

            identity

            VStack {
                Spacer()
                authorship
                bottomSlot
            }
            .padding(.bottom, BocTheme.spacing.xl)
        }
        // Sin esto el contenedor **no aparece en el árbol de accesibilidad**: SwiftUI expone las
        // hojas, y un `ZStack` con un color y dos pilas dentro no es una. La prueba de interfaz
        // buscaba `splash_root` y no lo encontraba, con la portada delante de los ojos.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splash_root")
    }

    /// El escudo y el nombre del boletín, como bloque centrado.
    ///
    /// **Se dibuja `ic_escudo_cantabria`, no `ic_launch_emblem`.** Aquel lleva relleno
    /// transparente dentro del lienzo para que el sistema lo centre donde toca en la pantalla de
    /// lanzamiento; dibujarlo aquí con una altura de 104 encogería el escudo a la tercera parte,
    /// porque los 104 se los llevaría el lienzo entero.
    ///
    /// El bloque va centrado, que es lo que muestra la imagen de referencia. **De dónde cae el
    /// escudo con ese centrado sale el desplazamiento del recurso del lanzamiento**, y no al
    /// revés: se mide sobre una captura y se regenera el recurso (research.md D-203).
    private var identity: some View {
        VStack(spacing: 0) {
            Image(.icEscudoCantabria)
                .resizable()
                .scaledToFit()
                .frame(height: Self.emblemHeight)
                .accessibilityIdentifier("splash_emblem")
                .accessibilityLabel(Text(Strings.Splash.titleLineOne))

            Text(Strings.Splash.acronym)
                .bocTextStyle(BocTheme.typography.displayLarge)
                .foregroundStyle(BocTheme.colors.onPrimary)
                .padding(.top, BocTheme.spacing.lg)

            VStack(spacing: 0) {
                Text(Strings.Splash.titleLineOne)
                Text(Strings.Splash.titleLineTwo)
            }
            .bocTextStyle(BocTheme.typography.splash.subtitle)
            .foregroundStyle(BocTheme.colors.onPrimary)
            .multilineTextAlignment(.center)

            Rectangle()
                .fill(BocTheme.colors.onPrimaryAccent)
                .frame(width: Self.dividerWidth, height: Self.dividerHeight)
                .padding(.top, BocTheme.spacing.lg)
        }
        .padding(.horizontal, BocTheme.spacing.screenMargin)
    }

    private var authorship: some View {
        VStack(spacing: BocTheme.spacing.xxs) {
            Text(Strings.Splash.authorshipLabel)
                .bocTextStyle(BocTheme.typography.splash.authorshipLabel)
                .foregroundStyle(BocTheme.colors.onPrimaryMuted)
            Text(Strings.Splash.authorshipName)
                .bocTextStyle(BocTheme.typography.splash.authorshipName)
                .foregroundStyle(BocTheme.colors.onPrimaryAccent)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, BocTheme.spacing.screenMargin)
    }

    /// Lo que cambia con el estado va abajo, bajo la autoría, que es donde la imagen de referencia
    /// pone el indicador.
    @ViewBuilder
    private var bottomSlot: some View {
        switch state {
        case .preparing, .ready:
            ProgressView()
                .tint(BocTheme.colors.onPrimaryAccent)
                .padding(.top, BocTheme.spacing.md)
                .accessibilityIdentifier("splash_loading")
                .accessibilityLabel(Text(Strings.Splash.loadingDescription))

        case let .error(error):
            recoverableError(error)

        case let .blocked(reason):
            blocked(reason)
        }
    }

    /// El acceso bloqueado. **Solo reintentar** (FR-012, FR-013).
    ///
    /// No hay «continuar sin conexión» aquí, y no es que esté oculto: el estado es un caso propio
    /// y esta rama no lo dibuja. Saltarse el bloqueo anula su propósito.
    private func blocked(_ reason: BlockReason) -> some View {
        VStack(spacing: BocTheme.spacing.sm) {
            Text(blockedTitle(reason))
                .bocTextStyle(BocTheme.typography.titleMedium)
                .foregroundStyle(BocTheme.colors.onPrimary)

            blockedMessage(reason)
                .bocTextStyle(BocTheme.typography.bodyMedium)
                .foregroundStyle(BocTheme.colors.onPrimaryMuted)

            Button(action: onRetry) {
                Text(Strings.Action.retry)
                    .bocTextStyle(BocTheme.typography.labelLarge)
                    .padding(.horizontal, BocTheme.spacing.lg)
                    .padding(.vertical, BocTheme.spacing.sm)
            }
            .buttonStyle(BocOnPrimaryButtonStyle())
            .accessibilityIdentifier("splash_retry")
            .padding(.top, BocTheme.spacing.xs)
        }
        .multilineTextAlignment(.center)
        .padding(.top, BocTheme.spacing.lg)
        .padding(.horizontal, BocTheme.spacing.screenMargin)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splash_blocked")
    }

    private func blockedTitle(_ reason: BlockReason) -> LocalizedStringResource {
        switch reason {
        case .updateRequired: Strings.Splash.updateRequiredTitle
        case .maintenance: Strings.Splash.maintenanceTitle
        }
    }

    /// El mensaje de mantenimiento es **el que publica el servicio**, no una cadena nuestra: es
    /// justamente lo que permite avisar de una incidencia sin publicar una versión.
    @ViewBuilder
    private func blockedMessage(_ reason: BlockReason) -> some View {
        switch reason {
        case .updateRequired: Text(Strings.Splash.updateRequiredMessage)
        case let .maintenance(message): Text(message)
        }
    }

    /// El error recuperable, con sus **dos** salidas (FR-010).
    ///
    /// El error de dominio no se pinta: la pantalla nunca dice códigos. Lo único que cambia con él
    /// es cuál de los dos mensajes se muestra, y el detalle vive en el registro.
    private func recoverableError(_ error: DomainError) -> some View {
        VStack(spacing: BocTheme.spacing.sm) {
            Text(Strings.Splash.errorTitle)
                .bocTextStyle(BocTheme.typography.titleMedium)
                .foregroundStyle(BocTheme.colors.onPrimary)

            Text(error == .network ? Strings.Splash.errorNetwork : Strings.Splash.errorUnknown)
                .bocTextStyle(BocTheme.typography.bodyMedium)
                .foregroundStyle(BocTheme.colors.onPrimaryMuted)

            HStack(spacing: BocTheme.spacing.sm) {
                Button(action: onRetry) {
                    Text(Strings.Action.retry)
                        .bocTextStyle(BocTheme.typography.labelLarge)
                        .padding(.horizontal, BocTheme.spacing.lg)
                        .padding(.vertical, BocTheme.spacing.sm)
                }
                .buttonStyle(BocOnPrimaryButtonStyle())
                .accessibilityIdentifier("splash_retry")

                Button(action: onContinueOffline) {
                    Text(Strings.Splash.continueOffline)
                        .bocTextStyle(BocTheme.typography.labelLarge)
                        .foregroundStyle(BocTheme.colors.onPrimaryAccent)
                        .padding(.horizontal, BocTheme.spacing.lg)
                        .padding(.vertical, BocTheme.spacing.sm)
                }
                .accessibilityIdentifier("splash_continue_offline")
            }
            .padding(.top, BocTheme.spacing.xs)
        }
        .multilineTextAlignment(.center)
        .padding(.top, BocTheme.spacing.lg)
        .padding(.horizontal, BocTheme.spacing.screenMargin)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splash_error")
    }

    // Las tres medidas del apartado 13.2 que no son un espaciado de la escala. Viven aquí como
    // constantes con nombre y no sueltas dentro del `body`; el desplazamiento, además, tiene que
    // seguir coincidiendo con el del recurso del lanzamiento.
    /// Los 104 pt del §13.2 son el **escudo visible**, no el lienzo del recurso: su `viewBox`
    /// lleva 2,97 unidades de relleno arriba y abajo sobre un alto de 137, así que el marco tiene
    /// que ser un 4,5 % mayor. Medido sobre una captura (quickstart, paso 8a), no estimado: enmarcar
    /// a 104 a secas deja el escudo en 99,5 y nadie sabría por qué.
    private static let emblemHeight: CGFloat = 104 * 137 / 131.06
    private static let dividerWidth: CGFloat = 120
    private static let dividerHeight: CGFloat = 2
}

#Preview("Preparando") {
    SplashContentView(state: .preparing, onRetry: {}, onContinueOffline: {})
}

#Preview("Error recuperable") {
    SplashContentView(state: .error(.network), onRetry: {}, onContinueOffline: {})
}

#Preview("Versión obsoleta") {
    SplashContentView(state: .blocked(.updateRequired), onRetry: {}, onContinueOffline: {})
}

#Preview("Mantenimiento") {
    SplashContentView(
        state: .blocked(.maintenance("Estamos actualizando el servicio. Vuelve en unos minutos.")),
        onRetry: {},
        onContinueOffline: {}
    )
}
