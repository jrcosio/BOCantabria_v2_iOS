//
//  Route.swift
//  The typed destinations inside a tab.
//
//  Hoy no hay ninguno: **pulsar una tarjeta no navega a ningún sitio** en esta feature (FR-077).
//  El mecanismo se conserva montado porque el detalle de la publicación es la feature siguiente y
//  entonces cada pestaña tendrá su pila con destinos tipados.
//

enum Route: Hashable {
    /// El detalle de una publicación, identificado por su clave externa. Llega con la 004.
    case publicationDetail(externalKey: String)
}
