# Contratos internos

La aplicación no expone ninguna interfaz externa: no hay API pública, ni línea de órdenes, ni
servicio. Los contratos relevantes son los **límites entre capas**, y son los que las features
siguientes van a dar por buenos sin volver a leerlos.

---

## 1. `Domain` hacia el resto del mundo

```swift
protocol ContentRepository: Sendable {
    /// Nunca lanza: los fallos viajan en el resultado.
    func contentItems() async -> AppResult<[ContentItem]>
}

struct GetContentItemsUseCase: Sendable {
    init(repository: ContentRepository)
    func callAsFunction() async -> AppResult<[ContentItem]>
}
```

- `contentItems()` **nunca propaga un error lanzado**. Lo que devuelve es un `AppResult`.
- Una colección vacía es `.success([])`, no `.failure`.
- Es **idempotente**: llamarla dos veces no produce efectos secundarios observables.
- **El caso de uso no añade lógica.** Existe para que `UI` no conozca los repositorios y para dar
  un lugar evidente donde ponerla cuando aparezca.

---

## 2. `Data` hacia `Domain`

```swift
protocol ContentRemoteDataSource: Sendable {
    /// Puede lanzar. El repositorio es quien captura y traduce.
    func fetchContentItems() async throws -> [ContentItemDTO]
}

protocol ContentLocalDataSource: Sendable {
    func readContentItems() async -> [ContentItemRecord]
    func writeContentItems(_ items: [ContentItemRecord]) async
}
```

### Política del repositorio

Esta tabla **es el contrato**, y cada fila tiene su prueba:

| Situación | Resultado |
|---|---|
| El origen remoto responde | Se traduce a dominio, se guarda en local y se devuelve `.success` |
| El remoto falla y local tiene datos | Se devuelve `.success` con lo local (respaldo) |
| El remoto falla y local está vacío | Se devuelve `.failure(.network)` |
| El remoto responde con lista vacía | Se devuelve `.success([])` y se limpia lo local |

**Ningún error escapa del repositorio.** Lo que no sea una cancelación se traduce; la cancelación
se repropaga.

---

## 3. Telemetría: `Core` hacia `Data`

```swift
protocol AnalyticsTracker: Sendable {
    func track(_ event: AnalyticsEvent)
    func trackScreenView(_ screenName: String)
}

protocol CrashReporter: Sendable {
    func recordNonFatal(_ error: Error)
    func log(_ message: String)
}
```

- **Las cuatro son operaciones de disparar y olvidar: nunca lanzan ni bloquean a quien las llama.**
  Un fallo de telemetría jamás puede tumbar una pantalla.
- Las implementaciones sobre Firebase viven **exclusivamente** en `Data/Telemetry`.
- Las claves sensibles se descartan **antes** de enviar, y el descarte vive en `AnalyticsEvent`
  (ver `data-model.md` §3).
- Existen implementaciones de no operación, y se usan en dos sitios: en pruebas y cuando falta el
  fichero de configuración (FR-021).
- `CrashReporter` hace eco al registro del sistema **solo en compilaciones de depuración**, y de un
  fallo no mortal escribe **el nombre del tipo del error, nunca su mensaje**: un mensaje puede
  llevar dentro lo que alguien escribió o una ruta con datos.

---

## 4. Cableado de dependencias

```swift
@MainActor
final class AppContainer {
    init(telemetry: TelemetryBundle = .resolved())
    func makeHomeViewModel() -> HomeViewModel
}
```

- **`AppContainer` es el único punto de entrada del grafo.** El punto de entrada de la aplicación
  no conoce ninguna dependencia individual.
- Todo se recibe **por inicializador** y detrás de un protocolo. Un cableado incompleto **no
  compila**.
- `TelemetryBundle.resolved()` es la fábrica que decide entre Firebase y no operación según exista
  o no el fichero de configuración. **Es el único sitio que toma esa decisión**, y está fuera del
  contenedor para que el contenedor no importe Firebase y la regla de arquitectura 5 se cumpla
  sola.
- **Añadir una pieza obliga a cablearla en el contenedor**; si no, no compila.

---

## 5. Presentación

```swift
@MainActor @Observable
final class HomeViewModel {
    init(getContentItems: GetContentItemsUseCase, analytics: AnalyticsTracker)
    private(set) var state: HomeUiState
    func onAppear() async
    func onRetry() async
}

struct HomeView: View            // obtiene su modelo del contenedor
struct HomeContentView: View     // sin estado: recibe estado y emite eventos
```

- `state` es de solo lectura desde fuera y **siempre tiene valor**; el inicial es `.loading`.
- La carga inicial se dispara **una sola vez**, aunque la vista aparezca varias veces.
- `onRetry()` no hace nada si ya hay una carga en curso.
- El evento de pantalla vista se registra **exactamente una vez por instancia**.
- **`HomeContentView` no conoce el modelo de pantalla.** Recibe estado y emite eventos, de modo que
  las pruebas pueden recorrer los cuatro estados sin arrancar el grafo.

---

## 6. Identificadores de accesibilidad

Son un contrato con las pruebas de interfaz. **Cambiarlos es romper un contrato**, y se conservan
literales del proyecto Android para que las dos plataformas se prueben con los mismos nombres.

| Identificador | Elemento |
|---|---|
| `home_loading` | Indicador de carga |
| `home_content` | Lista de elementos |
| `home_empty` | Mensaje de «sin contenido» |
| `home_error` | Mensaje de error |
| `home_retry` | Acción de reintentar |

---

## 7. El aspecto

```swift
enum BocTheme {
    static let colors: BocColors
    static let typography: BocTypography
    static let spacing: BocSpacing
    static let shape: BocShape
    static let elevation: BocElevation
}
```

- **Es el único sitio del proyecto que construye un color.** Lo comprueba la regla de arquitectura
  del aspecto.
- No hay nada que proveer ni que inyectar: son constantes. Una vista previa funciona sin envolver
  nada.
- **No hay variante oscura y no debe haberla.** El mecanismo no está puesto a un valor seguro:
  no existe.
