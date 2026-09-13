//
//  FileDocumentCacheTests.swift
//
//  **Las cuatro pruebas del lateral son la regresión de STAB-001**, el hallazgo de severidad alta
//  de la auditoría de la aplicación de origen: allí un lateral presente pero vacío no se trataba
//  como ausente, la comprobación de formato saltaba y **la aplicación se cerraba** al abrir esa
//  publicación, y otra vez en cada reintento.
//

import CryptoKit
import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Caché de documentos")
struct FileDocumentCacheTests {

    // MARK: - Guardar y recuperar

    @Test("Lo guardado se recupera con su recuento y su huella")
    func whatIsStoredComesBackWithItsCountAndFingerprint() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }

        let documento = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                                  checksum: PdfFixture.valido.sha256)

        #expect(documento.byteCount == Int64(PdfFixture.valido.data.count))
        #expect(documento.checksum == PdfFixture.valido.sha256)
        #expect(!documento.hasUnknownChecksum)

        let recuperado = cache.get("boc:1")
        #expect(recuperado?.checksum == PdfFixture.valido.sha256)
        #expect(recuperado?.localPath == documento.localPath)
    }

    @Test("El nombre del fichero NO es la clave: una clave con barras y dos puntos no se cuela en la ruta")
    func theFileNameIsNotTheKey() throws {
        // La clave viene de la red. `boc:439765` cuando el enlace trae identificador, y **una
        // dirección entera** cuando no. Una clave que se cuela en una ruta es una forma conocida
        // de escribir donde no se debe.
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }

        let clave = "https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=1"
        let documento = try store(in: cache, key: clave, bytes: PdfFixture.valido.data,
                                  checksum: PdfFixture.valido.sha256)

        let nombre = URL(fileURLWithPath: documento.localPath).lastPathComponent
        #expect(nombre == "\(sha256Hex(clave)).pdf")
        #expect(!nombre.contains("/"))
        #expect(!nombre.contains(":"))
        // Y está **dentro** del directorio, no en cualquier otro sitio.
        #expect(documento.localPath.hasPrefix(directorio.path))
    }

    @Test("El temporal no es visible: solo lo es el documento ya completo")
    func theTemporaryFileIsNeverVisible() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }

        let part = cache.stage("boc:1")
        try PdfFixture.valido.data.write(to: part)

        // Con el temporal escrito y sin confirmar, la caché **no tiene nada**.
        #expect(cache.get("boc:1") == nil)
        #expect(part.pathExtension == "part")

        _ = cache.commit("boc:1", from: part, byteCount: 609, checksum: PdfFixture.valido.sha256)
        #expect(cache.get("boc:1") != nil)
        #expect(!FileManager.default.fileExists(atPath: part.path))
    }

    // MARK: - El lateral (STAB-001)

    @Test(
        "Un lateral que no se puede creer es huella perdida, y el documento se sirve IGUAL",
        arguments: [
            SidecarCase(name: "vacío", contents: ""),
            SidecarCase(name: "truncado", contents: "abc"),
            SidecarCase(name: "en mayúsculas", contents: String(repeating: "A", count: 64)),
            SidecarCase(name: "con basura", contents: "no soy una huella"),
            SidecarCase(name: "con un salto de línea de más", contents: String(repeating: "a", count: 63) + "\n"),
        ]
    )
    func anUnbelievableSidecarIsALostFingerprintAndTheDocumentIsStillServed(_ caso: SidecarCase) throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }
        _ = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                      checksum: PdfFixture.valido.sha256)

        // Se estropea el lateral, exactamente como se estropeó en el dispositivo de verdad.
        let lateral = directorio.appendingPathComponent("\(sha256Hex("boc:1")).sha256")
        try Data(caso.contents.utf8).write(to: lateral)

        let recuperado = cache.get("boc:1")

        // **El documento sigue ahí.** Sus bytes ya se verificaron al descargarlos.
        #expect(recuperado != nil, "«\(caso.name)» no puede hacer desaparecer el documento")
        #expect(recuperado?.hasUnknownChecksum == true, "«\(caso.name)» debería dar huella perdida")
    }

    @Test("Un lateral ausente se comporta exactamente igual que uno ilegible")
    func anAbsentSidecarBehavesExactlyLikeAnUnreadableOne() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }
        _ = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                      checksum: PdfFixture.valido.sha256)

        try FileManager.default.removeItem(
            at: directorio.appendingPathComponent("\(sha256Hex("boc:1")).sha256")
        )

        #expect(cache.get("boc:1")?.hasUnknownChecksum == true)
    }

    @Test("El lateral se escribe ANTES que el documento: si hay documento, hay huella válida")
    func theSidecarIsWrittenBeforeTheDocument() throws {
        // No se puede observar el orden desde fuera, pero sí su consecuencia: **nunca** existe un
        // documento visible cuyo lateral no esté. El orden importa porque la huella tiene
        // consumidor, y una ventana sin ella declara obsoleto un resumen que era bueno.
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }
        _ = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                      checksum: PdfFixture.valido.sha256)

        let base = directorio.appendingPathComponent(sha256Hex("boc:1"))
        #expect(FileManager.default.fileExists(atPath: base.appendingPathExtension("pdf").path))
        #expect(FileManager.default.fileExists(atPath: base.appendingPathExtension("sha256").path))
        // Y ningún temporal de ninguno de los dos.
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathExtension("pdf").appendingPathExtension("part").path))
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathExtension("sha256").appendingPathExtension("part").path))
    }

    @Test("Si el documento no llega a hacerse visible, el lateral no se queda solo")
    func anOrphanSidecarIsNeverLeftBehind() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }

        // Un temporal que no existe: el renombrado del documento fallará.
        let inexistente = directorio.appendingPathComponent("no-existe.part")
        let resultado = cache.commit("boc:1", from: inexistente, byteCount: 10,
                                     checksum: PdfFixture.valido.sha256)

        #expect(resultado == nil)
        let base = directorio.appendingPathComponent(sha256Hex("boc:1"))
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathExtension("sha256").path),
                "Un lateral que apunta a un documento que no existe es peor que no tener lateral")
    }

    @Test("Un documento visible pero vacío se trata como ausente, y la descarga lo repara")
    func aVisibleButEmptyDocumentIsTreatedAsAbsent() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }
        _ = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                      checksum: PdfFixture.valido.sha256)

        try Data().write(to: directorio.appendingPathComponent("\(sha256Hex("boc:1")).pdf"))

        #expect(cache.get("boc:1") == nil)
    }

    // MARK: - Retirada

    @Test("Se retira lo más antiguo hasta bajar del presupuesto")
    func theOldestIsEvictedUntilTheBudgetIsMet() throws {
        let reloj = ManualClock()
        let (cache, directorio) = make(clock: reloj)
        defer { try? FileManager.default.removeItem(at: directorio) }

        // Tres documentos, usados en instantes distintos. **Con el reloj congelado este filtro
        // sería inerte**, que es una trampa que este proyecto ya tiene anotada.
        let bytes = PdfFixture.valido.data
        for (indice, clave) in ["boc:viejo", "boc:medio", "boc:nuevo"].enumerated() {
            _ = try store(in: cache, key: clave, bytes: bytes, checksum: PdfFixture.valido.sha256)
            await_advance(reloj, seconds: Double((indice + 1) * 3600))
        }

        // Presupuesto para dos.
        cache.evict(maxBytes: Int64(bytes.count * 2), keeping: [])

        #expect(cache.get("boc:viejo") == nil, "El más antiguo es el que se va")
        #expect(cache.get("boc:medio") != nil)
        #expect(cache.get("boc:nuevo") != nil)
    }

    @Test("Lo que está en uso no se retira, aunque sea lo más antiguo")
    func whatIsInUseIsNeverEvicted() throws {
        let reloj = ManualClock()
        let (cache, directorio) = make(clock: reloj)
        defer { try? FileManager.default.removeItem(at: directorio) }

        let bytes = PdfFixture.valido.data
        for clave in ["boc:leyendose", "boc:otro"] {
            _ = try store(in: cache, key: clave, bytes: bytes, checksum: PdfFixture.valido.sha256)
            await_advance(reloj, seconds: 3600)
        }

        // Presupuesto para ninguno, pero uno se está leyendo: retirarlo dejaría al visor con un
        // fichero que acaba de desaparecer.
        cache.evict(maxBytes: 0, keeping: ["boc:leyendose"])

        #expect(cache.get("boc:leyendose") != nil)
        #expect(cache.get("boc:otro") == nil)
    }

    @Test("La retirada barre los temporales huérfanos, que no son caché sino restos")
    func evictionSweepsOrphanTemporaries() throws {
        let (cache, directorio) = make()
        defer { try? FileManager.default.removeItem(at: directorio) }

        let huerfano = cache.stage("boc:abandonado")
        try Data("a medias".utf8).write(to: huerfano)

        cache.evict(maxBytes: FileDocumentCache.defaultBudget, keeping: [])

        #expect(!FileManager.default.fileExists(atPath: huerfano.path))
    }

    @Test("Retirar un documento se lleva también su lateral")
    func evictingADocumentTakesItsSidecarWithIt() throws {
        let reloj = ManualClock()
        let (cache, directorio) = make(clock: reloj)
        defer { try? FileManager.default.removeItem(at: directorio) }
        _ = try store(in: cache, key: "boc:1", bytes: PdfFixture.valido.data,
                      checksum: PdfFixture.valido.sha256)

        cache.evict(maxBytes: 0, keeping: [])

        let base = directorio.appendingPathComponent(sha256Hex("boc:1"))
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathExtension("pdf").path))
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathExtension("sha256").path))
    }

    // MARK: - Ayudas

    struct SidecarCase: Sendable {
        let name: String
        let contents: String
    }

    private func make(clock: AppClock = ImmediateClock()) -> (FileDocumentCache, URL) {
        let directorio = FileManager.default.temporaryDirectory
            .appendingPathComponent("boc-cache-\(UUID().uuidString)", isDirectory: true)
        let cache = FileDocumentCache(
            directory: directorio, clock: clock, crashReporter: NoOpCrashReporter()
        )
        return (cache, directorio)
    }

    private func store(
        in cache: FileDocumentCache, key: String, bytes: Data, checksum: String
    ) throws -> OfficialDocument {
        let part = cache.stage(key)
        try bytes.write(to: part)
        guard let documento = cache.commit(key, from: part, byteCount: Int64(bytes.count),
                                           checksum: checksum) else {
            throw CacheTestError.commitFailed
        }
        return documento
    }

    private func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// `ManualClock.advance` es asíncrono; aquí solo hace falta mover el instante que devuelve
    /// `now()`, y la prueba es síncrona.
    private func await_advance(_ clock: ManualClock, seconds: Double) {
        clock.advanceNow(by: seconds)
    }

    enum CacheTestError: Error { case commitFailed }
}
