# Modelo de datos: pantalla de arranque

Cuatro tipos nuevos de dominio, uno de datos y uno de presentación. Ninguno tiene más campos de los
que necesita para que la pantalla decida qué pintar.

```
RemoteConfigValues ──traduce──► AppConfig ─────┐
   (Data/Source/Remote)          (Domain)      │
                                               ├──► StartupStatus ──► SplashUiState
ConnectivityDataSource ──► ConnectivityRepo ───┤        (Domain)         (UI/Splash)
   (Data/Source/Local)         (Domain)        │
                                               │
AppVersion (valor, del composition root) ──────┘
```

---

## `AppVersion` · `Domain/Model`

La versión de la aplicación, en la forma en que la persona la ve en la tienda. Es un valor, no un
servicio: quién la lee del paquete es asunto del composition root (research.md D-206).

| Campo | Tipo | Reglas |
|---|---|---|
| `major` · `minor` · `patch` | `Int` | Cada uno ≥ 0 |

- Conforma `Comparable`, `Equatable` y `Sendable`. El orden es el lexicográfico sobre la terna, que
  es lo que significa «versión anterior a».
- `init?(_ text: String)` acepta «1», «1.0» y «1.0.0», completando con ceros los componentes
  ausentes. **Devuelve `nil`** ante cualquier otra cosa: texto vacío, componentes no numéricos,
  negativos, más de tres componentes. Esa nulidad es la que FR-015 convierte en «no bloquea».
- `static let zero = AppVersion(0, 0, 0)`, que es el valor por defecto de la versión mínima: nunca
  es mayor que ninguna versión instalada real.

---

## `AppConfig` · `Domain/Model`

Los parámetros que condicionan el arranque. Portador de datos sin comportamiento más allá de su
normalización.

| Campo | Tipo | Reglas |
|---|---|---|
| `minSupportedVersion` | `AppVersion` | Versión mínima que el servicio admite para esta plataforma |
| `maintenanceMessage` | `String?` | **Nulo** significa «sin mantenimiento». Una cadena vacía o compuesta solo de espacios se normaliza a nulo al construirlo, para que nadie tenga que comprobar las dos cosas (FR-013) |

```
static let `default` = AppConfig(minSupportedVersion: .zero, maintenanceMessage: nil)
```

Ese valor por defecto es **la única declaración** de «todo permitido» que hay en el proyecto
(research.md D-208). Es lo que se usa cuando el servicio no ha publicado nada, cuando ha publicado
algo ilegible y cuando no hay servicio en absoluto.

---

## `StartupStatus` · `Domain/Model`

La conclusión de la preparación cuando **no** ha habido fallo. Enumerado cerrado, de modo que el
`switch` de la pantalla sea exhaustivo y el compilador avise si mañana aparece un cuarto caso.

| Caso | Significado |
|---|---|
| `ready` | Se puede continuar al contenido principal |
| `updateRequired` | La versión instalada es inferior a la mínima soportada |
| `maintenance(String)` | El servicio ha publicado un mensaje de mantenimiento. Lleva el mensaje, que es lo que se pinta |

Los fallos **no** son casos de este enumerado: viajan como `AppResult.failure(DomainError)`, que ya
existe desde la feature 001. El arranque no necesita un vocabulario de errores propio.

### Precedencia, que es lo que de verdad hay que probar

`PrepareStartupUseCase` la aplica en este orden, y cada línea tiene su prueba:

| # | Situación | Resultado | Por qué manda sobre las siguientes |
|---|---|---|---|
| 1 | La configuración remota no se pudo obtener | `.failure(.network)` si además no hay conexión; `.failure(.unknown)` si la hay | Sin configuración no se sabe **ni** la versión mínima **ni** si hay mantenimiento. Los dos datos siguientes no existen |
| 2 | Versión instalada < mínima soportada | `.success(.updateRequired)` | De nada sirve informar de una incidencia temporal a quien no va a poder usar la aplicación de todos modos |
| 3 | Hay mensaje de mantenimiento | `.success(.maintenance(mensaje))` | — |
| 4 | Cualquier otro caso | `.success(.ready)` | — |

La conectividad **no** decide si se intenta la petición: solo elige, en la línea 1, cuál de los dos
errores se devuelve, y por tanto cuál de los dos mensajes se muestra (research.md D-205).

---

## `RemoteConfigValues` · `Data/Source/Remote`

Lo que el servicio de configuración entrega, con **sus** nombres y **sus** tipos. No cruza a
`Domain`: lo traduce el repositorio.

| Campo | Tipo | Clave publicada |
|---|---|---|
| `minSupportedVersion` | `String` | `min_supported_version_ios` |
| `maintenanceMessage` | `String` | `maintenance_message` |

Los dos son `String` porque es lo que el servicio devuelve para un valor ausente: cadena vacía. La
traducción a `AppConfig` es real, no una copia:

| Valor recibido | `AppConfig` resultante |
|---|---|
| `"1.2.0"` | `minSupportedVersion = 1.2.0` |
| `""` · `"  "` · `"latest"` · `"1.2.x"` | `minSupportedVersion = .zero` — ilegible no bloquea (FR-015) |
| `maintenanceMessage = ""` o solo espacios | `nil` — sin mantenimiento |

`min_supported_version_code`, el parámetro de la otra plataforma, **no se lee aquí**. Existe en la
misma consola y sigue siendo suyo.

---

## `SplashUiState` · `UI/Splash`

Los cuatro estados de FR-009, mutuamente excluyentes por construcción.

| Caso | Contenido | Acciones que ofrece |
|---|---|---|
| `preparing` | — | Ninguna |
| `ready` | — | Ninguna: la raíz conmuta al contenido principal |
| `error(DomainError)` | El error, que elige el mensaje | Reintentar · Continuar sin conexión |
| `blocked(BlockReason)` | El motivo | **Solo** reintentar |

```
enum BlockReason: Equatable { case updateRequired, maintenance(String) }
```

**Por qué `blocked` es un caso y no una bandera dentro de `error`** (research.md, y Android D-007
por el mismo motivo): un error recuperable ofrece «continuar sin conexión» y un acceso bloqueado
**no puede** ofrecerlo, porque saltarse el bloqueo anula su propósito. Con una bandera
`canContinue`, la diferencia viviría en un condicional dentro de la vista, que es donde estas cosas
se olvidan; y existiría la combinación incoherente «bloqueado pero con salida», que es exactamente
el fallo que hay que impedir. Como casos distintos, el compilador obliga a tratarlos por separado.

### Transiciones

```
  [inicial]  ──prepare()──►  preparing ──┬── ready ─────────────────► ready ──► contenido principal
                                 ▲       │
                                 │       ├── updateRequired ────────► blocked ──onRetry()──┐
                                 │       │   maintenance                                   │
                                 │       │                                                 │
                                 │       └── failure ─────────────► error ──onRetry()──────┤
                                 │                                    │                    │
                                 └────────────────────────────────────┴────────────────────┘
                                                                      │
                                                    onContinueOffline()└──► contenido principal
```

Reglas del estado:

- El estado inicial es `preparing` y la preparación se dispara una sola vez, al aparecer la portada.
- `onRetry()` **se ignora** si ya hay una preparación en curso (FR-011). No es que no haga nada
  visible: es que no lanza una segunda.
- `onContinueOffline()` solo tiene efecto desde `error`. Desde `blocked` se ignora (FR-012, FR-013).
- `ready` no se alcanza antes de los 1.200 ms desde que empezó la preparación, aunque el trabajo
  termine antes (FR-005). El mínimo se solapa con el trabajo, no se le suma.
- Superados los 8 s, la preparación se abandona y el estado pasa a `error` (FR-006).
- El estado vive en el modelo de pantalla, que posee la raíz. Por eso sobrevive a un ciclo de
  segundo plano sin reiniciarse ni duplicarse (FR-008).

---

## `StartupScenario` · `Core/Util`

La costura de las pruebas de interfaz (research.md D-212). Enumerado con valor de cadena, leído del
argumento de lanzamiento `-boc-startup-scenario=`.

| Caso | Qué fuerza |
|---|---|
| `ready` | Preparación correcta (es el valor por defecto, y el de producción) |
| `offline` | Sin conexión: error recuperable con sus dos salidas |
| `updateRequired` | Versión por debajo de la mínima |
| `maintenance` | Mensaje de mantenimiento publicado |
| `slow` | Preparación que no responde, para ver el estado de carga y el límite de espera |

Un valor desconocido o ausente cae en `ready`, igual que el escenario de contenido que ya existe.

---

## Tokens de diseño que esta feature consume

Todos existen ya salvo los tres del último grupo, que se añaden (research.md D-214).

| Elemento de la portada | Token |
|---|---|
| Fondo | `BocTheme.colors.primary` — `#063B5C` |
| `BOC` | `BocTheme.typography.displayLarge`, sobre `colors.onPrimary` |
| Denominación en dos líneas | `BocTheme.typography.splash.subtitle` — **nuevo** |
| Línea divisoria | `BocTheme.colors.onPrimaryAccent` — `#8FD3EE`, 120 × 2 pt |
| Etiqueta de autoría | `BocTheme.typography.splash.authorshipLabel` — **nuevo**, sobre `colors.onPrimaryMuted` (blanco al 70 %) |
| Nombre del autor | `BocTheme.typography.splash.authorshipName` — **nuevo**, sobre `colors.onPrimaryAccent` |
| Indicador de progreso | `BocTheme.colors.onPrimaryAccent` |
| Separaciones | `BocTheme.spacing.lg` (24) y las demás de la escala |
