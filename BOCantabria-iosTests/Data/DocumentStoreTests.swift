//
//  DocumentStoreTests.swift
//
//  Cuatro invariantes, y cada uno tuvo su defecto en la aplicación de origen:
//
//  1. **Una sola descarga** por documento, aunque la pidan dos pantallas (FR-026).
//  2. **Quien espera no hereda la cancelación** de quien inició (FR-028). Aquí sale del tipo.
//  3. **Todo camino publica un estado terminal** (FR-029). Es STAB-002.
//  4. **Quien llega tarde ve el estado vigente**, y por eso no se cuelga (D-510).
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

@Suite("Almacén de documentos")
struct DocumentStoreTests {

    // MARK: - Reutilización y reproducción

    @Test("Un documento que ya está no se vuelve a descargar")
    func anAlreadyPresentDocumentIsNotDownloadedAgain() async {
        let guardado = officialDocument(externalKey: "boc:1")
        let downloader = CountingDocumentDownloader()
        let store = DocumentStore(
            downloader: downloader,
            cache: FakeDocumentCache(seeded: ["boc:1": guardado]),
            crashReporter: NoOpCrashReporter()
        )

        let resultado = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

        #expect(resultado == .success(guardado))
        #expect(await downloader.downloadCount == 0)
    }

    @Test("Quien se suscribe DESPUÉS ve el estado vigente de inmediato")
    func aLateSubscriberSeesTheCurrentStateImmediately() async {
        // **Es la prueba que impide un cuelgue silencioso.** El visor se abre cuando el documento
        // ya está disponible; la publicación de ese estado ocurrió antes de que él llegara. Sin la
        // reproducción, no recibe nada y se queda cargando **para siempre**, sin excepción y sin
        // nada en el registro.
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(),
            cache: FakeDocumentCache(),
            crashReporter: NoOpCrashReporter()
        )

        _ = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

        var primero: DocumentStatus?
        for await estado in store.observeDocument(externalKey: "boc:1") {
            primero = estado
            break
        }

        #expect(primero?.isTerminal == true, "Quien llega tarde no puede recibir «obteniéndose»")
        #expect(primero?.document != nil)
    }

    @Test("Una clave que nadie ha pedido está ausente, no cargando")
    func anUnrequestedKeyIsAbsentRatherThanLoading() async {
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(),
            cache: FakeDocumentCache(),
            crashReporter: NoOpCrashReporter()
        )

        var primero: DocumentStatus?
        for await estado in store.observeDocument(externalKey: "boc:nadie") {
            primero = estado
            break
        }

        #expect(primero == .absent)
    }

    // MARK: - Coalescencia (FR-026, FR-028)

    @Test("Dos peticiones simultáneas del mismo documento producen UNA descarga")
    func twoSimultaneousRequestsProduceASingleDownload() async {
        let downloader = CountingDocumentDownloader(holds: true)
        let store = DocumentStore(
            downloader: downloader, cache: FakeDocumentCache(), crashReporter: NoOpCrashReporter()
        )
        let publicacion = publication(externalKey: "boc:1")

        async let primera = store.ensureLocalCopy(publicacion)
        // Se espera a que la primera haya llegado a la puerta. **Nada de esperas por tiempo**: una
        // espera convierte esto en una carrera, y una carrera en verde es peor que una roja.
        await downloader.waitUntilHolding(1)
        async let segunda = store.ensureLocalCopy(publicacion)

        await downloader.release()
        let (uno, dos) = await (primera, segunda)

        #expect(await downloader.downloadCount == 1)
        #expect(uno == dos)
        if case .failure = uno { Issue.record("Las dos deberían haber recibido el documento") }
    }

    @Test("Quien espera NO hereda la cancelación de quien inició la descarga")
    func aWaiterDoesNotInheritTheInitiatorsCancellation() async {
        // **Es FR-028, y aquí sale del sistema de tipos.** En la aplicación de origen, cancelar la
        // primera pantalla dejaba a la segunda cargando sin botón de reintento, atascada hasta
        // salir. Con `Task<_, Never>` no existe el canal por el que heredar nada.
        let downloader = CountingDocumentDownloader(holds: true)
        let store = DocumentStore(
            downloader: downloader, cache: FakeDocumentCache(), crashReporter: NoOpCrashReporter()
        )
        let publicacion = publication(externalKey: "boc:1")

        let primera = Task { await store.ensureLocalCopy(publicacion) }
        await downloader.waitUntilHolding(1)
        async let segunda = store.ensureLocalCopy(publicacion)

        // La primera se va. La segunda sigue esperando.
        primera.cancel()
        await downloader.release()

        let recibido = await segunda
        guard case .success = recibido else {
            Issue.record("La segunda pantalla se ha quedado sin documento por una cancelación ajena")
            return
        }
        #expect(await downloader.downloadCount == 1)
    }

    @Test("Volver a pedirlo después de cancelar arranca una descarga nueva y funciona")
    func askingAgainAfterACancellationStartsAFreshDownload() async {
        // Cubre el camino que la persona recorre: salir del detalle mientras se descarga y volver
        // a entrar. Tiene que traer el documento, no un error que nadie pidió.
        //
        // **Lo que esta prueba NO discrimina, y se dice**: el almacén lleva además un guardián
        // —`!job.task.isCancelled` en `claim`— para una ventana más estrecha, la de engancharse a
        // un trabajo ya cancelado **antes** de que su propia limpieza lo retire del diccionario.
        // Se encontró leyendo el código y se cerró por construcción, pero forzarla desde fuera
        // exigiría una costura dentro del actor para saber cuándo ha corrido la cancelación, y eso
        // es más superficie de la que el defecto merece. Al quitar el guardián, **la que se pone
        // roja es la de FR-028**, no ésta: la ventana existe, y el que la cubre de verdad es el
        // tipo del trabajo en vuelo.
        let downloader = CountingDocumentDownloader(holds: true)
        let store = DocumentStore(
            downloader: downloader, cache: FakeDocumentCache(), crashReporter: NoOpCrashReporter()
        )
        let publicacion = publication(externalKey: "boc:1")

        // Alguien pide y se va: el trabajo queda cancelado.
        let primera = Task { await store.ensureLocalCopy(publicacion) }
        await downloader.waitUntilHolding(1)
        primera.cancel()
        await downloader.release()
        let cancelada = await primera.value
        #expect(cancelada == .failure(.cancelled))

        // Y otro entra justo detrás, con el trabajo viejo todavía en el diccionario.
        async let segunda = store.ensureLocalCopy(publicacion)
        await downloader.waitUntilHolding(2)
        await downloader.release()

        guard case .success = await segunda else {
            Issue.record("Quien vuelve a entrar ha recibido una cancelación ajena")
            return
        }
        // Y ha arrancado **su propia** descarga, no reutilizado la cancelada.
        #expect(await downloader.downloadCount == 2)
    }

    // MARK: - El estado terminal (FR-029, STAB-002)

    @Test(
        "TODO camino de error publica un estado terminal",
        arguments: [
            TerminalCase(name: "tipo declarado", outcome: .rejected(.unexpectedType), commitSucceeds: true),
            TerminalCase(name: "no es un documento", outcome: .rejected(.notAPdf), commitSucceeds: true),
            TerminalCase(name: "demasiado grande", outcome: .rejected(.tooLarge), commitSucceeds: true),
            TerminalCase(name: "error del servicio", outcome: .rejected(.httpError), commitSucceeds: true),
            TerminalCase(name: "canal inseguro", outcome: .rejected(.insecureScheme), commitSucceeds: true),
            TerminalCase(name: "host inesperado", outcome: .rejected(.unexpectedHost), commitSucceeds: true),
            TerminalCase(name: "red", outcome: .rejected(.network), commitSucceeds: true),
            TerminalCase(name: "no se pudo escribir", outcome: .rejected(.storage), commitSucceeds: true),
            TerminalCase(
                name: "fallo al guardar, con la descarga terminada",
                outcome: .downloaded(byteCount: 10, checksum: String(repeating: "a", count: 64)),
                commitSucceeds: false
            ),
        ]
    )
    func everyErrorPathPublishesATerminalState(_ caso: TerminalCase) async {
        // **Éste es el defecto de severidad media de la auditoría**, visto desde dentro: el fallo
        // se devolvía a quien lo pidió y **no se publicaba**, y como las pantallas solo observan el
        // estado, el detalle y el visor se quedaban en «obteniéndose» para siempre.
        //
        // La última fila es la que lo reproducía: la descarga termina bien y **guardarla falla**.
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(outcome: caso.outcome),
            cache: FakeDocumentCache(commitSucceeds: caso.commitSucceeds),
            crashReporter: NoOpCrashReporter()
        )

        let resultado = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

        // **Se lee DESPUÉS, y a propósito.** Un observador en segundo plano parecía más fiel y es
        // una trampa: si se registra después de que la descarga termine, solo recibe el estado
        // reproducido, y cualquier condición de salida que espere «más de uno» **cuelga la prueba
        // en vez de fallarla**. Costó un tiempo de espera agotado descubrirlo.
        //
        // Y leer después comprueba exactamente lo que FR-029 pide: que **lo que queda** sea
        // terminal. Si el defecto de origen estuviera aquí, lo que quedaría es «obteniéndose».
        var ultimo: DocumentStatus?
        for await estado in store.observeDocument(externalKey: "boc:1") { ultimo = estado; break }

        #expect(ultimo?.isTerminal == true, "«\(caso.name)» ha dejado la pantalla cargando")
        if case .failed(let publicado) = ultimo, case .failure(let devuelto) = resultado {
            // FR-029 pide las dos cosas **coherentes**, no solo que existan.
            #expect(publicado == devuelto, "«\(caso.name)»: el estado y el resultado discrepan")
        } else {
            Issue.record("«\(caso.name)» debería acabar en fallo, y acabó en \(String(describing: ultimo))")
        }
    }

    @Test("El resultado que se devuelve concuerda con el estado que se publica")
    func theReturnedResultAgreesWithThePublishedState() async {
        // FR-029 pide las dos cosas **coherentes**, no solo que existan. Que discrepen es
        // exactamente cómo se manifestaba el defecto.
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(outcome: .rejected(.notAPdf)),
            cache: FakeDocumentCache(),
            crashReporter: NoOpCrashReporter()
        )

        let resultado = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

        var estado: DocumentStatus?
        for await valor in store.observeDocument(externalKey: "boc:1") { estado = valor; break }

        #expect(resultado == .failure(.unknown))
        #expect(estado == .failed(.unknown))
    }

    @Test("Cancelar deja el documento como NO descargado, nunca como error")
    func cancellingLeavesTheDocumentAsNotDownloadedAndNeverAsAnError() async {
        // FR-027. Quien canceló ya no está mirando; la próxima visita no debe encontrarse un error
        // que nadie provocó.
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(outcome: .rejected(.cancelled)),
            cache: FakeDocumentCache(),
            crashReporter: NoOpCrashReporter()
        )

        _ = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

        var estado: DocumentStatus?
        for await valor in store.observeDocument(externalKey: "boc:1") { estado = valor; break }

        #expect(estado == .absent, "Cancelar no es fallar")
    }

    @Test("Todo camino descarta el temporal, incluido el de cancelación")
    func everyPathDiscardsTheTemporaryFile() async {
        for outcome in [
            DocumentDownloadResult.rejected(.notAPdf),
            .rejected(.cancelled),
            .rejected(.network),
            .downloaded(byteCount: 10, checksum: String(repeating: "a", count: 64)),
        ] {
            let cache = FakeDocumentCache()
            let store = DocumentStore(
                downloader: CountingDocumentDownloader(outcome: outcome),
                cache: cache, crashReporter: NoOpCrashReporter()
            )

            _ = await store.ensureLocalCopy(publication(externalKey: "boc:1"))

            #expect(cache.discardedParts.count == 1, "\(outcome) no descartó su temporal")
        }
    }

    // MARK: - Retirada

    @Test("La retirada no toca lo que se está mirando")
    func releasingDoesNotTouchWhatIsBeingRead() async {
        let cache = FakeDocumentCache()
        let store = DocumentStore(
            downloader: CountingDocumentDownloader(), cache: cache, crashReporter: NoOpCrashReporter()
        )
        _ = await store.ensureLocalCopy(publication(externalKey: "boc:leyendose"))
        _ = cache.commit("boc:otro", from: cache.stage("boc:otro"), byteCount: 1,
                         checksum: String(repeating: "b", count: 64))

        await store.releaseUnused()

        #expect(cache.get("boc:leyendose") != nil)
        #expect(cache.get("boc:otro") == nil)
    }

    struct TerminalCase: Sendable {
        let name: String
        let outcome: DocumentDownloadResult
        let commitSucceeds: Bool
    }
}
