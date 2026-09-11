//
//  SectionsDrawerRow.swift
//  One section in the panel, with its subsections underneath.
//

import SwiftUI

struct SectionsDrawerRow: View {
    let row: SectionRow
    let isExpanded: Bool
    let selection: HomeSelection
    let onSelect: (HomeSelection) -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sectionRow
            if isExpanded, row.isExpandable {
                subsections
            }
            Divider().overlay(BocTheme.colors.outline.opacity(0.35))
        }
    }

    private var sectionRow: some View {
        HStack(spacing: BocTheme.spacing.sm) {
            Button {
                onSelect(.section(code: row.section.code, subsectionCode: nil))
            } label: {
                HStack(spacing: BocTheme.spacing.sm) {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(sectionColor)
                    // La forma «1 · Disposiciones generales»: el número es parte del nombre
                    // oficial y la gente lo usa para orientarse.
                    Text("\(row.section.code) · \(row.section.name)")
                        .bocTextStyle(BocTheme.typography.titleMedium)
                        .foregroundStyle(BocTheme.colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("section_row_\(row.id)")

            if row.isExpandable {
                Button(action: onToggle) {
                    Image(.icExpandMore)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(BocTheme.colors.textSecondary)
                .accessibilityLabel(Text(isExpanded
                    ? Strings.Sections.collapse(row.section.name)
                    : Strings.Sections.expand(row.section.name)))
                .accessibilityIdentifier("section_toggle_\(row.id)")
            }
        }
        .padding(.horizontal, BocTheme.spacing.md)
        .frame(minHeight: 72)
    }

    private var subsections: some View {
        VStack(spacing: 0) {
            ForEach(row.children) { child in
                Button {
                    onSelect(.section(code: row.section.code, subsectionCode: child.code))
                } label: {
                    HStack(spacing: BocTheme.spacing.xs) {
                        Circle()
                            .fill(sectionColor)
                            .frame(width: 6, height: 6)
                        Text("\(child.code) · \(child.name)")
                            .bocTextStyle(BocTheme.typography.bodyMedium)
                            .foregroundStyle(BocTheme.colors.textSecondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, BocTheme.spacing.sm)
                    .padding(.horizontal, BocTheme.spacing.md)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("section_row_\(child.code)")
            }
        }
        // Fondo suave y sangría: la misma jerarquía visual que la segunda fila de chips, para que
        // haya un solo vocabulario en los dos sitios donde aparecen subsecciones.
        .background(BocTheme.colors.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: BocTheme.shape.small))
        .padding(.horizontal, BocTheme.spacing.md)
        .padding(.leading, BocTheme.spacing.lg)
        .padding(.bottom, BocTheme.spacing.xs)
    }

    private var icon: ImageResource {
        switch row.section.code {
        case "1": .icSectionGeneral
        case "2": .icSectionPersonnel
        case "3": .icSectionContracting
        case "4": .icSectionEconomy
        case "5": .icSectionExpropriation
        case "6": .icSectionGrants
        case "7": .icSectionAnnouncements
        case "8": .icSectionJudicial
        default: .icSectionElections
        }
    }

    private var sectionColor: Color {
        switch row.section.colorGroup {
        case .general: BocTheme.colors.sectionGeneral
        case .personnel: BocTheme.colors.sectionPersonnel
        case .contracting: BocTheme.colors.sectionContracting
        case .economy: BocTheme.colors.sectionEconomy
        case .announcements: BocTheme.colors.sectionAnnouncements
        }
    }
}
