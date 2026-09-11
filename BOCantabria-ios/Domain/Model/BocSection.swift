//
//  BocSection.swift
//  The official section tree of the bulletin: nine sections and fourteen subsections.
//
//  Es **conocimiento de negocio**, no de procedencia: si mañana hubiera un servicio propio que
//  agregara las fuentes, las secciones seguirían siendo estas nueve. Por eso el árbol vive en
//  `Domain` y el catálogo de direcciones vive en `Data`.
//

import Foundation

/// Los cinco grupos cromáticos del apartado 4.4 del documento de diseño. **Es un tipo de dominio,
/// no un color**: la traducción a color vive en la capa de interfaz, que es la única que sabe
/// pintar.
///
/// Son cinco para nueve secciones, y eso no pierde información porque el indicador de color
/// **siempre va acompañado de texto** (FR-040). El color agrupa; el texto identifica.
enum SectionColorGroup: String, Sendable, Codable, CaseIterable {
    case general
    case personnel
    case contracting
    case economy
    case announcements
}

struct BocSection: Sendable, Hashable, Identifiable, Codable {
    /// `1`, `2`, `2.1`, `7.5`… Único en todo el árbol.
    let code: String
    /// Nombre oficial completo.
    let name: String
    /// El del chip y el de la fila del panel.
    let shortName: String
    /// Nulo en las nueve secciones principales.
    let parentCode: String?
    /// Orden oficial de presentación.
    let order: Int
    let colorGroup: SectionColorGroup

    var id: String { code }
    var isTopLevel: Bool { parentCode == nil }
}

extension BocSection {
    /// El árbol completo, en orden oficial. Veintitrés filas.
    ///
    /// **Las secciones 2, 4, 7 y 8 no tienen fuente propia**: su contenido es la unión del de sus
    /// subsecciones. Esa es la razón de que una consulta por sección principal filtre por el
    /// código de sección y no por igualdad con el código más específico.
    static let all: [BocSection] = [
        .init(code: "1", name: "Disposiciones Generales", shortName: "Disposiciones",
              parentCode: nil, order: 1, colorGroup: .general),

        .init(code: "2", name: "Autoridades y Personal", shortName: "Personal",
              parentCode: nil, order: 2, colorGroup: .personnel),
        .init(code: "2.1", name: "Nombramientos, Ceses y Otras Situaciones",
              shortName: "Nombramientos", parentCode: "2", order: 1, colorGroup: .personnel),
        .init(code: "2.2", name: "Cursos, Oposiciones y Concursos", shortName: "Oposiciones",
              parentCode: "2", order: 2, colorGroup: .personnel),
        .init(code: "2.3", name: "Otros", shortName: "Otros", parentCode: "2", order: 3,
              colorGroup: .personnel),

        .init(code: "3", name: "Contratación Administrativa", shortName: "Contratación",
              parentCode: nil, order: 3, colorGroup: .contracting),

        .init(code: "4", name: "Economía, Hacienda y Seguridad Social", shortName: "Economía",
              parentCode: nil, order: 4, colorGroup: .economy),
        .init(code: "4.1", name: "Actuaciones en materia Presupuestaria", shortName: "Presupuestos",
              parentCode: "4", order: 1, colorGroup: .economy),
        .init(code: "4.2", name: "Actuaciones en materia Fiscal", shortName: "Fiscal",
              parentCode: "4", order: 2, colorGroup: .economy),
        .init(code: "4.3", name: "Actuaciones en materia de Seguridad Social",
              shortName: "Seguridad Social", parentCode: "4", order: 3, colorGroup: .economy),
        .init(code: "4.4", name: "Otros", shortName: "Otros", parentCode: "4", order: 4,
              colorGroup: .economy),

        .init(code: "5", name: "Expropiación Forzosa", shortName: "Expropiación",
              parentCode: nil, order: 5, colorGroup: .announcements),

        .init(code: "6", name: "Subvenciones y Ayudas", shortName: "Subvenciones",
              parentCode: nil, order: 6, colorGroup: .economy),

        .init(code: "7", name: "Otros Anuncios", shortName: "Anuncios", parentCode: nil, order: 7,
              colorGroup: .announcements),
        .init(code: "7.1", name: "Urbanismo", shortName: "Urbanismo", parentCode: "7", order: 1,
              colorGroup: .announcements),
        .init(code: "7.2", name: "Medio Ambiente y Energía", shortName: "Medio Ambiente",
              parentCode: "7", order: 2, colorGroup: .announcements),
        .init(code: "7.3", name: "Estatutos y Convenios Colectivos", shortName: "Convenios",
              parentCode: "7", order: 3, colorGroup: .announcements),
        .init(code: "7.4", name: "Particulares", shortName: "Particulares", parentCode: "7",
              order: 4, colorGroup: .announcements),
        .init(code: "7.5", name: "Varios", shortName: "Varios", parentCode: "7", order: 5,
              colorGroup: .announcements),

        .init(code: "8", name: "Procedimientos Judiciales", shortName: "Judicial",
              parentCode: nil, order: 8, colorGroup: .announcements),
        .init(code: "8.1", name: "Subastas", shortName: "Subastas", parentCode: "8", order: 1,
              colorGroup: .announcements),
        .init(code: "8.2", name: "Otros Anuncios", shortName: "Otros", parentCode: "8", order: 2,
              colorGroup: .announcements),

        .init(code: "9", name: "Elecciones", shortName: "Elecciones", parentCode: nil, order: 9,
              colorGroup: .general),
    ]

    static func named(_ code: String) -> BocSection? {
        all.first { $0.code == code }
    }

    /// Las nueve principales, en orden.
    static var topLevel: [BocSection] {
        all.filter(\.isTopLevel).sorted { $0.order < $1.order }
    }

    /// Las subsecciones de una sección, en orden. Vacío en las cinco que no tienen.
    static func children(of code: String) -> [BocSection] {
        all.filter { $0.parentCode == code }.sorted { $0.order < $1.order }
    }
}
