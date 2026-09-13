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

    func makeUIView(context: Context) -> BocPdfView {
        let view = BocPdfView()
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

    /// **Solo hace algo cuando cambia el documento**, y eso es una decisión, no una simplificación.
    ///
    /// La versión anterior también restauraba la página cuando el índice de fuera no coincidía con
    /// el de dentro, y eso cierra un bucle: el visor cambia de página → la notificación escribe el
    /// enlace → SwiftUI redibuja → esto mueve el visor → la notificación escribe otra vez. El
    /// guardián de «estoy restaurando» no lo corta, porque la notificación llega **en la cola
    /// principal**, después de que el guardián se haya bajado.
    ///
    /// Un bucle así no falla: deja la aplicación sin llegar nunca a reposo, y lo que se ve desde
    /// fuera es que los toques **dejan de sintetizarse**.
    ///
    /// El flujo correcto es de una sola dirección: la página guardada entra **una vez**, al cargar
    /// el documento, y a partir de ahí solo sale.
    func updateUIView(_ view: BocPdfView, context: Context) {
        guard context.coordinator.loadedUrl != fileUrl else { return }
        view.document = PDFDocument(url: fileUrl)
        context.coordinator.loadedUrl = fileUrl
        // El ajuste lo fija la vista **cuando tiene su tamaño**, no aquí. Ver `BocPdfView`.
        view.needsInitialFit = true
        context.coordinator.restore(pageIndex, in: view)
    }

    static func dismantleUIView(_ view: BocPdfView, coordinator: Coordinator) {
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

        init(pageIndex: Binding<Int>) {
            self.pageIndex = pageIndex
        }

        func observe(_ view: BocPdfView) {
            token = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged, object: view, queue: .main
            ) { [weak self, weak view] _ in
                MainActor.assumeIsolated {
                    guard let self, let view else { return }
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

        /// Lleva el visor a la página guardada. **Se llama una sola vez, al cargar el documento.**
        ///
        /// No pelea con el dedo porque nunca se llama mientras se lee: la única dirección que queda
        /// viva después es visor → estado.
        func restore(_ index: Int, in view: PDFView) {
            guard let document = view.document,
                  index > 0, index < document.pageCount,
                  let page = document.page(at: index)
            else { return }
            view.go(to: page)
        }
    }
}


/// `PDFView` que fija su ajuste **cuando ya conoce su tamaño**.
///
/// **Es un defecto que se ve y no se lee.** `scaleFactorForSizeToFit` depende del ancho de la
/// vista, y en el momento en que SwiftUI asigna el documento la vista todavía no lo tiene: el
/// factor sale mal, el documento aparece **más ancho que la pantalla** y el texto se corta por la
/// derecha. Se descubrió abriendo un boletín de verdad y mirándolo, no leyendo el código
/// (research.md D-515).
///
/// El tope inferior se fija aquí por la misma razón que ya estaba escrita: con el factor a cero, el
/// pellizco deja reducir el documento a nada sin forma de recuperarlo.
final class BocPdfView: PDFView {
    /// Lo pone la vista de SwiftUI al asignar un documento nuevo.
    var needsInitialFit = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard needsInitialFit, document != nil, bounds.width > 0 else { return }
        needsInitialFit = false

        let ajuste = scaleFactorForSizeToFit
        guard ajuste > 0 else {
            // Todavía no se puede calcular: se intenta en la siguiente pasada.
            needsInitialFit = true
            return
        }
        minScaleFactor = ajuste
        maxScaleFactor = ajuste * 5
        scaleFactor = ajuste
    }
}
