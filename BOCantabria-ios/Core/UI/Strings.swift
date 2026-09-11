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

    enum Action {
        static let retry = LocalizedStringResource("action_retry")
    }
}
