//
//  DetailHeader.swift
//  The document's header: five elements, in an order that is a requirement.
//
//  **Sección, TÍTULO, organismo, fecha, distintivo** (FR-007). Al revés que la tarjeta de Inicio,
//  que desde la feature anterior pone el organismo antes del título, y el porqué de que diverjan
//  está escrito: en un listado el organismo permite descartar sin leer; aquí ya se ha decidido
//  leer, y **el título es el contenido**.
//
//  **Y el título va íntegro**, con su prefijo del organismo si lo trae. En la tarjeta se recorta
//  porque la línea de encima ya lo dice; aquí el organismo va **debajo**, y además esto es el
//  documento, no un resumen (FR-008).
//

import SwiftUI

struct DetailHeader: View {
    let publication: Publication
    let sectionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.sm) {
            Text(Strings.Card.section(sectionName))
                .bocTextStyle(BocTheme.typography.labelLarge)
                .foregroundStyle(BocTheme.colors.primary)
                .accessibilityIdentifier("detail_section")

            // `headlineSmall` y no `headlineLarge`: a treinta puntos, un título real del BOC —los
            // hay de ciento treinta caracteres— llena seis líneas y deja la ficha en una franja.
            // **Completo y sin recortar**: nada de `lineLimit`.
            Text(publication.title)
                .bocTextStyle(BocTheme.typography.headlineSmall)
                .foregroundStyle(BocTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("detail_title")

            // **Sin hueco cuando no hay organismo** (FR-010): el campo es opcional y hay anuncios
            // de los que no se deduce.
            if let issuer = publication.issuer {
                metadataLine(
                    icon: .icOrganization,
                    description: Strings.Detail.issuerDescription,
                    value: issuer,
                    id: "detail_issuer"
                )
            }

            metadataLine(
                icon: .icCalendar,
                description: Strings.Detail.dateDescription,
                value: BocDateFormatting.long(publication.publicationDate),
                id: "detail_date"
            )

            officialBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BocTheme.spacing.ml)
        .padding(.vertical, BocTheme.spacing.lg)
        .background(BocTheme.colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_header")
    }

    /// El organismo y la fecha, **cada uno con su icono** (FR-009).
    ///
    /// El icono lleva la descripción accesible y el valor va aparte: un lector de pantalla que
    /// dijera solo «Consejería de Salud» no diría de qué es ese nombre.
    private func metadataLine(
        icon: ImageResource,
        description: LocalizedStringResource,
        value: String,
        id: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BocTheme.spacing.xs) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(BocTheme.colors.textSecondary)
                .accessibilityHidden(true)
            Text(value)
                .bocTextStyle(BocTheme.typography.bodyLarge)
                .foregroundStyle(BocTheme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(String(localized: description)): \(value)"))
        .accessibilityIdentifier(id)
    }

    /// Distintivo perfilado, **no relleno** (§18.2): dice que el documento es oficial, no que haya
    /// que hacer nada con él.
    private var officialBadge: some View {
        HStack(spacing: BocTheme.spacing.xxs) {
            Image(.icOfficial)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(Strings.Detail.officialBadge)
                .bocTextStyle(BocTheme.typography.labelMedium)
        }
        .foregroundStyle(BocTheme.colors.accentOfficial)
        .padding(.horizontal, BocTheme.spacing.sm)
        .padding(.vertical, BocTheme.spacing.xxs)
        .overlay(
            BocTheme.shape.chip.stroke(BocTheme.colors.accentOfficial, lineWidth: 1)
        )
        .padding(.top, BocTheme.spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail_official_badge")
    }
}
