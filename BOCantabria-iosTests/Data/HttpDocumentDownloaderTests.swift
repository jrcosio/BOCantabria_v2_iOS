//
//  HttpDocumentDownloaderTests.swift
//
//  **Aquí se comprueba SC-004**: que ninguna respuesta que no sea el documento oficial llega a
//  presentarse como tal. Las respuestas están fabricadas para engañar, que es lo que un servicio
//  público sin compromiso de disponibilidad puede devolver cualquier martes.
//
//  Y SC-005: **ninguna descarga fallida deja restos**. Cada rechazo comprueba además el disco.
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

@Suite("Descargador del documento", .serialized)
struct HttpDocumentDownloaderTests {
    private static let url = URL(string: "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=439765")!

    // MARK: - El camino feliz

    @Test("Un documento correcto se descarga entero, con su recuento y su huella")
    func aGoodDocumentIsDownloadedWholeWithItsCountAndFingerprint() async throws {
        let muestra = PdfFixture.valido
        StubURLProtocol.set(StubResponse(body: muestra.data))
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        let resultado = await downloader.download(from: Self.url, into: destino, progress: { _, _ in })

        #expect(resultado == .downloaded(byteCount: Int64(muestra.data.count), checksum: muestra.sha256))
        // Los bytes escritos son **los mismos**, no unos parecidos.
        #expect(try Data(contentsOf: destino) == muestra.data)
    }

    @Test("El progreso llega con el total cuando el servicio lo declara")
    func progressCarriesTheTotalWhenTheServiceDeclaresIt() async {
        let muestra = PdfFixture.valido
        StubURLProtocol.set(StubResponse(body: muestra.data))
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        let recogido = Mutex<[(Int64, Int64?)]>([])
        _ = await downloader.download(from: Self.url, into: destino) { leidos, total in
            recogido.withLock { $0.append((leidos, total)) }
        }

        let avisos = recogido.withLock { $0 }
        #expect(!avisos.isEmpty)
        #expect(avisos.last?.0 == Int64(muestra.data.count))
        #expect(avisos.last?.1 == Int64(muestra.data.count))
    }

    // MARK: - Los rechazos

    @Test("Un enlace que no usa canal seguro se rechaza sin conectar")
    func anInsecureLinkIsRefusedWithoutConnecting() async {
        StubURLProtocol.set(StubResponse(body: PdfFixture.valido.data))
        let (downloader, destino) = make()

        let insegura = URL(string: "http://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=1")!
        let resultado = await downloader.download(from: insegura, into: destino, progress: { _, _ in })

        #expect(resultado == .rejected(.insecureScheme))
        // **Sin conectar**: no se ha pedido nada, y no hay fichero.
        #expect(StubURLProtocol.requestedUrls.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: destino.path))
    }

    @Test("Un enlace que no apunta al servicio del boletín se rechaza sin conectar")
    func aForeignHostIsRefusedWithoutConnecting() async {
        StubURLProtocol.set(StubResponse(body: PdfFixture.valido.data))
        let (downloader, destino) = make()

        // Con credenciales incrustadas, que es la forma en que una comprobación por recorte de
        // cadenas se deja engañar: lo anterior a la arroba es información de usuario.
        let ajena = URL(string: "https://boc.cantabria.es:443@audit.invalid/documento.pdf")!
        let resultado = await downloader.download(from: ajena, into: destino, progress: { _, _ in })

        #expect(resultado == .rejected(.unexpectedHost))
        #expect(StubURLProtocol.requestedUrls.isEmpty)
    }

    @Test("Una redirección a otro destino se rechaza, aunque la dirección pedida fuera buena")
    func aRedirectionElsewhereIsRefused() async {
        StubURLProtocol.set(
            StubResponse(
                body: PdfFixture.valido.data,
                finalUrl: URL(string: "https://otro.invalid/documento.pdf")!
            )
        )
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        let resultado = await downloader.download(from: Self.url, into: destino, progress: { _, _ in })

        #expect(resultado == .rejected(.unexpectedHost))
        #expect(!FileManager.default.fileExists(atPath: destino.path))
    }

    @Test("Un error del servicio se rechaza", arguments: [404, 410, 500, 503])
    func aServiceErrorIsRefused(_ status: Int) async {
        StubURLProtocol.set(StubResponse(statusCode: status, body: PdfFixture.valido.data))
        let (downloader, destino) = make()

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.httpError))
        #expect(!FileManager.default.fileExists(atPath: destino.path))
    }

    @Test("Una página de error con código 200 se rechaza por el tipo declarado")
    func anErrorPageWithTwoHundredIsRefusedByItsDeclaredType() async {
        // El caso que da nombre a la historia 2: el servicio responde «correctamente» y lo que
        // devuelve no es el anuncio.
        StubURLProtocol.set(
            StubResponse(contentType: "text/html; charset=utf-8", body: PdfFixture.paginaError.data)
        )
        let (downloader, destino) = make()

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.unexpectedType))
        #expect(!FileManager.default.fileExists(atPath: destino.path))
    }

    @Test("Sin tipo declarado tampoco se da por bueno")
    func noDeclaredTypeIsNotGoodEnough() async {
        StubURLProtocol.set(StubResponse(contentType: nil, body: PdfFixture.valido.data))
        let (downloader, destino) = make()

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.unexpectedType))
    }

    @Test("Lo que se declara documento portátil y no lo es se rechaza por sus primeros bytes")
    func whatClaimsToBeAPdfAndIsNotIsRefusedByItsFirstBytes() async {
        // **Ésta es la respuesta fabricada para engañar**: el tipo declarado es correcto y el
        // contenido no. Sin mirar los bytes, se habría presentado como documento oficial.
        StubURLProtocol.set(StubResponse(body: PdfFixture.declaradoPdfNoLoEs.data))
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.notAPdf))
    }

    @Test("Un cuerpo más corto que la firma tampoco cuela")
    func aBodyShorterThanTheSignatureDoesNotSlipThrough() async {
        StubURLProtocol.set(StubResponse(body: Data("%PD".utf8)))
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.notAPdf))
    }

    @Test("Una longitud declarada por encima del tope se rechaza sin leer el cuerpo")
    func aDeclaredLengthAboveTheCapIsRefusedWithoutReadingTheBody() async {
        var grande = Data("%PDF-".utf8)
        grande.append(Data(count: Int(HttpDocumentDownloader.maxDocumentBytes) + 1))
        StubURLProtocol.set(StubResponse(body: grande))
        let (downloader, destino) = make()

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.tooLarge))
        #expect(!FileManager.default.fileExists(atPath: destino.path))
    }

    @Test("Un fallo de red se rechaza como tal")
    func aNetworkFailureIsRefusedAsSuch() async {
        StubURLProtocol.set(StubResponse(error: URLError(.notConnectedToInternet)))
        let (downloader, destino) = make()

        #expect(await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
            == .rejected(.network))
    }

    @Test("No se puede escribir en el destino: se rechaza por almacenamiento, no por red")
    func anUnwritableDestinationIsRefusedAsStorage() async {
        // Es el camino de STAB-002: el disco lleno. Lo que importa es que **llegue como fallo**,
        // no que se pierda.
        StubURLProtocol.set(StubResponse(body: PdfFixture.valido.data))
        let downloader = HttpDocumentDownloader(session: StubURLProtocol.session())
        let imposible = URL(fileURLWithPath: "/no-existe-este-directorio/documento.pdf.part")

        #expect(await downloader.download(from: Self.url, into: imposible, progress: { _, _ in })
            == .rejected(.storage))
    }

    // MARK: - El tope, de verdad

    @Test("Un documento en el tope del tamaño se descarga dentro del presupuesto")
    func aDocumentAtTheSizeCapDownloadsWithinBudget() async {
        // **Es la cifra que la decisión D-502 dejó abierta.** La iteración de `AsyncBytes` es byte
        // a byte —no hay API pública por trozos— y había que medir si eso aguanta veinticinco
        // megas antes de dar por buena la elección frente a la descarga nativa a disco, que
        // transmite sola pero pierde el rechazo temprano por cabeceras y obliga a releer el fichero
        // entero para la huella.
        //
        // **Medido: 1,84 s** para 25 MB, con la huella y la escritura incluidas, y sin red de por
        // medio. El presupuesto de SC-003 son diez segundos **con** la red. Aguanta, y esta prueba
        // es lo que avisará si alguien toca el tamaño del trozo o la reserva del acumulador.
        var grande = Data("%PDF-1.4\n".utf8)
        grande.append(Data(count: Int(HttpDocumentDownloader.maxDocumentBytes) - grande.count))
        StubURLProtocol.set(StubResponse(body: grande, chunkSize: 256 * 1024))
        let (downloader, destino) = make()
        defer { try? FileManager.default.removeItem(at: destino) }

        let inicio = DispatchTime.now().uptimeNanoseconds
        let resultado = await downloader.download(from: Self.url, into: destino, progress: { _, _ in })
        let segundos = Double(DispatchTime.now().uptimeNanoseconds - inicio) / 1_000_000_000

        guard case .downloaded(let bytes, _) = resultado else {
            Issue.record("Justo en el tope todavía cabe: \(resultado)"); return
        }
        #expect(bytes == HttpDocumentDownloader.maxDocumentBytes)
        #expect(segundos < 5, Comment(rawValue: "25 MB han tardado \(segundos) s"))
    }

    // MARK: - Ayudas

    private func make() -> (HttpDocumentDownloader, URL) {
        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent("boc-test-\(UUID().uuidString).pdf.part")
        return (HttpDocumentDownloader(session: StubURLProtocol.session()), destino)
    }
}
