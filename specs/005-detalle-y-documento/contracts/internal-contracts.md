# Contratos internos: el detalle, el documento validado y el visor

**Un apunte de vocabulario, porque los tres documentos hablan a públicos distintos.** La
especificación nombra las cosas por su función —«suma de verificación», «documento portátil», «canal
seguro», «el marco del visor»— porque describe qué debe ocurrir y tiene que sobrevivir a un cambio de
tecnología. Aquí y en `tasks.md` se llaman por su nombre técnico —huella SHA-256, PDF, HTTPS,
PDFKit—. **Son las mismas cosas**, y decirlo evita que alguien que lea solo uno de los dos crea que
son dos.

La aplicación no expone interfaces externas. Los contratos que importan son **los límites entre
capas**, y esta feature toca casi todos. Los bloques de código son **firmas, no implementaciones**.

---

## 1 · Lo que NO cambia, y va primero por ser lo más importante

```swift
// Domain
enum DomainError { case network, storage, cancelled, unknown }   // CUATRO. No crece
struct Publication { … }                                          // sin un campo nuevo

// Data
// BocMigrations: sin migración. El esquema se queda en "v1"
// PublicationQueries: gana UNA consulta de lectura y NINGUNA de escritura

// UI
struct HomeUiState { … }                                          // sin un campo nuevo
```

Si una tarea acaba abriendo `BocMigrations.swift`, algo se ha desviado del plan.

---

## 2 · Domain

### 2.1 Modelos nuevos

```swift
struct OfficialDocument: Sendable, Hashable {
    let externalKey: String
    let localPath: String
    let byteCount: Int64
    let checksum: String
    let lastUsedAt: Date

    static let unknownChecksum: String
    static func isValidChecksum(_ value: String) -> Bool
}

enum DocumentStatus: Sendable, Equatable {
    case absent
    case downloading(bytesRead: Int64, totalBytes: Int64?)
    case available(OfficialDocument)
    case failed(DomainError)
    var isTerminal: Bool { get }
}

enum ShareTarget: Sendable, Equatable {
    case document(SharedDocument)
    case link(url: URL, reason: LinkReason)
}
enum LinkReason: Sendable, Equatable { case noConnection }

struct SharedDocument: Sendable, Hashable, Identifiable {
    let externalKey: String
    let fileName: String
    let localPath: String?
    var id: String { externalKey }
}

enum DetailTab: String, Sendable, CaseIterable {
    case document, aiSummary
    static func restored(from raw: String) -> DetailTab
}
```

### 2.2 Repositorios

```swift
protocol DocumentRepository: Sendable {
    func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus>
    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument>
    func releaseUnused() async
}

protocol PublicationRepository: Sendable {                        // AMPLIADO, +1 método
    func observePublication(externalKey: String) -> AsyncStream<AppResult<Publication?>>
    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>>
    func observeHeader(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>>
    func isCacheStale() async -> Bool
    func refresh(force: Bool) async -> AppResult<SyncSummary>
}
```

**Ninguno lanza.** El fallo viaja como `DomainError` dentro de `AppResult`; la cancelación se
repropaga; las excepciones se traducen dentro de `Data`.

### 2.3 Casos de uso

```swift
struct ObservePublicationUseCase: Sendable {
    func callAsFunction(_ externalKey: String) -> AsyncStream<AppResult<Publication?>>
}
struct ObserveOfficialDocumentUseCase: Sendable {
    func callAsFunction(_ externalKey: String) -> AsyncStream<DocumentStatus>
}
struct OpenOfficialDocumentUseCase: Sendable {
    func callAsFunction(_ publication: Publication) async -> AppResult<OfficialDocument>
}
struct ShareOfficialDocumentUseCase: Sendable {                   // el ÚNICO sitio con la regla de degradación
    func callAsFunction(_ publication: Publication) async -> ShareTarget
}
```

---

## 3 · Data

### 3.1 El descargador

```swift
protocol DocumentDownloader: Sendable {
    func download(from url: URL, into destination: URL,
                  progress: @Sendable (Int64, Int64?) async -> Void) async -> DocumentDownloadResult
}
```

**Orden de comprobación — es contrato, no implementación:**

| # | Cuándo | Qué | Rechazo |
|---|---|---|---|
| 1 | **antes de conectar** | esquema `https` | `insecureScheme` |
| 2 | **antes de conectar** | host `boc.cantabria.es` | `unexpectedHost` |
| 3 | con las cabeceras | host del destino **final**, tras redirecciones | `unexpectedHost` |
| 4 | con las cabeceras | estado HTTP | `httpError` |
| 5 | con las cabeceras | tipo declarado contiene `application/pdf` | `unexpectedType` |
| 6 | con las cabeceras | longitud declarada por encima del tope | `tooLarge` |
| 7 | primeros 5 bytes | `%PDF-` | `notAPdf` |
| 8 | **durante el cuerpo** | tope, contando mientras llega | `tooLarge` |
| 9 | al escribir | fallo de disco | `storage` |
| 10 | al terminar | huella calculada al vuelo | — |

**Constantes**: tope 25 MB · trozo 64 KiB · host `boc.cantabria.es` · **un solo intento** · límites de
tiempo propios, más largos que los del feed.

### 3.2 La caché

```swift
protocol DocumentCache: Sendable {
    func get(_ externalKey: String) -> OfficialDocument?
    func stage(_ externalKey: String) -> URL
    func commit(_ externalKey: String, from part: URL, byteCount: Int64, checksum: String) -> OfficialDocument?
    func discard(_ part: URL)
    func evict(maxBytes: Int64, keeping inUse: Set<String>)
}
```

**El orden de `commit` es contrato**: lateral `.part` → renombrar lateral → renombrar documento → si
el último falla, borrar el lateral y devolver `nil`. Invariante: **documento visible ⇒ lateral válido**.

**La lectura del lateral es contrato**: recortar espacios y exigir 64 hexadecimales en minúscula;
cualquier otra cosa es `unknownChecksum` y el documento **se sirve**.

### 3.3 El almacén

`DocumentStore` es un `actor` y **el tipo de su trabajo en vuelo es parte del contrato**:

```swift
Task<AppResult<OfficialDocument>, Never>    // Never. Si alguien pone Error, vuelve el bug de STAB-002
```

---

## 4 · UI

### 4.1 Modelos de pantalla

```swift
@MainActor @Observable
final class PublicationDetailViewModel {
    static let screenName = "publication_detail"
    private(set) var state: PublicationDetailUiState
    func onAppear() async
    func onSelectTab(_ tab: DetailTab)
    func onDocumentTabShown() async      // FR-016: aquí, y no en onAppear
    func onRetryDocument() async
    func onShare() async
    func onShareConsumed()
}

@MainActor @Observable
final class PdfViewerViewModel {
    static let screenName = "pdf_viewer"
    private(set) var state: PdfViewerUiState
    func onAppear() async
    func onRetry() async
}
```

### 4.2 La tarjeta, ampliada

```swift
struct PublicationCard: View {
    let publication: Publication
    var share: ShareTarget            // NUEVO: lo decide el llamante (D-518)
    var onOpen: (() -> Void)?         // NUEVO: gesto, no enlace de navegación (D-519)
    var onShare: (() -> Void)?
    var onSave: (() -> Void)?
}
```

**Sigue sin estado.** Los cuatro peldaños de `PublicationCard.Typography` **no se tocan**.

### 4.3 Identificadores de accesibilidad — SON CONTRATO

Los que **ya existen y no pueden cambiar**: `publication_card_<n>`, `publication_share`,
`publication_save`, `publication_date`, `home_content`, `home_root`, `coming_soon`.

Los **nuevos**:

| Zona | Identificadores |
|---|---|
| Barra superior | `detail_back` · `detail_save` · `detail_share` |
| Cabecera | `detail_header` · `detail_section` · `detail_title` · `detail_issuer` · `detail_date` · `detail_official_badge` |
| Pestañas | `detail_tabs` · `detail_tab_document` · `detail_tab_summary` |
| Contenido | `detail_scroll` · `detail_metadata` · `detail_preview` · `detail_preview_loading` · `detail_preview_error` |
| Barra de acciones | `detail_actions` · `detail_action_open` · `detail_action_ask` |
| Estados | `detail_missing` · `detail_missing_action` · `detail_error` · `detail_retry` |
| Preguntar | `ask_root` · `ask_back` |
| Visor | `pdf_viewer` · `pdf_viewer_loading` · `pdf_viewer_error` · `pdf_viewer_retry` · `pdf_viewer_back` · `pdf_viewer_share` |

**Las dos reglas del árbol, que en este proyecto han costado tres trampas**: un identificador sobre un
contenedor **se propaga a sus descendientes** salvo que se declare `.accessibilityElement(children:
.contain)`; y **no se anidan dos contenedores declarados**, porque el de dentro desaparece.

### 4.4 Navegación

```swift
enum Route: Hashable {
    case publicationDetail(externalKey: String)   // ya existe
    case pdfViewer(externalKey: String)           // NUEVO
    case ask(externalKey: String)                 // NUEVO
}
```

Las tres viajan **por clave, nunca por objeto**. `ask` lleva la clave aunque el marcador de posición no
la lea: añadir el argumento después obligaría a cambiar una ruta que ya estaría en la calle.

El detalle, el visor y preguntar se apilan **dentro del `NavigationStack` de la pestaña**, y los tres
declaran `.toolbar(.hidden, for: .tabBar)` (FR-006).

---

## 5 · Telemetría

| Evento | Parámetros | Dónde |
|---|---|---|
| `document_opened` | `cached` = `"true"` / `"false"` | al resolverse la copia local |
| `document_share` | `target` = `"document"` / `"link"` | al decidir el destino |
| `screen_view` | `screen_name` = `publication_detail` / `pdf_viewer` / `ask` | una vez por instancia |

**Ni un título, ni una dirección, ni una clave, ni un nombre de fichero.** Solo recuentos y enumerados.
El motivo exacto de un rechazo va **al registro**, no a analítica.

---

## 6 · Textos

Claves nuevas en `Localizable.xcstrings`, con acceso tipado en `Core/UI/Strings.swift`
(`enum Detail`, `enum PdfViewer`, `enum Share`, `enum Ask`). Los valores literales salen de
`docs/referencia-android/res/strings.xml`, bloque de la feature 004:

`detail_title` · `detail_back` · `detail_share` · `detail_official_badge` ·
`detail_issuer_description` · `detail_date_description` · `detail_tab_document` ·
`detail_tab_summary` · `detail_field_description` · `detail_field_issuer` · `detail_field_section` ·
`detail_field_date` · `detail_field_reference` · `detail_field_official` ·
`detail_field_edition_ordinary` · `detail_field_edition_extraordinary` ·
`detail_field_edition_unknown` · `detail_preview_title` · `detail_preview_loading` ·
`detail_preview_unavailable` · `detail_action_open` · `detail_action_ask` · `detail_missing_title` ·
`detail_missing_body` · `detail_missing_action` · `document_error_network` ·
`document_error_invalid` · `pdf_viewer_loading` · `pdf_viewer_error` · `share_preparing` ·
`share_link_fallback` · `ask_title`

Se **reutilizan** `action_retry`, `coming_soon`, `publication_save`, `publication_share`,
`publication_share_chooser` y `publication_section`.

---

## 7 · Reglas de arquitectura

**Regla 14 — nueva**: nadie fuera de `UI/PDF/` importa PDFKit ni nombra sus tipos. Con **las dos
mitades**, como la 10: importaciones **y** referencias por nombre.

Las trece existentes siguen valiendo. Tres rozan esta feature y hay que tenerlas presentes:

- **Regla 7**: nadie construye un color fuera de `Core/UI/Theme/`. El visor necesita un color de UIKit
  → se construye en el tema (D-522).
- **Regla 11**: nadie usa el reloj del dispositivo fuera de `Core/Util/`. La caché necesita el instante
  → **reloj inyectado**.
- **Regla 12**: nada de tareas desprendidas. El almacén usa tareas poseídas por el actor.

**Y dos números que suben en el mismo cambio**: «trece» en `CLAUDE.md` y «Nueve reglas» en la cabecera
de `ArchitectureRulesTests.swift`, que ya estaba desfasada.
