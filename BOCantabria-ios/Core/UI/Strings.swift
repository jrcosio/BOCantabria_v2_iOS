//
//  Strings.swift
//  The visible text of the application, in one place.
//
//  Los textos viven en `Localizable.xcstrings` y se nombran desde aquí. Tenerlos agrupados en
//  constantes en vez de esparcidos como literales en las vistas hace dos cosas: el compilador
//  caza una clave mal escrita, y se ve de un vistazo qué dice la aplicación.
//

import Foundation

enum Strings {
    enum Home {
        static let title = LocalizedStringResource("home_title")
        static let loading = LocalizedStringResource("home_loading_body")
        static let bulletinToday = LocalizedStringResource("home_bulletin_today")
        static let emptyToday = LocalizedStringResource("home_empty_today")
        static let emptySection = LocalizedStringResource("home_empty_section")
        static let errorSync = LocalizedStringResource("home_error_sync")
        static let offline = LocalizedStringResource("home_offline")

        /// Los dos rótulos de la fecha. Son **dos** porque la fecha significa dos cosas distintas,
        /// y sin fecha no se pinta ninguno (FR-033 … FR-035).
        static func editionDate(_ date: String) -> LocalizedStringResource {
            LocalizedStringResource("home_header_date_bulletin", defaultValue: "Edición del \(date)")
        }

        static func latestPublicationDate(_ date: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "home_header_date_section",
                defaultValue: "Última publicación: \(date)"
            )
        }

        /// El primer plural del catálogo.
        static func publicationCount(_ count: Int) -> LocalizedStringResource {
            LocalizedStringResource("home_publication_count", defaultValue: "\(count) anuncios")
        }
    }

    enum AppBar {
        static let title = LocalizedStringResource("app_bar_title")
        static let openSections = LocalizedStringResource("app_bar_open_sections")
        static let search = LocalizedStringResource("app_bar_search")
        static let info = LocalizedStringResource("app_bar_info")
    }

    enum Chip {
        static let todaysBulletin = LocalizedStringResource("chip_todays_bulletin")
        static let wholeSection = LocalizedStringResource("chip_whole_section")
    }

    enum Card {
        static let save = LocalizedStringResource("publication_save")
        static let unsave = LocalizedStringResource("publication_unsave")
        static let share = LocalizedStringResource("publication_share")
        static let shareChooser = LocalizedStringResource("publication_share_chooser")

        static func section(_ name: String) -> LocalizedStringResource {
            LocalizedStringResource("publication_section", defaultValue: "Sección \(name)")
        }
    }

    enum Sections {
        static let close = LocalizedStringResource("sections_close")

        static func expand(_ name: String) -> LocalizedStringResource {
            LocalizedStringResource("sections_expand", defaultValue: "Desplegar \(name)")
        }

        static func collapse(_ name: String) -> LocalizedStringResource {
            LocalizedStringResource("sections_collapse", defaultValue: "Contraer \(name)")
        }
    }

    enum Nav {
        static let home = LocalizedStringResource("nav_home")
        static let search = LocalizedStringResource("nav_search")
        static let saved = LocalizedStringResource("nav_saved")
    }

    enum Common {
        static let comingSoon = LocalizedStringResource("coming_soon")
    }

    /// El formato largo español, compuesto a mano. Usar el formateador del sistema ataría el texto
    /// al idioma del dispositivo y haría que una prueba pasara o fallara según la máquina (D-316).
    ///
    /// Los doce meses se escriben uno a uno: la clave de un `LocalizedStringResource` tiene que ser
    /// literal, así que no hay forma de componerla. Doce líneas es el precio de que el compilador
    /// cace una clave mal escrita.
    enum Dates {
        static let months: [LocalizedStringResource] = [
            LocalizedStringResource("month_01", defaultValue: "enero"),
            LocalizedStringResource("month_02", defaultValue: "febrero"),
            LocalizedStringResource("month_03", defaultValue: "marzo"),
            LocalizedStringResource("month_04", defaultValue: "abril"),
            LocalizedStringResource("month_05", defaultValue: "mayo"),
            LocalizedStringResource("month_06", defaultValue: "junio"),
            LocalizedStringResource("month_07", defaultValue: "julio"),
            LocalizedStringResource("month_08", defaultValue: "agosto"),
            LocalizedStringResource("month_09", defaultValue: "septiembre"),
            LocalizedStringResource("month_10", defaultValue: "octubre"),
            LocalizedStringResource("month_11", defaultValue: "noviembre"),
            LocalizedStringResource("month_12", defaultValue: "diciembre"),
        ]

        /// - Parameter month: 1 … 12. Fuera de rango es un error de programación, no de datos:
        ///   `BocDate` no deja construir un mes que no exista.
        static func month(_ month: Int) -> LocalizedStringResource {
            months[month - 1]
        }

        static func long(day: Int, month: String, year: Int) -> LocalizedStringResource {
            LocalizedStringResource("date_long", defaultValue: "\(day) de \(month) de \(year)")
        }
    }

    enum Splash {
        static let acronym = LocalizedStringResource("splash_acronym")
        static let titleLineOne = LocalizedStringResource("splash_title_line_one")
        static let titleLineTwo = LocalizedStringResource("splash_title_line_two")
        static let authorshipLabel = LocalizedStringResource("splash_authorship_label")
        static let authorshipName = LocalizedStringResource("splash_authorship_name")
        static let loadingDescription = LocalizedStringResource("splash_loading_description")
        static let errorTitle = LocalizedStringResource("splash_error_title")
        static let errorNetwork = LocalizedStringResource("splash_error_network")
        static let errorUnknown = LocalizedStringResource("splash_error_unknown")
        static let continueOffline = LocalizedStringResource("splash_continue_offline")
        static let updateRequiredTitle = LocalizedStringResource("splash_update_required_title")
        static let updateRequiredMessage = LocalizedStringResource("splash_update_required_message")
        static let maintenanceTitle = LocalizedStringResource("splash_maintenance_title")
    }

    enum Action {
        static let retry = LocalizedStringResource("action_retry")
    }
}
