# Data Model: Del titular al documento oficial

**Feature**: `005-detalle-y-documento` | **Fase**: 1 | **Fecha**: 12 de septiembre de 2026

La 003 dejó la `Publication` guardada y observable. Esta feature añade **una sola cosa**: la copia
local del documento oficial, y el estado de esa copia.

**Sin migración de base de datos.** Ni una tabla, ni una columna, ni un índice. La copia local se
deriva del sistema de ficheros (`research.md` **D-501**).

---

## 1 · La cadena completa

```text
Tarjeta pulsada ──▶ Route.publicationDetail(externalKey)
                         │
                         ├── ObservePublicationUseCase(externalKey) ──▶ Publication?     (NUEVO)
                         │        nil = ya no está guardada. No es un fallo (FR-004)
                         │
                         └── ObserveOfficialDocumentUseCase(externalKey) ──▶ DocumentStatus
                                    │
                                    │  .absent → se pide al mostrarse la pestaña (FR-016)
                                    ▼
                          DocumentStore (actor)
                                    │  coalescencia · espectadores · estado terminal
                                    ▼
                          DocumentCache ──falla──▶ DocumentDownloader
                                    │                    │ https · host · tipo · %PDF- · tope · huella
                                    │◀──.part validado, lateral primero, renombrado──┘
                                    ▼
                          OfficialDocument(localPath) ──▶ PdfViewerView ──▶ PDFView
```

---

## 2 · Dominio (`Domain/Model/`) — Swift puro

### `OfficialDocument`

La copia local del documento de una publicación.

| Campo | Tipo | Regla |
|---|---|---|
| `externalKey` | `String` | A qué publicación pertenece. Es su identidad. No vacío |
| `localPath` | `String` | Dónde está. **`String` y no `URL`**: ver abajo |
| `byteCount` | `Int64` | Lo que ocupa. Base del tope de la caché. Mayor que cero |
| `checksum` | `String` | La huella, 64 hexadecimales en minúscula, **o `unknownChecksum`** |
| `lastUsedAt` | `Date` | Base de la retirada por antigüedad. Lo pone el reloj **inyectado** |

```swift
static let unknownChecksum = String(repeating: "0", count: 64)
static func isValidChecksum(_ value: String) -> Bool   // 64 hex en minúscula, exactamente
```

**`localPath` es `String` y no `URL`**, igual que en la aplicación de origen y por la misma razón
ampliada: `URL` de Foundation es un tipo de plataforma con semántica de sistema de ficheros, y el
dominio no debe tener opinión sobre rutas. `Publication.documentUrl` **sí** es `URL` porque es una
dirección de red, que es un concepto del problema, no del dispositivo.

**No lleva la dirección de origen.** La tiene la `Publication`, y duplicarla aquí crearía una segunda
verdad que puede quedarse atrás (D-501).

**`unknownChecksum` es público y es parte del contrato.** Un lateral ausente, vacío, truncado o
malformado produce este valor, **no** un fallo y **no** un `nil` que alguien pueda forzar (FR-024,
D-506). El documento se sirve igualmente.

### `DocumentStatus`

En qué punto está la copia local. Es **lo único** que el detalle, el visor y compartir observan.

```text
DocumentStatus
├── absent                                        nunca pedido, retirado de la caché, o cancelado
├── downloading(bytesRead: Int64, totalBytes: Int64?)
├── available(OfficialDocument)
└── failed(DomainError)

var isTerminal: Bool          // todo menos .downloading
```

`totalBytes` es opcional **a propósito**: el servicio puede no declarar la longitud, y entonces la
barra tiene que ser indeterminada, que es la verdad. Un `-1` disfrazado de total pintaría una barra
llena (D-502, nota del rechazo previo).

**`absent` es también el desenlace de una cancelación** (FR-027). Cancelar no es fallar: quien canceló
ya no está mirando, y la próxima visita no debe encontrarse un error que nadie provocó.

### `ShareTarget`

Qué se acabó ofreciendo al compartir, **y por qué**.

```text
ShareTarget
├── document(SharedDocument)         lo normal
└── link(url: URL, reason: LinkReason)

LinkReason
└── noConnection
```

Existe con su motivo porque FR-040 exige **explicar** el caso degradado. Un booleano no puede decir por
qué. Y el enumerado tiene un solo caso a propósito: **ningún otro fallo se disfraza de enlace**; los
demás son `failed`.

### `SharedDocument`

Lo que viaja a la hoja del sistema. Vive en `Domain` porque el nombre visible es una decisión de
producto, no de dibujo.

| Campo | Tipo | Regla |
|---|---|---|
| `externalKey` | `String` | Identidad |
| `fileName` | `String` | El nombre legible, `2026-6695.pdf`. **Nunca la huella** (FR-042, D-505) |
| `localPath` | `String?` | `nil` mientras no esté en caché: el cierre asíncrono lo resolverá |

### `DetailTab`

`document` · `aiSummary`. **Dos**, no tres: «Preguntar» es pantalla propia (FR-014, FR-044).

```swift
static func restored(from raw: String) -> DetailTab   // por nombre, con respaldo. NUNCA init(rawValue:) sin comprobar
```

Restaurar **por nombre y con respaldo** es FR-017 y es una lección ya escrita en este proyecto: una
pestaña retirada entre versiones tumbaría la pantalla al volver de la muerte del proceso, en el único
camino que nadie recorre a mano. `MainTab.restored(from:)` ya lo hace así.

---

## 3 · Contratos de repositorio (`Domain/Repository/`)

```swift
protocol DocumentRepository: Sendable {
    func observeDocument(externalKey: String) -> AsyncStream<DocumentStatus>
    func ensureLocalCopy(_ publication: Publication) async -> AppResult<OfficialDocument>
    func releaseUnused() async
}

protocol PublicationRepository: Sendable {                       // AMPLIADO
    func observePublication(externalKey: String) -> AsyncStream<AppResult<Publication?>>
    // … los cuatro que ya existen, sin tocar
}
```

Reglas heredadas y no negociables: **nunca lanzan**; el fallo viaja como `DomainError` dentro de
`AppResult`; la cancelación se repropaga; las excepciones se traducen dentro de `Data`.

`observePublication` emite `.success(nil)` cuando la publicación ya no está guardada, y eso **no es un
fallo**: es la información que FR-004 necesita (D-512).

`observeDocument` **no** devuelve `AppResult`: `DocumentStatus` ya lleva su propio caso de fallo, y
envolverlo daría dos formas de decir lo mismo.

---

## 4 · Casos de uso (`Domain/UseCase/`)

```swift
ObservePublicationUseCase(repository:)         (_ externalKey: String) -> AsyncStream<AppResult<Publication?>>
ObserveOfficialDocumentUseCase(repository:)    (_ externalKey: String) -> AsyncStream<DocumentStatus>
OpenOfficialDocumentUseCase(repository:)       (_ publication: Publication) async -> AppResult<OfficialDocument>
ShareOfficialDocumentUseCase(documents:connectivity:)
                                               (_ publication: Publication) async -> ShareTarget
```

`ShareOfficialDocumentUseCase` es **el único sitio** donde vive la regla de degradación (FR-041): las
pantallas preguntan y obedecen. Depende de conectividad porque la regla de FR-040 la necesita.

---

## 5 · Capa de datos (`Data/`)

### 5.1 El descargador — `Data/Source/Remote/`

```swift
enum DocumentRejection: String, Sendable, Equatable {
    case insecureScheme, unexpectedHost, unexpectedType, notAPdf, tooLarge, httpError, network, storage, cancelled
}

enum DocumentDownloadResult: Sendable, Equatable {
    case downloaded(byteCount: Int64, checksum: String)
    case rejected(DocumentRejection)
}

protocol DocumentDownloader: Sendable {
    func download(from url: URL, into destination: URL,
                  progress: @Sendable (_ bytesRead: Int64, _ totalBytes: Int64?) async -> Void)
        async -> DocumentDownloadResult
}
```

**El rechazo es valor, no excepción** (D-503). `progress` es asíncrono a propósito: da contrapresión y
evita sembrar una tarea por cada trozo.

**Constantes**: tope `25 * 1024 * 1024`; host `boc.cantabria.es` —**no** `www.cantabria.es`, que es el
de los feeds—; trozo de escritura 64 KiB; firma `%PDF-`; **un solo intento** (D-504); límites de tiempo
propios, más largos que los del feed (D-525).

**`DocumentRejection` no hace crecer `DomainError`**, que sigue teniendo cuatro casos. La traducción:
`network` → `.network`; `storage` → `.storage`; `cancelled` → `.cancelled`; todo lo demás → `.unknown`.
La pantalla hace lo mismo con todos —explicar y ofrecer reintentar—, así que distinguirlos arriba no
cambiaría nada; el motivo exacto viaja **al registro**, que es donde se diagnostica.

### 5.2 La caché — `Data/Source/Local/`

```swift
protocol DocumentCache: Sendable {
    func get(_ externalKey: String) -> OfficialDocument?
    func stage(_ externalKey: String) -> URL                    // la ruta del .part
    func commit(_ externalKey: String, from part: URL, byteCount: Int64, checksum: String) -> OfficialDocument?
    func discard(_ part: URL)
    func evict(maxBytes: Int64, keeping inUse: Set<String>)
}
```

Disposición del directorio (D-505, D-506):

```text
<cachés>/documents/
├── <huella>.pdf            visible SOLO si está completo
├── <huella>.pdf.part       descarga en curso
├── <huella>.sha256         64 hex en minúscula
└── <huella>.sha256.part    escritura en curso
```

**El orden de `commit` es el requisito** (FR-023):

1. escribir `<huella>.sha256.part`
2. renombrarlo a `<huella>.sha256`
3. renombrar `<huella>.pdf.part` a `<huella>.pdf`
4. si (3) falla, **borrar el lateral** y devolver `nil`

Invariante: **documento visible ⇒ lateral válido**. El renombrado dentro del mismo volumen es atómico.

**La lectura del lateral** (FR-024): se recorta el espacio en blanco y se comprueba que sean
exactamente 64 hexadecimales en minúscula. Cualquier otra cosa —ausente, vacío, truncado, en
mayúsculas— devuelve `OfficialDocument.unknownChecksum`, y el documento **se sirve igual**.

`evict` retira por antigüedad de uso hasta el presupuesto (100 MiB), **nunca toca las claves en uso**
(FR-030) y barre los `.part` huérfanos. El instante lo da el **reloj inyectado**: la regla 11 prohíbe
`Date()` fuera de `Core/Util`, y sin reloj inyectado la retirada por antigüedad no se puede probar.

### 5.3 El almacén — `Data/Repository/DocumentStore.swift`

Es un `actor`, y **es el corazón de la feature**. Guarda tres cosas por clave: el estado vigente, las
continuaciones que lo observan y el trabajo en vuelo.

```swift
private struct Job {
    let task: Task<AppResult<OfficialDocument>, Never>   // ← Never NO es un detalle: es FR-028 (D-507)
    var watchers: Int
}
```

**Transiciones**:

```text
   absent ──se muestra la pestaña Documento──▶ downloading ──ok──▶ available
      ▲                                             │                  │
      │                                             │ rechazo / red /  │ retirada de la caché
      │                                             │ fallo al guardar │
      │                                             ▼                  │
      ├──────────── onRetry() ─────────────────  failed ◀──────────────┘
      │                                             
      └──── último espectador se va: se cancela, y el estado vuelve a `absent`, NUNCA a `failed`
```

**Cuatro invariantes, y cada uno tiene prueba** (FR-026 … FR-029):

1. Dos peticiones simultáneas de la misma clave comparten **un** trabajo.
2. Quien espera **no** hereda la cancelación de quien lo inició. Sale del tipo (D-507).
3. **Todo** desenlace publica un estado terminal, y ese estado concuerda con el resultado devuelto.
4. La limpieza —borrar el `.part`, retirar el trabajo, publicar— es **síncrona y aislada al actor**,
   así que ninguna cancelación la interrumpe (D-509). **Dentro de ella no puede haber un `await`.**

Y un guardián de identidad: al publicar `absent` tras una cancelación, solo se publica si el trabajo
que se está limpiando **sigue siendo el registrado**. Sin él, la limpieza de un trabajo viejo pisa el
`downloading` de uno nuevo y la barra desaparece con la descarga en marcha.

---

## 6 · Presentación

### 6.1 Detalle — `UI/Detail/`

```swift
struct PublicationDetailUiState: Equatable {
    var publication: Publication?          // nil mientras carga
    var section: BocSection?
    var isMissing: Bool                    // ya no está guardada (FR-004). NO es un error
    var loadFailed: Bool                   // no se pudo LEER lo guardado. Esto sí lo es
    var selectedTab: DetailTab
    var document: DocumentStatus
    var share: ShareState
}

enum ShareState: Equatable { case idle, preparing, ready(ShareTarget) }
```

`document` y `share` van **fuera** de un enumerado único, y es la misma decisión que `HomeUiState` ya
tomó: son ejes **ortogonales**. Se puede estar preparando algo para compartir mientras el documento ya
está disponible, y meterlo todo en una jerarquía multiplicaría los casos sin que ninguno aportara.

`ready` es un **evento de un solo uso**: se consume y vuelve a `idle`.

> **`loadFailed` se añadió al implementar** y no estaba previsto aquí. El fallo de lectura se
> escribía dentro de `document`, y la observación del documento lo pisaba un instante después: dos
> escrituras del mismo campo desde dos sitios, que es la trampa que la feature del boletín ya dejó
> anotada y que ha vuelto a morder. Cada dato, su campo (`research.md` **D-526**).
>
> **Y `HomeUiState` gana `share`**, que el plan decía que no ganaría: la tarjeta no puede resolver su
> destino de compartir porque hace falta el caso de uso, y una vista sin estado no puede llamarlo.
> Emite el evento y Inicio resuelve, igual que el detalle (`research.md` **D-518**, corregida).

### 6.2 Visor — `UI/PDF/`

```swift
enum PdfViewerUiState: Equatable {
    case loading
    case ready(fileUrl: URL, title: String, pageCount: Int)
    case error(PdfViewerError)
}

enum PdfViewerError: Equatable { case locked, unreadable, document(DomainError) }
```

**Ni `PDFDocument` ni `PDFPage` están aquí, y no por elegancia: no compilarían.** Son `NSObject`
pelados sin anotación de concurrencia, así que no son `Sendable` (D-513). El estado lleva una `URL`, un
título y un entero.

`locked` y `unreadable` son casos **distintos** (FR-036, D-514): protegido con contraseña no es lo
mismo que ilegible, y un documento cifrado pero legible no es ninguno de los dos — se abre.

**La página visible no está en el estado**: vive en el almacenamiento de escena, porque es una posición
de lectura y no algo que el modelo de pantalla decida (D-515).

---

## 7 · Lo que NO cambia, y decirlo importa

- **`Publication` no gana ni un campo.** El título íntegro que FR-008 pide ya está en `title`, y el
  abreviado del visor es `titleWithoutIssuer`, que la 004 ya calculó.
- **El esquema de GRDB no se toca.** Ni migración, ni columna, ni índice. `PublicationQueries` gana una
  consulta de lectura y **ninguna** de escritura.
- **`DomainError` sigue teniendo cuatro casos.**
- ~~**`HomeUiState` no gana ningún campo**~~ — **corregido al implementar: gana `share`.** La
  previsión suponía que la tarjeta derivaría su destino de `isOffline` y lo llevaría dentro, y eso
  no se sostiene. Ver arriba y `research.md` D-518.
- **La regla 13 y la prueba de regresión del borrado siguen valiendo tal cual**: esta feature no añade
  ni una sentencia de escritura sobre `publications`.
