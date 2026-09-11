# Modelo de datos: esqueleto de arquitectura

## 1. La cadena de traducción

```
ContentItemDTO  ──map──▶  ContentItem  ◀──map──  ContentItemRecord
  (Data/Remote)            (Domain)               (Data/Local)
                               │
                               ▼
                    HomeUiState.content([ContentItem])
                               (UI)
```

**Ni el DTO ni el registro cruzan a `UI`.** Es la regla de dependencias escrita como dato, y la
comprueba la regla de arquitectura 2.

### `ContentItemDTO` — lo que devuelve el origen remoto

| Campo | Tipo | Nota |
|---|---|---|
| `id` | `String` | |
| `label` | `String` | **Se llama `label` y no `title` a propósito.** Los nombres son deliberadamente distintos de los del dominio para que la traducción sea real y no una copia de campos. Heredado del Android |

### `ContentItemRecord` — lo que guarda el origen local

| Campo | Tipo |
|---|---|
| `id` | `String` |
| `title` | `String` |

### `ContentItem` — el modelo de dominio

| Campo | Tipo | Regla |
|---|---|---|
| `id` | `String` | No vacío y **estable entre cargas**: identifica al elemento, no a su posición |
| `title` | `String` | No vacío, visible |

Deliberadamente trivial. Existe para demostrar el recorrido entre capas y lo sustituye la feature
del boletín.

### `AppResult` y `DomainError`

```swift
typealias AppResult<T> = Result<T, DomainError>

enum DomainError: Error, Equatable {
    case network   // No se pudo traer y no había copia local usable
    case unknown   // Cualquier fallo inesperado, traducido en Data
}
```

Dos invariantes que no se negocian:

- **Una colección vacía es `.success([])`, no un fallo.** «Vacío» y «error» se distinguen en la
  capa de presentación, no en el dominio.
- **Los errores no salen de `Data`**: se capturan allí y se traducen a `DomainError`. La
  cancelación se repropaga siempre.

---

## 2. Estado de la pantalla inicial

```swift
enum HomeUiState: Equatable {
    case loading
    case content([ContentItem])
    case empty
    case error(DomainError)
}
```

### Transiciones

```
        ┌──────────────── onRetry() ────────────────┐
        │                                           │
   [inicial] ──load()──▶ loading ──éxito, n>0──▶ content
                            ├──éxito, n==0──▶ empty
                            └──fallo────────▶ error ──┘
```

Tres reglas, portadas literales del Android:

1. **El estado inicial al construirse el modelo de pantalla es `loading`**, y la carga se dispara
   sola.
2. **`onRetry()` solo tiene efecto desde `error` o `empty`.** Desde `loading` se ignora, de modo
   que pulsar repetidamente no lanza cargas simultáneas.
3. **El estado vive en el modelo de pantalla**, así que sobrevive a un ciclo de segundo plano y
   vuelta sin recargar (FR-005).

Y una cuarta, propia de la telemetría: **el evento de pantalla vista se registra exactamente una
vez por instancia del modelo de pantalla**, no una vez por aparición de la vista.

---

## 3. Evento de uso

```swift
struct AnalyticsEvent: Equatable {
    let name: String                      // ^[a-z][a-z0-9_]{0,39}$
    let parameters: [String: String]      // vacío por defecto
    func sanitizedParameters() -> [String: String]
}
```

- El nombre se valida contra el patrón al construirlo. Un nombre inválido es un error de
  programación y se trata como tal.
- `sanitizedParameters()` descarta las claves sensibles por **coincidencia exacta en minúsculas**
  —no por subcadena, no por el valor—:

  `address`, `dni`, `email`, `ip`, `latitude`, `longitude`, `name`, `nie`, `nif`, `password`,
  `phone`, `surname`, `token`, `user_id`, `username`

- **El filtro vive en el modelo, no en la implementación del proveedor.** Es lo que permite
  probarlo sin tocar ningún SDK, y lo que hace que cambiar de proveedor no pueda perderlo por el
  camino.
- Constante compartida: `parameterScreenName = "screen_name"`.

---

## 4. Los valores del aspecto

Transcripción de `docs/diseno/especificaciones-diseno.md`. **Son datos, no decisiones**: si algo
aquí no coincide con el documento, manda el documento.

### 4.1 Color — 26 tokens

Los nombres describen el **papel**, nunca la apariencia: `primary`, jamás `blue`. Un token
sobrevive a un cambio de tono; un nombre de color se convierte en mentira la primera vez que se
revisa la paleta.

| Token | Valor | | Token | Valor |
|---|---|---|---|---|
| `primary` | `#063B5C` | | `surfaceStrong` | `#E6EDF1` |
| `onPrimary` | `#FFFFFF` | | `readerSurface` | `#D9DEE2` |
| `primaryPressed` | `#042C45` | | `textPrimary` | `#122B3A` |
| `primaryContainer` | `#DCEEF6` | | `textSecondary` | `#536873` |
| `onPrimaryContainer` | `#082F45` | | `textMuted` | `#778993` |
| `secondary` | `#087EA4` | | `outline` | `#B8C4CB` |
| `secondaryPressed` | `#056686` | | `divider` | `#D9E0E4` |
| `secondaryContainer` | `#DDF3FA` | | `success` | `#2E7D32` |
| `accentOfficial` | `#C62828` | | `warning` | `#ED6C02` |
| `aiAccent` | `#6650A4` | | `error` | `#BA1A1A` |
| `aiContainer` | `#F1EDFA` | | `onPrimaryAccent` | `#8FD3EE` |
| `background` | `#F6F8FA` | | `onPrimaryMuted` | blanco al **70 %** |
| `surface` | `#FFFFFF` | | | |

Notas que importan al transcribir:

- **`onPrimary` y `surface` valen los dos `#FFFFFF`, y `success` vale lo mismo que el color de la
  sección de economía.** Son tokens distintos con el mismo valor: no los colapses.
- `onPrimaryMuted` es blanco con alfa `0xB3` = 179/255 = 70,2 %.
- **Fuera quedan los cinco colores de sección** (D-111), que llegan con las secciones del boletín.
- `AccentColor` del catálogo de recursos vale `#063B5C`, el mismo que `primary`, y **debe
  mantenerse sincronizado**: lo consume el sistema antes de que exista `BocTheme`.

### 4.2 Tipografía — 14 estilos

Familia: **la del sistema**. Una sola; el carácter editorial sale de la escala, el peso y el
espaciado, no de mezclar fuentes.

| Estilo | Tamaño | Interlineado | Peso | Uso |
|---|---:|---:|---|---|
| `displayLarge` | 56 | 64 | regular | Siglas BOC en portada |
| `displaySmall` | 40 | 48 | regular | Título editorial excepcional |
| `headlineLarge` | 30 | 38 | semibold | Título de publicación |
| `headlineMedium` | 26 | 34 | semibold | Título principal de pantalla |
| `headlineSmall` | 22 | 28 | semibold | Título de bloque |
| `titleLarge` | 20 | 26 | semibold | Título de tarjeta destacada |
| `titleMedium` | 17 | 23 | semibold | Título de publicación en listado |
| `titleSmall` | 15 | 20 | semibold | Organismos y cabeceras pequeñas |
| `bodyLarge` | 16 | 24 | regular | Texto principal de lectura |
| `bodyMedium` | 14 | 21 | regular | Descripciones y resúmenes |
| `bodySmall` | 12 | 18 | regular | Información auxiliar |
| `labelLarge` | 14 | 20 | semibold | Botones y pestañas |
| `labelMedium` | 12 | 17 | semibold | Chips y categorías |
| `labelSmall` | 11 | 15 | semibold | Metadatos muy breves |

- **Los pesos 650 del documento se implementan como `semibold` (600)**, el peso real más cercano.
  Pedir 650 da o el 600 real o un engrosamiento sintético de peor calidad según el dispositivo.
- **Espaciado entre letras: cero en los catorce.** Hay que ponerlo a mano, porque la fuente del
  sistema trae el suyo. Si no se hace, la tipografía se parece pero no es la misma.
- **El interlineado del documento es absoluto y el de SwiftUI es aditivo.** `.lineSpacing()` añade
  espacio **entre** líneas, no fija la altura de la línea: el valor que hay que aplicar es el
  interlineado de la tabla menos la altura natural de la fuente a ese tamaño. Transcribir la cifra
  de la tabla directamente a `.lineSpacing()` deja los párrafos muy abiertos.

### 4.3 Espaciado — unidad base 4

| Token | Valor | | Token | Valor |
|---|---:|---|---|---:|
| `xxs` | 4 | | `lg` | 24 |
| `xs` | 8 | | `xl` | 32 |
| `sm` | 12 | | `xxl` | 40 |
| `md` | 16 | | `xxxl` | 48 |
| `ml` | 20 | | `screenMargin` | = `md` = 16 |

Todos los valores son múltiplos de 4. `screenMargin` es el margen de pantalla de teléfono; el
documento define además 20 para teléfono grande y 32 para tableta, que **no se implementan**
porque la aplicación es solo iPhone.

### 4.4 Formas

| Token | Radio | | Token | Radio |
|---|---:|---|---|---:|
| `extraSmall` | 8 | | `bottomSheet` | 28 **solo arriba** |
| `small` | 12 | | `dialog` | 24 |
| `medium` | 14 | | `banner` | 12 |
| `large` | 18 | | `chip` | completo (cápsula) |
| `extraLarge` | 28 | | | |

### 4.5 Elevación

| Token | Valor | Uso |
|---|---:|---|
| `level0` | 0 | Fondos y tarjetas delimitadas por borde |
| `level1` | 1 | Tarjetas estándar |
| `level2` | 3 | Barra inferior y elementos flotantes |
| `level3` | 6 | Hojas inferiores y menús |
| `level4` | 8 | Diálogos |

Sombras suaves, amplias y de baja opacidad. Se prefiere separar superficies por contraste de fondo
antes que apilar sombras; por eso los niveles se quedan deliberadamente bajos.
