//
//  MetadataCard.swift
//  The six blocks of the document tab (§19.2).
//
//  El orden es el del documento de diseño y no se negocia: descripción, organismo, sección, fecha
//  de publicación, referencia y documento oficial. Etiquetas en `labelMedium`, valores en
//  `bodyLarge`.
//
//  **No hay bloques de texto extraído**, y no es un olvido: del servicio no llega texto, llega el
//  enlace a un documento. El modo lectura del §19.3 queda para cuando exista esa extracción.
//

import SwiftUI

struct MetadataCard: View {
    let publication: Publication
    let sectionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.md) {
            block(Strings.Detail.fieldDescription, publication.title)
            if let issuer = publication.issuer {
                block(Strings.Detail.fieldIssuer, issuer)
            }
            block(Strings.Detail.fieldSection, sectionName)
            block(Strings.Detail.fieldDate, BocDateFormatting.long(publication.publicationDate))
            block(Strings.Detail.fieldReference, publication.externalKey)
            block(Strings.Detail.fieldOfficial, String(localized: editionLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BocTheme.spacing.md)
        .background(BocTheme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.medium))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail_metadata")
    }

    private var editionLabel: LocalizedStringResource {
        switch publication.editionType {
        case .ordinary: Strings.Detail.editionOrdinary
        case .extraordinary: Strings.Detail.editionExtraordinary
        case .unknown: Strings.Detail.editionUnknown
        }
    }

    private func block(_ label: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: BocTheme.spacing.xxs) {
            Text(label)
                .bocTextStyle(BocTheme.typography.labelMedium)
                .foregroundStyle(BocTheme.colors.textSecondary)
            Text(value)
                .bocTextStyle(BocTheme.typography.bodyLarge)
                .foregroundStyle(BocTheme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
