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
        static let empty = LocalizedStringResource("home_empty_body")
        static let error = LocalizedStringResource("home_error_body")
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
