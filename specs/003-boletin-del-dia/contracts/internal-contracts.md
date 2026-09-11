# Contratos internos: boletín del día

La aplicación no expone interfaces externas. Los contratos que importan son **los límites entre
capas**, y lo que sigue es lo que cada una promete a la de al lado. **Romper cualquiera de estas
promesas debe romper una prueba**; donde no la haya, está dicho.

Los bloques de código son **firmas, no implementaciones**.

---

## 1 · `Domain` hacia el resto del mundo

```swift
protocol PublicationRepository: Sendable {
    /// Emite la lista completa cada vez que lo guardado cambia. **Nunca lanza.**
    /// La tarea que bombea la observación muere con el flujo (research.md D-302).
    func observePublications(_ selection: HomeSelection) -> AsyncStream<AppResult<[Publication]>>

    /// La cabecera editorial: denominación, fecha —opcional— y recuento.
    func observeHeader(_ selection: HomeSelection) -> AsyncStream<AppResult<BulletinHeader>>

    /// `true` si lo guardado tiene más de treinta minutos, o si no hay marca.
    func isCacheStale() async -> Bool

    /// Escribe y devuelve un resumen. **No devuelve publicaciones**: para eso está la observación.
    func refresh(force: Bool) async -> AppResult<SyncSummary>
}

protocol BocSectionRepository: Sendable {
    /// El árbol completo, ordenado. Veintitrés filas. No lee de la base: es catálogo.
    func sections() -> [BocSection]
}

protocol HomeSelectionStore: Sendable {
    func load() -> HomeSelection      // resuelve contra el catálogo; si no casa, boletín del día
    func save(_ selection: HomeSelection)
}
```

**Reglas que valen para los tres**, y son las de la casa:

- **Nunca lanzan.** El error viaja como `DomainError` dentro de `AppResult`.
- **Una lista vacía es `success([])`**, no un fallo. «Vacío» y «error» se distinguen en la pantalla.
- **La cancelación se repropaga**, nunca se traduce.
- Las excepciones se capturan y se traducen **dentro** de `Data`, y todo `catch` informa por
  `CrashReporter.log`. Nunca el título de una publicación.

### Política de `refresh(force:)` — cinco filas, y cada una tiene su prueba

| Situación | Qué devuelve | Qué ven los flujos |
|---|---|---|
| Todas las fuentes responden | `success(summary)` con `failedFeeds == 0` | Lo escrito, conforme se escribe |
| Algunas fuentes fallan | `success(summary)` con `failedFeeds > 0` | Lo de las que sí respondieron. **Ningún mensaje de error** |
| Todas fallan, hay contenido guardado | `success(summary)` con `allFailed == true` | Lo guardado, intacto. La pantalla enciende `isOffline` |
| Todas fallan, no hay nada guardado | `failure(.network)` | Lista vacía. La pantalla muestra error con reintento |
| Caché fresca y `force == false` | `success` con resumen vacío, **sin tocar la red** | Lo guardado |

> **`force` es lo único que distingue las dos entradas.** El arranque llama con `force: false` y
> respeta la caducidad de treinta minutos (FR-023); el gesto de deslizar llama con `force: true` y
> **siempre** sale a la red (FR-024). No hay una tercera política escondida.

---

## 2 · `Data` hacia dentro

### La descarga

```swift
protocol FeedDownloader: Sendable {
    func fetch(_ definition: BocFeedDefinition, knownBodyHash: String?) async -> FeedFetchResult
}

enum FeedFetchResult: Sendable {
    case fetched(body: Data, bodyHash: String)
    case notModified                      // la huella coincide con la conocida
    case failed(FeedFailure)
}
```

> **Es la única interfaz del proyecto que puede fallar sin lanzar**, y es deliberado: devuelve el
> fallo como valor para que el orquestador siga con las demás fuentes sin escaleras de `catch`. Es lo
> que hace FR-004 barato en lugar de laborioso.

**Garantías que promete, y que se prueban con un protocolo de URL de prueba** (D-311):

- **Solo HTTPS**, comprobado en la dirección pedida **y en la final**, porque las redirecciones se
  siguen solas.
- Tope de **5 MB contando bytes mientras llegan**, más rechazo previo por la longitud declarada.
- Tiempo de inactividad 45 s y total por fuente 60 s. **No hay tiempo de conexión separado**, y eso
  está decidido, no olvidado.
- Tres intentos con esperas crecientes **más jitter inyectado**, solo ante agotamiento de tiempo,
  error de conexión, 408, 429 y 5xx. **Nunca** ante 400, 401, 403, 404 ni cuerpo inválido.
- `waitsForConnectivity` en `false`: sin red **falla**, no espera.
- `User-Agent` identificable y `Accept` de XML, declarados una sola vez en la configuración.

### El analizador

```swift
@concurrent
func parseFeed(_ body: Data, limit: Int) throws -> RssChannelDTO
```

- **Código puro.** Sin red, sin base, sin reloj.
- **Rechaza el cuerpo antes de analizarlo** si contiene `<!DOCTYPE` o `<!ENTITY`, buscando **bytes**,
  no texto decodificado.
- `shouldResolveExternalEntities = false` **y** `externalEntityResolvingPolicy = .never`.
- Analiza **por nombre de elemento**, nunca por posición ni por orden.
- **Ignora lo desconocido** en lugar de fallar.
- Tope de **500 publicaciones** por fuente.
- **Un item inválido no aborta el canal**: se omite y se cuenta.
- Comprueba cancelación al cerrar cada item y aborta si la hay.
- **Acumula el texto y lo confirma al cerrar el elemento**, porque llega troceado.
- **Si el análisis falla, lanza.** Devolver cero items sería indistinguible de un feed vacío legítimo,
  y un feed vacío legítimo existe.

### El normalizador — las once reglas

```swift
func normalize(_ item: RssItemDTO, from definition: BocFeedDefinition) -> NormalizationOutcome
enum NormalizationOutcome: Sendable { case accepted(Publication); case rejected(RejectionReason) }
```

1. **Mínimos para aceptar**: título no vacío, enlace HTTPS válido y fecha interpretable como
   `AAAA-MM-DD`. Si falta alguno, se rechaza **con motivo**.
2. `sectionCode` y `subsectionCode` salen **siempre** de la definición de la fuente, nunca de
   `categorias`.
3. `categorias` se guarda íntegro y sin normalizar.
4. El tipo de edición se busca **en cualquier componente**. Si no aparece: desconocido, más
   `editionTypeMissing`.
5. Los componentes que empiezan por un código de sección son códigos; el resto, quitado el tipo de
   edición, es la ruta del organismo.
6. Si el código declarado no corresponde al de la fuente: `categoryDoesNotMatchFeed`, **y manda la
   fuente**.
7. Si el tipo de edición no está al final: `categoryOrderUnreliable`. **No se descarta.**
8. Sin `categorias`: `categoriesAbsent`, sección de la fuente y tipo desconocido.
9. **Identidad en cascada**: identificador del enlace → dirección canónica → SHA-256 de fuente, fecha,
   título y categorías. Se registra cuál en `idSource`.
10. `issuer`: el último elemento de la ruta del organismo; si no hay ruta, el texto anterior al primer
    dos puntos del título. Es **auxiliar** y puede quedar nulo.
11. **El título se guarda entero.** Recortar es cosa de la pantalla.

### El coordinador

```swift
actor FeedSyncCoordinator {
    func sync(force: Bool) async -> SyncSummary   // la segunda llamada espera y comparte resultado
    func cancel()
}
```

- Tope de **cuatro** fuentes simultáneas, con ventana explícita.
- **Escribe el padre**, una transacción por fuente, conforme terminan.
- Una sola sincronización viva en todo el proceso.

---

## 3 · Presentación

```swift
@MainActor @Observable
final class HomeViewModel {
    private(set) var state: HomeUiState
    func apply(_ selection: HomeSelection) async   // la llama .task(id:) de la vista
    func onRefresh() async                         // deslizar: force = true
    func onRetry() async
}

@MainActor @Observable
final class MainViewModel {
    private(set) var state: MainUiState
    func onSelect(_ selection: HomeSelection)      // desde el panel o desde los chips
    func onToggleExpanded(_ sectionCode: String)
    func onSelectTab(_ tab: MainTab)
}
```

**Contrato del modelo de pantalla**, heredado y ampliado:

- `apply(_:)` **no retorna hasta haber publicado el primer estado**, para que la prueba pueda afirmar
  en la línea siguiente.
- La analítica de vista de pantalla se emite **una vez por instancia**, en el inicializador.
- Antes de publicar se comprueba la cancelación.
- **Ningún error de dominio se pinta como código.** La pantalla dice frases; el registro dice motivos.
- **El abierto/cerrado del panel no está en ningún modelo de pantalla**: es `@State` de `MainView`.

**Vistas sin estado**, todas previsualizables y con todos sus datos por parámetro:

```swift
HomeContentView(state:onRefresh:onRetry:onSelect:onOpenDrawer:onSearch:onInfo:onShare:onSave:)
BulletinHeaderView(header:)
SectionChipRow(chips:selectedCode:style:onSelect:)      // sirve a las dos filas
PublicationCard(publication:sectionName:colorGroup:onShare:onSave:)
PublicationCardSkeleton()
OfflineBanner()
SectionsDrawer(state:onSelect:onToggleExpanded:onDismiss:)
```

---

## 4 · Cableado

`AppContainer` gana: la base, el descargador, el coordinador, los tres repositorios, el almacén de la
selección y la fuente de aleatoriedad. Todo por inicializador, todo detrás de un protocolo de
`Domain`, y **con valor por defecto** para no romper las llamadas existentes de `AppContainerTests`.

`PrepareStartupUseCase` gana un paso: abrir y migrar la base. Un fallo ahí es un desenlace de la
portada (D-305).

---

## 5 · Identificadores de accesibilidad

Son **contrato**, no decoración: las pruebas de interfaz buscan por identificador y **nunca por
texto**, porque «BOC Cantabria» aparece en la barra superior y en la cabecera del panel, y «Boletín de
hoy» en la cabecera editorial y en el primer chip. Con el panel montado siempre (D-320), cada una de
esas cadenas existe por duplicado incluso con el panel cerrado.

| Identificador | Qué marca |
|---|---|
| `home_skeleton` | Los marcadores de la primera carga |
| `home_content` | El listado con publicaciones |
| `home_empty` | El estado vacío |
| `home_error` | El estado de error |
| `home_retry` | El botón de reintentar |
| `home_offline_banner` | El aviso de falta de conexión |
| `home_header` | La cabecera editorial |
| `home_header_date` | La fecha **con su rótulo** |
| `home_header_count` | El distintivo del recuento |
| `home_section_chips` | La primera fila |
| `home_subsection_chips` | La segunda fila; **no existe cuando no procede** |
| `chip_<code>` | Un chip concreto; `chip_today` para el primero |
| `home_menu` · `home_search` · `home_info` | Las tres acciones de la barra superior |
| `publication_card_<n>` | La enésima tarjeta |
| `publication_share` · `publication_save` | Las acciones de la tarjeta |
| `sections_drawer` | El panel |
| `sections_drawer_scrim` | El velo. Se toca para cerrar |
| `sections_drawer_dismiss` | La flecha de la cabecera |
| `section_row_<code>` · `section_toggle_<code>` | Fila y chevron de una sección |
| `tab_home` · `tab_search` · `tab_saved` | Los tres destinos |
| `coming_soon` | El marcador de Buscar y Guardados |

**Dos reglas sobre cómo se buscan**, las dos heredadas y las dos caras: se busca **sin fijar el tipo**
—`app.descendants(matching: .any).matching(identifier:)`—, porque un contenedor de SwiftUI no aparece
como `otherElements`; y todo contenedor que tenga que encontrarse se declara
`.accessibilityElement(children: .contain)` **antes** del identificador, porque si no, no entra en el
árbol.

---

## 6 · Costura de las pruebas de interfaz

**Dos argumentos, los mismos que hoy.** `-boc-content-scenario=` **desaparece**.

| Argumento | Valores | Qué hace |
|---|---|---|
| `-boc-data-scenario=` | `today` · `empty` · `failing` · `offline` · `slow` | Siembra la base con las muestras pasadas por el analizador real, en memoria o fichero temporal |
| `-boc-startup-scenario=` | `ready` · `offline` · `updateRequired` · `maintenance` · `slow` | Sin cambios respecto a la 002 |

Además, sin tocar una línea de producción, las pruebas de interfaz fijan idioma y región y pueden
sembrar la selección de Inicio, porque el sistema de preferencias lee el dominio de argumentos por su
cuenta (D-316, D-318).

---

## 7 · Lo que esta feature NO cambia

- **La portada** sigue siendo un conmutador y no entra en la pila. Lo único que cambia es que su
  comprobación previa hace un trabajo más.
- **La telemetría** sigue tras `AnalyticsTracker` y `CrashReporter`, y `TelemetryBundle` no se toca.
- **El sistema de diseño** no se rehace: se le añaden seis tokens de color y ni uno más.
- **Las reglas 7 y 8** —el color y el tema del sistema— quedan intactas.
- **El identificador de paquete, el proyecto de Firebase y los planes de prueba** no se tocan.
- **El documento en PDF no se toca**: se guarda su enlace y nada más. Descargarlo, validarlo y
  calcular su huella es la feature siguiente.
