//
//  PublicationCard.swift
//  The central component of the application.
//
//  Vive en `Core/UI/Component` y no en `UI/Home` porque la van a usar tres pantallas: Inicio,
//  Guardados y Buscar. Es **sin estado**: recibe la publicación y dos cierres, y no sabe de dónde
//  sale ni qué pasa después.
//
//  El orden de lectura es el del apartado 12.1 del documento de diseño y no es negociable:
//  sección, organismo, título, y la fecha compartiendo fila con las acciones. Y **el indicador de
//  color va siempre acompañado de texto** (FR-040): el color agrupa nueve secciones en cinco, así
//  que por sí solo no identifica nada.
//
//  **Los cuatro datos tienen que distinguirse por tamaño** (FR-001), y no basta con declararlo:
//  los cuatro peldaños viven en `PublicationCard.Typography`, al final del fichero, porque es lo
//  único que permite afirmarlos desde una prueba. La tarjeta se combina en un solo elemento de
//  accesibilidad y sus textos no existen en el árbol.
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
                dateAndActions
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
            .bocTextStyle(Typography.section)
            .foregroundStyle(sectionColor)
    }

    /// Quién publica, que es la mitad de la decisión de leer o no.
    ///
    /// **Las mayúsculas son de presentación, no de dato**: `.textCase(.uppercase)` y nunca
    /// `issuer.uppercased()`. Lo almacenado no cambia, y por eso compartir y la futura búsqueda
    /// siguen viendo el texto original.
    ///
    /// Y por eso mismo **declara su propia etiqueta de accesibilidad con la caja original**: una
    /// caja alta es una decisión visual y lo que se oye no debería depender de ella. Hay
    /// organismos de setenta caracteres y los hay que son siglas (research.md D-402).
    ///
    /// **Un organismo ausente no deja hueco** (FR-007): el campo es opcional y hay anuncios de los
    /// que no se deduce.
    @ViewBuilder
    private var organisation: some View {
        if let issuer = publication.issuer {
            Text(issuer)
                .textCase(.uppercase)
                .bocTextStyle(Typography.organisation)
                .foregroundStyle(BocTheme.colors.textPrimary)
                .lineLimit(2)
                .accessibilityLabel(Text(issuer))
        }
    }

    /// El título, **sin repetir el organismo** que la línea de arriba ya dice.
    ///
    /// El color se queda en `textPrimary`, decidido con el propietario: en la captura se lee
    /// azulado, pero es efecto del tamaño y manda el apartado 12.1.
    private var title: some View {
        Text(publication.titleWithoutIssuer)
            .bocTextStyle(Typography.title)
            .foregroundStyle(BocTheme.colors.textPrimary)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// La fecha y las dos acciones **comparten fila**, y se apilan cuando no caben (FR-004,
    /// FR-005).
    ///
    /// **La trampa que hay que conocer para leer esto**: `ViewThatFits` mide el tamaño **ideal** de
    /// cada candidato. Un `Spacer()` sin longitud mínima tiene un ideal minúsculo, así que la fila
    /// «cabría» siempre y el segundo candidato **no se elegiría nunca**. Con
    /// `Spacer(minLength:)` el ideal de la fila pasa a ser *fecha + separación + acciones*, que es
    /// la medida verdadera. Eso compila y no rompe ninguna prueba: se comprueba mirando la
    /// pantalla con el texto al 200 % (research.md D-404, quickstart paso 8).
    private var dateAndActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BocTheme.spacing.xs) {
                date
                Spacer(minLength: BocTheme.spacing.sm)
                actions
            }

            VStack(alignment: .leading, spacing: BocTheme.spacing.xxs) {
                date
                HStack(spacing: BocTheme.spacing.xs) {
                    Spacer(minLength: 0)
                    actions
                }
            }
        }
        .padding(.top, BocTheme.spacing.xxs)
    }

    private var date: some View {
        HStack(spacing: BocTheme.spacing.xxs) {
            Image(.icCalendar)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(BocDateFormatting.long(publication.publicationDate))
                .bocTextStyle(Typography.date)
                // El identificador va en el `Text` y no en la fila: sobre un contenedor se
                // propagaría al icono, y aquí hace falta el marco del texto para comprobar que
                // la fila se apila (FR-005).
                .accessibilityIdentifier("publication_date")
        }
        .foregroundStyle(BocTheme.colors.textSecondary)
    }

    private var actions: some View {
        HStack(spacing: BocTheme.spacing.xs) {
            // Se comparte **el enlace del documento oficial**, no el título: lo que sirve al otro
            // lado es poder abrir el documento (FR-075). El asunto lleva el título **entero**,
            // con su organismo: fuera de la aplicación no hay una línea encima que lo diga.
            ShareLink(
                item: publication.documentUrl,
                subject: Text(publication.title),
                message: Text(Strings.Card.shareChooser)
            ) {
                icon(.icShare)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BocTheme.colors.textSecondary)
            .accessibilityLabel(Text(Strings.Card.share))
            .accessibilityIdentifier("publication_share")
            .simultaneousGesture(TapGesture().onEnded { onShare?() })

            action(.icBookmark, label: Strings.Card.save, identifier: "publication_save") {
                onSave?()
            }
        }
    }

    private func icon(_ resource: ImageResource) -> some View {
        Image(resource)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            // Área táctil de 48 pt, aunque el icono mida 24 (documento de diseño §12.1).
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }

    private func action(
        _ icon: ImageResource,
        label: LocalizedStringResource,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            self.icon(icon)
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

// MARK: - The four steps of the card

extension PublicationCard {
    /// The four typography steps of the card, in one place, so a test can assert them.
    ///
    /// **Sin esto FR-018 no se puede comprobar.** La tarjeta se declara
    /// `.accessibilityElement(children: .combine)` para que un lector de pantalla la recorra de un
    /// gesto y no de cuatro, y la consecuencia es que **sus cuatro textos no existen en el árbol de
    /// accesibilidad**: no tienen identificador, no tienen marco, y ninguna prueba de interfaz
    /// puede medirlos. Nombrarlos aquí permite afirmar sobre ellos sin arrancar el simulador, y
    /// además comprueba más de lo que el requisito pedía: que van en orden y que **ninguno se ha
    /// escrito a mano** (research.md D-403).
    ///
    /// Son propiedades **calculadas**: no declaran ningún tamaño, eligen un peldaño de la escala
    /// de catorce del apartado 6.2 del documento de diseño.
    enum Typography {
        /// 15 · La etiqueta de sección. Es lo primero que se mira para descartar.
        static var section: BocTextStyle { BocTheme.typography.titleSmall }
        /// 16 · El organismo. Quién publica es la mitad de la decisión de leer o no.
        ///
        /// Es `bodyLarge`, que es **regular**, y no un token semibold: sube de cuerpo y va en
        /// mayúsculas, y los tres efectos juntos pesarían más que el título, que es el dato.
        static var organisation: BocTextStyle { BocTheme.typography.bodyLarge }
        /// 20 · El título. Tiene que ganar.
        static var title: BocTextStyle { BocTheme.typography.titleLarge }
        /// 14 · La fecha. El apartado 6.3 prohíbe bajar de 12.
        static var date: BocTextStyle { BocTheme.typography.bodyMedium }

        /// Los tres que forman la jerarquía de lectura, en orden de peso **creciente**.
        static var hierarchy: [BocTextStyle] { [section, organisation, title] }
        /// Los cuatro, para poder recorrerlos.
        static var all: [BocTextStyle] { [section, organisation, title, date] }
    }
}

// MARK: - Previews

#Preview("Tarjeta estándar") {
    PublicationCard(publication: .preview())
        .padding(BocTheme.spacing.screenMargin)
        .background(BocTheme.colors.background)
}

#Preview("Con organismo largo") {
    // Setenta y dos caracteres, y en mayúsculas se lee peor: es la contrapartida aceptada de la
    // decisión, y por eso se mantiene el tope de dos líneas (documento de diseño §6.3).
    PublicationCard(
        publication: .preview(
            issuer: "Consejería de Fomento, Vivienda, Ordenación del Territorio y Medio Ambiente",
            title: "Información pública del estudio de impacto ambiental del proyecto de mejora"
        )
    )
    .padding(BocTheme.spacing.screenMargin)
    .background(BocTheme.colors.background)
}

#Preview("Sin organismo") {
    // El campo es opcional y hay anuncios de los que no se deduce. La línea **no existe**: no se
    // deja un hueco donde iría el nombre (FR-007).
    PublicationCard(publication: .preview(issuer: nil))
        .padding(BocTheme.spacing.screenMargin)
        .background(BocTheme.colors.background)
}

private extension Publication {
    static func preview(
        issuer: String? = "Consejería de Salud",
        title: String = "CONSEJERÍA DE SALUD: Convocatoria de concurso-oposición para el acceso a plazas de Enfermería."
    ) -> Publication {
        Publication(
            externalKey: "boc:439765",
            blobId: "439765",
            idSource: .blobId,
            feedId: "6802081",
            sectionCode: "2",
            subsectionCode: "2.2",
            title: title,
            issuer: issuer,
            organizationPath: issuer.map { [$0] } ?? [],
            editionType: .ordinary,
            publicationDate: BocDate(iso: "2026-08-27")!,
            documentUrl: URL(string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=439765")!,
            rawCategories: "2.Autoridades y Personal|2.2.Cursos, oposiciones y concursos",
            warnings: []
        )
    }
}
