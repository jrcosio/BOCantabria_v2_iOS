//
//  PublicationCard.swift
//  The central component of the application.
//
//  Vive en `Core/UI/Component` y no en `UI/Home` porque la van a usar tres pantallas: Inicio,
//  Guardados y Buscar. Es **sin estado**: recibe la publicación y dos cierres, y no sabe de dónde
//  sale ni qué pasa después.
//
//  El orden de lectura es el del apartado 12.1 del documento de diseño y no es negociable:
//  organismo, título, fecha, acciones. Y **el indicador de color va siempre acompañado de texto**
//  (FR-040): el color agrupa nueve secciones en cinco, así que por sí solo no identifica nada.
//

import SwiftUI

struct PublicationCard: View {
    let publication: Publication
    var onShare: (() -> Void)?
    var onSave: (() -> Void)?

    private var section: BocSection? {
        BocSection.named(publication.mostSpecificSectionCode)
    }

    var body: some View {
        HStack(alignment: .top, spacing: BocTheme.spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sectionColor)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BocTheme.spacing.xxs) {
                sectionLabel
                organisation
                title
                date
                actions
            }
        }
        .padding(BocTheme.spacing.md)
        .background(BocTheme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.medium))
        .shadow(color: .black.opacity(0.06), radius: BocTheme.elevation.level1, y: 1)
        .accessibilityElement(children: .combine)
    }

    private var sectionLabel: some View {
        Text(Strings.Card.section(section?.shortName ?? publication.mostSpecificSectionCode))
            .bocTextStyle(BocTheme.typography.labelSmall)
            .foregroundStyle(sectionColor)
    }

    @ViewBuilder
    private var organisation: some View {
        if let issuer = publication.issuer {
            Text(issuer)
                .bocTextStyle(BocTheme.typography.labelMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)
                .lineLimit(2)
        }
    }

    private var title: some View {
        Text(publication.title)
            .bocTextStyle(BocTheme.typography.titleMedium)
            .foregroundStyle(BocTheme.colors.textPrimary)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var date: some View {
        HStack(spacing: BocTheme.spacing.xxs) {
            Image(.icCalendar)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(BocDateFormatting.long(publication.publicationDate))
                .bocTextStyle(BocTheme.typography.bodySmall)
        }
        .foregroundStyle(BocTheme.colors.textSecondary)
        .padding(.top, BocTheme.spacing.xxs)
    }

    private var actions: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            Spacer()
            action(.icShare, label: Strings.Card.share, identifier: "publication_share") {
                onShare?()
            }
            action(.icBookmark, label: Strings.Card.save, identifier: "publication_save") {
                onSave?()
            }
        }
        .padding(.top, BocTheme.spacing.xxs)
    }

    private func action(
        _ icon: ImageResource,
        label: LocalizedStringResource,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                // Área táctil de 48 pt, aunque el icono mida 24 (documento de diseño §12.1).
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BocTheme.colors.textSecondary)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    private var sectionColor: Color {
        switch section?.colorGroup {
        case .general: BocTheme.colors.sectionGeneral
        case .personnel: BocTheme.colors.sectionPersonnel
        case .contracting: BocTheme.colors.sectionContracting
        case .economy: BocTheme.colors.sectionEconomy
        case .announcements: BocTheme.colors.sectionAnnouncements
        case nil: BocTheme.colors.outline
        }
    }
}
