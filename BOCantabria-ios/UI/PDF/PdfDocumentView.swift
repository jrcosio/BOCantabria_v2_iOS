//
//  PdfDocumentView.swift
//  The one place that puts PDFKit on screen.
//
//  Es la excepción que la constitución nombra: «la ÚNICA excepción es la interoperabilidad acotada
//  con PDFKit para el visor del documento oficial, que DEBE quedar encerrada tras una vista propia
//  y no puede filtrar tipos de PDFKit al resto de la aplicación». La regla 14 lo comprueba.
//

import PDFKit
import SwiftUI
import UIKit

struct PdfDocumentView: UIViewRepresentable {
    let fileUrl: URL
    /// La página visible. La posee quien llama, para poder guardarla entre ejecuciones.
    @Binding var pageIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(pageIndex: $pageIndex) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        // El documento de diseño (§24.2) pide página blanca con sombra suave; PDFKit la dibuja
        // demasiado marcada sobre el gris del lector, así que se apaga y el contraste lo da el
        // fondo.
        view.pageShadowsEnabled = false
        // El color sale del tema, no de aquí. La regla 7 falla la build en cualquier otro sitio.
        view.backgroundColor = BocUIColors.readerSurface
        view.interpolationQuality = .high
        context.coordinator.observe(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if context.coordinator.loadedUrl != fileUrl {
            view.document = PDFDocument(url: fileUrl)
            context.coordinator.loadedUrl = fileUrl

            // **Después de asignar el documento, nunca antes.** Sin documento vale cero, y con
            // cero el pellizco deja reducirlo a nada sin forma de recuperarlo. Se ve mirando la
            // pantalla, no leyendo el código (research.md D-515).
            let ajuste = view.scaleFactorForSizeToFit
            view.minScaleFactor = ajuste
            view.maxScaleFactor = ajuste * 5

            context.coordinator.restore(pageIndex, in: view)
        } else if context.coordinator.currentIndex(of: view) != pageIndex {
            context.coordinator.restore(pageIndex, in: view)
        }
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
        // Suelta el mapeo del fichero. Sin esto, un documento grande sigue ocupando después de
        // salir de la pantalla.
        view.document = nil
    }

    /// Traduce entre lo que el visor sabe —páginas— y lo que la vista guarda —un entero—.
    ///
    /// **El observador vive aquí y no en la vista** porque `dismantleUIView` es estático: guardarlo
    /// en la vista impediría retirarlo, y quedaría vivo después de salir.
    @MainActor
    final class Coordinator {
        var loadedUrl: URL?
        private let pageIndex: Binding<Int>
        private var token: NSObjectProtocol?
        /// Evita que restaurar la página dispare la notificación que vuelve a escribir el enlace.
        private var restoring = false

        init(pageIndex: Binding<Int>) {
            self.pageIndex = pageIndex
        }

        func observe(_ view: PDFView) {
            token = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged, object: view, queue: .main
            ) { [weak self, weak view] _ in
                MainActor.assumeIsolated {
                    guard let self, let view, !self.restoring else { return }
                    let indice = self.currentIndex(of: view)
                    if self.pageIndex.wrappedValue != indice { self.pageIndex.wrappedValue = indice }
                }
            }
        }

        func stopObserving() {
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
        }

        func currentIndex(of view: PDFView) -> Int {
            guard let document = view.document, let page = view.currentPage else { return 0 }
            return document.index(for: page)
        }

        /// Lleva el visor a la página guardada. **No pelea con el dedo**: solo se llama cuando el
        /// índice de fuera y el de dentro difieren.
        func restore(_ index: Int, in view: PDFView) {
            guard let document = view.document,
                  index > 0, index < document.pageCount,
                  let page = document.page(at: index)
            else { return }
            restoring = true
            view.go(to: page)
            restoring = false
        }
    }
}
