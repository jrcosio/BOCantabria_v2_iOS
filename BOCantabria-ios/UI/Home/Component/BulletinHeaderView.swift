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

    var body: some View {
        HStack(alignment: .top, spacing: BocTheme.spacing.md) {
            VStack(alignment: .leading, spacing: BocTheme.spacing.xs) {
                Text(header.title)
                    .bocTextStyle(BocTheme.typography.headlineLarge)
                    .foregroundStyle(BocTheme.colors.onPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let labelled = BocDateFormatting.labelled(header.date, meaning: header.dateMeaning) {
                    Text(labelled)
                        .bocTextStyle(BocTheme.typography.bodyLarge)
                        .foregroundStyle(BocTheme.colors.onPrimaryMuted)
                        .accessibilityIdentifier("home_header_date")
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
        .padding(BocTheme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BocTheme.colors.primary)
        // `.contain` es obligatorio: sin él, este identificador se propaga a los tres hijos y les
        // machaca el suyo. El volcado del árbol mostraba tres elementos llamados `home_header` y
        // ni rastro de `home_header_date` ni de `home_header_count`.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_header")
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
