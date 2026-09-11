# Contratos internos

La aplicación no expone interfaces externas. Los contratos que importan son los límites entre capas
—los que las reglas de arquitectura protegen—, más el contrato visual de la portada y el del
lanzamiento del sistema, que es lo que hace verificables SC-009 y FR-002.

---

## 1. `Domain` hacia el resto del mundo

```swift
// Domain/Repository/AppConfigRepository.swift
protocol AppConfigRepository: Sendable {
    /// Nunca lanza: los fallos llegan como `AppResult.failure`.
    func loadConfig() async -> AppResult<AppConfig>
}

// Domain/Repository/ConnectivityRepository.swift
protocol ConnectivityRepository: Sendable {
    /// Si el dispositivo tiene un camino de red utilizable. **No** garantiza salida a internet:
    /// ver la nota de abajo antes de apoyarse en esto.
    func isOnline() async -> Bool
}

// Domain/UseCase/PrepareStartupUseCase.swift
struct PrepareStartupUseCase: Sendable {
    init(
        appConfig: AppConfigRepository,
        connectivity: ConnectivityRepository,
        installedVersion: AppVersion
    )
    func callAsFunction() async -> AppResult<StartupStatus>
}
```

**Contrato del caso de uso:**

- **Nunca lanza.** Todo fallo sale como `AppResult.failure(DomainError)`.
- Aplica la precedencia de `data-model.md`, y esa tabla es su especificación: cada fila tiene
  prueba.
- Es **idempotente**: llamarlo dos veces da el mismo resultado para las mismas entradas. No guarda
  estado.
- **No impone el tiempo mínimo en pantalla.** Eso es presentación y vive en el modelo de pantalla.
- Repropaga la cancelación. Si la tarea que lo envuelve se cancela, no publica nada.

> **Lo que `ConnectivityRepository` NO promete, y hay que leer antes de usarlo.** Dice si hay un
> camino de red, no si hay internet: un portal cautivo de hotel responde que sí. Por eso la
> comprobación que manda es que la configuración remota se obtenga, y este repositorio solo elige
> **cuál de los dos mensajes de error** se muestra. Si alguna vez alguien lo usa para decidir si
> merece la pena intentar una petición, estará escribiendo un fallo que solo aparece en hoteles y
> aeropuertos. Ver research.md D-205.

---

## 2. `Data` hacia `Domain`

```swift
// Data/Source/Remote/RemoteConfigDataSource.swift
protocol RemoteConfigDataSource: Sendable {
    /// **Puede lanzar.** El repositorio es quien captura y traduce.
    func fetchValues() async throws -> RemoteConfigValues
}

// Data/Source/Remote/FirebaseRemoteConfigDataSource.swift  — ÚNICO sitio que toca el SDK
// Data/Source/Remote/UnavailableRemoteConfigDataSource.swift — devuelve valores vacíos, no lanza

// Data/Source/Local/ConnectivityDataSource.swift
protocol ConnectivityDataSource: Sendable {
    func isOnline() async -> Bool
}
// Data/Source/Local/PathMonitorConnectivityDataSource.swift — actor sobre el monitor del sistema
```

### Política de `AppConfigRepositoryImpl`

| Situación | Resultado |
|---|---|
| El servicio responde | Se traduce a `AppConfig` y se devuelve `.success` |
| El servicio lanza **y** no hay camino de red | `.failure(.network)` |
| El servicio lanza **y** sí hay camino de red | `.failure(.unknown)` |
| El servicio responde sin valores publicados | `.success(AppConfig.default)` |
| La versión mínima llega vacía o ilegible | `.success` con `minSupportedVersion = .zero` |
| El mensaje de mantenimiento llega vacío o en blanco | `.success` con `maintenanceMessage = nil` |
| No hay fichero de configuración del proveedor en el puesto | `.success(AppConfig.default)` |
| La tarea se cancela | El resultado **no se publica**: lo comprueba el modelo de pantalla con `Task.isCancelled` antes de escribir el estado, que es la política que fijó la feature 001 (D-108) |

**Ningún error escapa de `Data`** y **todo camino de fallo deja constancia** por `CrashReporter.log`
con la fase y el motivo exacto (FR-018). Nunca la clave del proveedor ni el contenido de la
configuración.

---

## 3. Presentación

```swift
// UI/Splash/SplashViewModel.swift
@MainActor
@Observable
final class SplashViewModel {
    static let screenName = "splash"

    private(set) var state: SplashUiState

    init(
        prepareStartup: PrepareStartupUseCase,
        analytics: AnalyticsTracker,
        crashReporter: CrashReporter,
        clock: AppClock,
        minimumDisplaySeconds: Double = 1.2,
        timeoutSeconds: Double = 8.0
    )

    func onAppear() async
    func onRetry() async
    func onContinueOffline()
}

// UI/Splash/SplashView.swift        — recibe el modelo por inicializador, lo envuelve en @State
// UI/Splash/SplashContentView.swift — tonta: `state` + tres closures. Es la que se previsualiza
```

**Contrato del modelo de pantalla:**

- `state` es de solo lectura desde fuera y **siempre tiene valor**. El inicial es `preparing`.
- **`onAppear()` no retorna hasta haber publicado el estado final.** No es un detalle de estilo: es
  lo que permite que una prueba haga `await viewModel.onAppear()` y afirme sobre el estado en la
  línea siguiente. Prohibido disparar el arranque en una `Task` sin dueño.
- `onAppear()` prepara **una sola vez** por instancia, aunque la vista vuelva a aparecer.
- `ready` no se publica antes de `minimumDisplaySeconds`, y la espera mínima corre **en paralelo**
  con el trabajo, no antes ni después.
- Pasados `timeoutSeconds` la preparación se abandona y el estado pasa a `error`.
- `onRetry()` **no hace nada** si ya hay una preparación en curso.
- `onContinueOffline()` solo tiene efecto desde `error`. Desde `blocked` se ignora.
- El evento de pantalla vista se registra **exactamente una vez por instancia**, en el
  inicializador, igual que en `HomeViewModel`.
- Los fallos de preparación se reportan al servicio de errores. **Sin datos personales**: ni
  mensajes del servicio, ni la credencial, ni el mensaje de mantenimiento.

**Contrato de la raíz** (`UI/Navigation/RootView.swift`):

- Posee el modelo de pantalla del arranque. Por eso el estado sobrevive al ciclo de segundo plano.
- Mientras el estado no sea `ready`, muestra la portada. Cuando lo es, muestra el `NavigationStack`.
- **La portada nunca entra en la pila de navegación**, así que ningún gesto de retroceso puede
  devolver a ella (FR-007). `Route` no cambia.

---

## 4. Cableado de dependencias

`AppContainer` gana una fábrica y los parámetros nuevos **con valor por defecto**, para que las
llamadas existentes de `AppContainerTests` sigan compilando:

```swift
init(
    telemetry: TelemetryBundle,
    clock: AppClock = SystemClock(),
    contentScenario: StubContentRemoteDataSource.Scenario = .items,
    startupScenario: StartupScenario = .ready,
    installedVersion: AppVersion = AppInfo.installedVersion
)

func makeSplashViewModel() -> SplashViewModel
```

- La fuente de configuración remota se resuelve **en el mismo punto** en que se resuelve la
  telemetría, porque las dos dependen de que la aplicación del proveedor esté configurada y
  configurarla dos veces es un error.
- `AppContainer` sigue **sin importar ningún SDK**. La decisión de proveedor sigue viviendo en
  `Data`.
- Quien lee el paquete es `AppInfo`, en `Core/Util`, **no** `AppVersion`. El modelo de dominio no
  puede saber que existe un paquete: es Swift puro y así se prueba (research.md D-206).
- El escenario de arranque sustituye las dependencias del arranque en **un** punto, no en varios.

---

## 5. Identificadores de accesibilidad

Identificadores estables sobre los que se afirman las pruebas de interfaz. Cambiarlos rompe un
contrato.

| Identificador | Qué marca |
|---|---|
| `splash_root` | El contenedor de la portada |
| `splash_emblem` | El escudo |
| `splash_loading` | El indicador de progreso |
| `splash_error` | El mensaje de error recuperable |
| `splash_blocked` | El mensaje de acceso bloqueado |
| `splash_retry` | El botón de reintentar |
| `splash_continue_offline` | El botón de continuar sin conexión |

**Los botones llevan identificador propio, y no se buscan por su texto.** En la feature 001 el
contrato declaró `home_retry` y no llegó a implementarse, así que sus pruebas de interfaz localizan
el botón por la cadena «Reintentar». Aquí hay dos botones y uno de ellos comparte texto con el de
`Inicio`: buscar por texto sería exactamente la trampa que `CLAUDE.md` documenta.

Se consultan **sin fijar el tipo**, con
`app.descendants(matching: .any).matching(identifier:).firstMatch`, por la razón que la feature 001
ya dejó escrita: un contenedor de SwiftUI no aparece como `otherElements`.

---

## 6. Contrato visual de la portada

Transcrito del apartado 13 de `docs/diseno/especificaciones-diseno.md` y de
`docs/diseno/pantalla-arranque-referencia.png`. Es lo que hace verificable SC-009.

| Elemento | Especificación |
|---|---|
| Fondo | `#063B5C` a pantalla completa, de borde a borde |
| Barra de estado | **Oculta**, desde el lanzamiento hasta el contenido principal (FR-022 enmendado) |
| Escudo | Recurso oficial, **104 pt** de alto, proporciones intactas, centrado horizontalmente y por encima del centro óptico |
| Separación escudo → siglas | 24 pt |
| `BOC` | `displayLarge` (56/64), blanco |
| `BOLETÍN OFICIAL` / `DE CANTABRIA` | Dos líneas, 20 pt, peso medio, espaciado entre letras amplio, blanco |
| Línea divisoria | 120 × 2 pt, `#8FD3EE`, centrada |
| Etiqueta de autoría | «Diseñada y desarrollada por», 13 pt, blanco al 70 % |
| Nombre | «José Ramón Blanco Gutiérrez», 15 pt, semibold, `#8FD3EE` |
| Indicador de progreso | Bajo la autoría, discreto, `#8FD3EE` |
| Anclaje inferior | Autoría e indicador son **un bloque** anclado abajo, respetando el área segura |

Ambigüedad documental resuelta, igual que la resolvió Android: el documento sitúa la autoría a 72 dp
del borde inferior pero no dice dónde va el indicador; la imagen de referencia lo pone debajo del
nombre. Se sigue la imagen y se trata el conjunto como un bloque, que es la lectura que satisface
las dos fuentes.

El texto de autoría es **el de esta especificación**, no el de la imagen de referencia, que está
desactualizada y dice «Aplicación creada por José Ramón Blanco».

---

## 7. Contrato del lanzamiento del sistema

Vive en `Config/Info.plist` y en los ajustes del proyecto. Tiene prueba: se lee el `Info.plist`
compilado y se comprueban las tres claves.

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>   <string>AccentColor</string>
    <key>UIImageName</key>   <string>ic_launch_emblem</string>
</dict>
<key>UIStatusBarHidden</key> <true/>
```

Y `INFOPLIST_KEY_UILaunchScreen_Generation = NO`, porque la generación automática produce un
lanzamiento en blanco que es justo el destello que FR-002 prohíbe.

**El escudo del lanzamiento y el de la portada deben verse en el mismo sitio y al mismo tamaño.**
El sistema centra la imagen a su tamaño natural, así que el recurso lleva el desplazamiento dentro
del lienzo (research.md D-203). Es una coincidencia geométrica que no la comprueba ningún
compilador: se verifica grabando el arranque, y ese paso está en el `quickstart.md`.

---

## 8. Lo que esta feature NO cambia

Conviene dejarlo escrito, porque son las cosas que una pantalla nueva invita a tocar:

- `Route` y la forma del `NavigationStack`. La portada no es un destino.
- Las nueve reglas de arquitectura. Ninguna se relaja; la 8 en particular queda intacta
  (research.md D-213).
- El escenario de contenido de `LaunchConfiguration`, que sigue siendo material desechable de la
  feature 001 y desaparecerá con la 003.
- `AnalyticsEvent` y la política de datos personales. Esta feature añade eventos, no mecanismo.
