//
//  BulletinHeaderView.swift
//  The editorial header.
//
//  **La fecha lleva rótulo, y son dos.** Sola no se sabe de qué fecha es, y junto al recuento
//  invita a inventarse la relación entre los dos números. Son dos rótulos porque significa dos
//  cosas distintas: la de la edición publicada en el boletín del día, y la de la publicación más
//  reciente dentro de una sección, que puede ser de hace años.
//
//  **Sin fecha no se pinta ningún rótulo**: un «Edición del» huérfano en la primera ejecución
//  sería peor que la fecha desnuda que vino a sustituir.
//
//  Y **nunca un número de boletín**: el servicio oficial no lo publica en las fuentes que la
//  aplicación consume, y escribirlo junto al escudo sería presentar un dato inventado como
//  oficial. En su sitio va el recuento, que es un dato real.
//

import SwiftUI

struct BulletinHeaderView: View {
    let header: BulletinHeader

    /// Cuánto está encogida, de 0 —entera— a 1 —al mínimo—.
    ///
    /// **Es una cifra continua y no un booleano, y esa es toda la diferencia** (research.md D-418).
    /// Con dos estados, la cabecera no responde al dedo: responde a un umbral, y cambia de golpe
    /// cuando el dedo ya ha hecho otra cosa. Con un recorrido, a cualquier punto intermedio del
    /// desplazamiento le corresponde un tamaño intermedio, y se puede parar a medio camino.
    ///
    /// **La denominación y el recuento se quedan** (FR-011): son la respuesta a «qué estoy viendo»
    /// y «cuánto hay». La fecha rotulada es el único elemento que puede irse sin dejar la cabecera
    /// muda, y es además el más alto de los tres.
    ///
    /// **Lo que NO cambia es el peldaño de la denominación, ni su número de líneas.** Bajarla de
    /// `headlineLarge` a `headlineSmall` ahorraría ocho puntos más, y pasarla de dos líneas a una
    /// ahorraría otros treinta y ocho. Las dos cosas **saltan**: SwiftUI no interpola tamaños de
    /// fuente ni recuentos de línea, los resuelve con un fundido. Lo que sí se interpola es una
    /// altura, y por eso lo único que encoge es el relleno y la fecha.
    var collapse: CGFloat = 0

    /// Cuánto alto puede liberar esta cabecera, publicado hacia arriba.
    ///
    /// Quien desplaza necesita el dato para dos cosas: saber en cuántos puntos de recorrido se
    /// completa el colapso —que es lo que hace que siga al dedo **1:1**— y devolverle al contenido
    /// exactamente lo que la cabecera libera. **Se mide, no se escribe**: las fuentes escalan con
    /// el ajuste del dispositivo, así que a doscientos por ciento el alto de la fecha es otro.
    var onCollapsibleHeight: (CGFloat) -> Void = { _ in }

    /// El alto natural de la **fila** de la fecha rotulada —su separación superior incluida—,
    /// medido con el texto del dispositivo.
    ///
    /// Se mide la fila entera y no solo el texto: forzar el alto del texto sin contar su
    /// separación **la recorta**, y la cabecera encoge ocho puntos de más nada más aparecer. Es el
    /// primer defecto que destapó la instrumentación.
    @State private var dateRowHeight: CGFloat = 0

    /// El recorrido: lo que se gana de relleno —arriba y abajo— más la fila de la fecha.
    private var collapsibleHeight: CGFloat {
        guard dateRowHeight > 0 else { return 0 }
        return (BocTheme.spacing.lg - BocTheme.spacing.sm) * 2 + dateRowHeight
    }

    private var labelledDate: String? {
        BocDateFormatting.labelled(header.date, meaning: header.dateMeaning)
    }

    var body: some View {
        HStack(alignment: .top, spacing: BocTheme.spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                Text(header.title)
                    .bocTextStyle(BocTheme.typography.headlineLarge)
                    .foregroundStyle(BocTheme.colors.onPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // **Solo se retira del árbol al final del recorrido**, cuando ya es invisible. Así
                // la transición es continua y `home_header_date` sigue desapareciendo de verdad,
                // que es lo que tres pruebas de interfaz afirman. Retirarla a mitad de camino era
                // una de las cuatro causas del salto.
                if collapse < 1, let labelled = labelledDate {
                    Text(labelled)
                        .bocTextStyle(BocTheme.typography.bodyLarge)
                        .foregroundStyle(BocTheme.colors.onPrimaryMuted)
                        .accessibilityIdentifier("home_header_date")
                        // La separación va **dentro** de lo que se mide y de lo que se recorta:
                        // fuera, el recorte se la comería y la cabecera perdería ocho puntos de
                        // golpe nada más aparecer.
                        .padding(.top, BocTheme.spacing.xs)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            // Solo con la cabecera entera: a medio camino el alto ya está
                            // recortado y mediría el recorte, no el natural.
                            if collapse == 0, height > 0 { dateRowHeight = height }
                        }
                        .frame(
                            height: dateRowHeight > 0 ? dateRowHeight * (1 - collapse) : nil,
                            alignment: .top
                        )
                        .opacity(1 - collapse)
                        .clipped()
                }
            }

            Spacer(minLength: 0)

            Text(BocDateFormatting.publicationCount(header.count))
                .bocTextStyle(BocTheme.typography.labelLarge)
                .foregroundStyle(BocTheme.colors.onPrimary)
                .padding(.horizontal, BocTheme.spacing.sm)
                .padding(.vertical, BocTheme.spacing.xs)
                .overlay(
                    Capsule().stroke(BocTheme.colors.onPrimaryMuted, lineWidth: 1)
                )
                .accessibilityIdentifier("home_header_count")
        }
        .padding(.horizontal, BocTheme.spacing.lg)
        .padding(
            .vertical,
            BocTheme.spacing.lg - (BocTheme.spacing.lg - BocTheme.spacing.sm) * collapse
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BocTheme.colors.primary)
        // **Sin `.animation(_:value:)`, y es deliberado** (research.md D-411, enmendada). Con un
        // valor continuo, una animación implícita hace que la cabecera vaya por detrás del dedo:
        // rebota y se arrastra, que es otra forma de la misma queja. El gesto **es** la animación.
        //
        // `.contain` es obligatorio: sin él, este identificador se propaga a los tres hijos y les
        // machaca el suyo. El volcado del árbol mostraba tres elementos llamados `home_header` y
        // ni rastro de `home_header_date` ni de `home_header_count`.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_header")
        .onChange(of: collapsibleHeight, initial: true) { _, height in
            onCollapsibleHeight(height)
        }
    }
}

#Preview("Boletín del día") {
    BulletinHeaderView(
        header: BulletinHeader(
            title: "Boletín de hoy",
            date: BocDate(iso: "2026-08-27"),
            count: 48,
            dateMeaning: .edition
        )
    )
}

#Preview("Una sección que no publica desde 2021") {
    BulletinHeaderView(
        header: BulletinHeader(
            title: "Actuaciones en materia de Seguridad Social",
            date: BocDate(iso: "2021-03-26"),
            count: 9,
            dateMeaning: .latestInSection
        )
    )
}

#Preview("Sin fecha todavía") {
    BulletinHeaderView(
        header: BulletinHeader(title: "Boletín de hoy", date: nil, count: 0, dateMeaning: .edition)
    )
}

#Preview("A medio camino") {
    // **Lo que hasta la 004 no se podía revisar sin arrancar la aplicación**: con un mecanismo de
    // dos estados, este fotograma no existía.
    BulletinHeaderView(
        header: BulletinHeader(
            title: "Boletín de hoy",
            date: BocDate(iso: "2026-08-27"),
            count: 48,
            dateMeaning: .edition
        ),
        collapse: 0.5
    )
}

#Preview("Al final del recorrido") {
    // Sin fecha rotulada y con la mitad de relleno. La denominación y el recuento siguen, que es
    // lo que dice qué se está mirando (FR-011).
    BulletinHeaderView(
        header: BulletinHeader(
            title: "Boletín de hoy",
            date: BocDate(iso: "2026-08-27"),
            count: 48,
            dateMeaning: .edition
        ),
        collapse: 1
    )
}

#Preview("Al final, con una denominación larga") {
    BulletinHeaderView(
        header: BulletinHeader(
            title: "Actuaciones en materia de Seguridad Social",
            date: BocDate(iso: "2021-03-26"),
            count: 9,
            dateMeaning: .latestInSection
        ),
        collapse: 1
    )
}
