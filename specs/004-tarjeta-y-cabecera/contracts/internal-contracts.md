# Contratos internos: la tarjeta con jerarquía y la cabecera fija

La aplicación no expone interfaces externas. Los contratos que importan son **los límites entre
capas**, y esta feature toca uno solo: el que va de `UI/Home` a `Core/UI/Component`. **Los otros no
se tocan y se dicen abajo, en el apartado 6**, porque en una feature de composición lo que no cambia
es tan informativo como lo que cambia.

Los bloques de código son **firmas, no implementaciones**.

---

## 1 · Lo que NO cambia, y va primero por ser lo más importante

```swift
// Domain: una propiedad calculada nueva, y nada más (ver el apartado 2).
// Data:   intacto. Ni una consulta, ni un registro, ni una migración.

@MainActor @Observable
final class HomeViewModel {
    private(set) var state: HomeUiState            // sin un campo nuevo
    func apply(_ selection: HomeSelection) async
    func onRefresh() async
    func onRetry() async
}

struct HomeUiState: Equatable {                    // sin un campo nuevo
    var selection: HomeSelection
    var header: BulletinHeader?
    var sectionChips: [SectionChip]
    var subsectionChips: [SectionChip]
    var content: HomeContent
    var isRefreshing: Bool
    var isOffline: Bool
}
```

> **`HomeUiState` no gana `isHeaderCompact`, y es una decisión, no un olvido** (research.md D-409).
> Que la cabecera esté encogida describe dónde está el dedo, no qué se está mostrando. Vive como
> `@State` de `HomeContentView`, igual que el abierto/cerrado del panel vive en `MainView`.

---

## 2 · La tarjeta

```swift
struct PublicationCard: View {
    let publication: Publication
    var onShare: (() -> Void)?
    var onSave: (() -> Void)?
}

extension PublicationCard {
    /// Los cuatro peldaños de la tarjeta, en un sitio, para poder afirmarlos (FR-018).
    enum Typography {
        static var section: BocTextStyle { get }        // titleSmall   · 15 semibold
        static var organisation: BocTextStyle { get }   // bodyLarge    · 16 regular
        static var title: BocTextStyle { get }          // titleLarge   · 20 semibold
        static var date: BocTextStyle { get }           // bodyMedium   · 14 regular
        /// En orden de peso creciente: sección, organismo, título.
        static var hierarchy: [BocTextStyle] { get }
        static var all: [BocTextStyle] { get }
    }
}
```

**La firma pública de la tarjeta no cambia**: sigue recibiendo la publicación y dos cierres, y sigue
derivando la sección y el color por dentro. Lo que cambia es lo de dentro.

Y `Domain` gana una lectura derivada, que es lo único que esta feature añade fuera de `UI`:

```swift
extension Publication {
    /// El título **sin el organismo que la línea de encima ya dice** (FR-021).
    ///
    /// Recorte **exacto y sin distinguir mayúsculas** sobre el texto anterior a los primeros dos
    /// puntos. Un prefijo que solo se parezca se conserva entero: «FRATERNIDAD MUPRESPA MATEPSS
    /// Nº 275» no es «Fraternidad Muprespa». Es presentación: lo almacenado no cambia, y
    /// compartir y buscar siguen viendo el título íntegro (research.md D-416).
    var titleWithoutIssuer: String { get }
}
```

> **Por qué en `Domain` y no en la vista**: se prueba en cuatro milésimas en vez de en un simulador,
> la pantalla de detalle de la 005 la va a necesitar igual, y es del mismo género que
> `mostSpecificSectionCode`, que vive tres líneas más arriba en el mismo fichero.

**Lo que la tarjeta promete**, y cada línea tiene quien la rompa en rojo:

| Promesa | Qué la rompe | Quién lo caza |
|---|---|---|
| Los cuatro peldaños son **distintos dos a dos** | Igualar dos tokens | `PublicationCardTypographyTests` |
| Van en orden de peso: `section < organisation < title` | Invertir dos | `PublicationCardTypographyTests` |
| Los cuatro salen de `BocTheme.typography.all` | Escribir un tamaño a mano (FR-008) | `PublicationCardTypographyTests` |
| La fecha no baja de 12 puntos (§6.3) | Bajarla | `PublicationCardTypographyTests` |
| El organismo se pinta **en mayúsculas** y se **oye en su caja original** | `issuer.uppercased()` en la vista | La prueba de interfaz, y VoiceOver a mano (quickstart, paso 8) |
| El organismo se pinta **una sola vez**, y el título no lo repite (FR-021) | Pintar `publication.title` en vez de `titleWithoutIssuer` | `testTheIssuerIsNotPaintedTwice`, que **falla con «(2) is not equal to (1)»** si se revierte |
| La fecha y las acciones comparten fila **y se apilan cuando no caben** | Un `Spacer()` sin `minLength` en el primer candidato de `ViewThatFits` (D-404) | `testTheDateSharesItsRowWithTheActionsAndStacksWhenItDoesNotFit`, por solapamiento vertical |
| El organismo ausente **no deja hueco** | Pintar una cadena vacía en vez de omitir la vista | La vista previa «Sin organismo» |
| El orden vertical es sección → organismo → título → (fecha · acciones) | Reordenar | Revisión y el quickstart |

> **Aquí decía que ninguna prueba automática puede ver qué candidato elige el `ViewThatFits`, y era
> falso.** Sí puede, y con un margen amplio: compartiendo fila, el texto de la fecha y el botón de
> compartir **se solapan verticalmente** (al 100 %, 451,2–466,2 contra 434,7–482,7); apilados, el
> botón queda estrictamente debajo (al 200 %, 930–975 contra 979–1027). Para eso la fecha gana el
> identificador `publication_date`. Lo que sigue sin poder verse desde una prueba es si el resultado
> **se lee bien**, y para eso está el paso 8 del quickstart.

---

## 3 · La cabecera editorial

```swift
struct BulletinHeaderView: View {
    let header: BulletinHeader
    /// Encogida: sin fecha rotulada, con menos relleno y con el rótulo a una línea.
    /// **El valor por defecto es `false`**, para que las vistas previas y las llamadas de la 003
    /// no cambien.
    var isCompact: Bool = false
}
```

**Contrato de la versión compacta** (FR-011):

| Elemento | Expandida | Compacta |
|---|---|---|
| Denominación | `headlineLarge`, hasta 2 líneas | **Igual**, 1 línea |
| Fecha rotulada · `home_header_date` | Presente si hay fecha | **Ausente** |
| Distintivo del recuento · `home_header_count` | Presente | **Igual** |
| Relleno vertical | `spacing.lg` · 24 | `spacing.sm` · 12 |
| Fondo | `colors.primary` | **Igual** |

> **La denominación no cambia de peldaño, y es deliberado** (D-410). SwiftUI no interpola tamaños de
> fuente: los resuelve con un fundido. FR-012 pide una transición gradual sin saltos, y ocultar una
> línea y reducir un relleno sí anima limpiamente porque las dos cosas son alturas.

La animación se declara **en la cabecera**, no en quien cambia el valor:
`.animation(.easeInOut(duration: 0.2), value: isCompact)` (D-411).

---

## 4 · El contenido de Inicio

```swift
struct HomeContentView: View {
    let state: HomeUiState
    var onRefresh: () async -> Void
    var onRetry: () -> Void
    var onSelect: (SectionChip) -> Void
    var onOpenSections: () -> Void
    var onSearch: () -> Void
    var onInfo: () -> Void
    var onShare: (Publication) -> Void
    var onSave: (Publication) -> Void

    /// Efímero. No sale de aquí y nadie más lo consulta (D-409).
    @State private var isHeaderCompact: Bool
}
```

**La firma pública no cambia**: los mismos nueve parámetros de la 003. `HomeView` no se toca.

**Contrato de la composición**, que es lo nuevo:

| Zona | Qué lleva | Se desplaza |
|---|---|---|
| Fija | Barra superior · cabecera editorial · fila de secciones · [fila de subsecciones] · [aviso sin conexión] | **No** |
| Desplazable | El listado, en cualquiera de sus cuatro estados | **Sí, y es lo único** |

- La zona fija lleva **fondo `colors.surface` sólido** y un **divisor de un punto con
  `colors.divider`** en su borde inferior (FR-013, §14.6). No un `Divider()`: ése pinta el color del
  sistema (D-406).
- El `refreshable` va **en el `ScrollView` del listado** (FR-015), acompañado de
  `.scrollBounceBehavior(.always, axes: .vertical)`, **sin lo cual el gesto desaparece en los estados
  vacío y de error** (D-407).
- El umbral se observa con `.onScrollGeometryChange(for: Bool.self)`, que publica **el resultado de
  la comparación y no el desplazamiento**, con dos umbrales —compacta por encima de 24 puntos,
  expande por debajo de 8— para que la banda no dé un salto con un listado apenas desplazable
  (D-408).

---

## 5 · Identificadores de accesibilidad

Son **contrato**, no decoración. **Ninguno se renombra, ninguno se añade y ninguno desaparece de la
pantalla**; lo que cambia es **dónde cuelgan**, y eso basta para romper una prueba.

| Identificador | Antes colgaba de | Ahora cuelga de | Qué tiene que seguir siendo cierto |
|---|---|---|---|
| `home_root` | La pantalla | **Igual** | Existe en los cuatro estados |
| `home_header` | El `ScrollView` único | El `VStack` fijo | **Existe también después de desplazar** — es la mitad de FR-009 |
| `home_header_date` | La cabecera | **Igual** | Presente arriba del todo; **ausente** con el listado desplazado |
| `home_header_count` | La cabecera | **Igual** | Presente en los dos estados de la cabecera |
| `home_section_chips` | El `ScrollView` único | El `VStack` fijo | Alcanzable sin volver arriba (SC-003) |
| `home_subsection_chips` | El `ScrollView` único | El `VStack` fijo | Sigue **sin existir** cuando no procede (FR-017) |
| `chip_<code>` · `chip_today` | La fila | **Igual** | Siguen encontrándose uno a uno |
| `home_offline_banner` | El `ScrollView` único | El `VStack` fijo | Visible **mientras** se desplaza (FR-014) |
| `home_content` | El `ScrollView` único | El `ScrollView` del listado | **Quince funciones de prueba en seis ficheros lo usan como puerta de entrada** |
| `home_skeleton` · `home_empty` · `home_error` · `home_retry` | El `ScrollView` único | El `ScrollView` del listado | Igual, y con el gesto de actualizar todavía disponible |
| `publication_card_<n>` | El listado | **Igual** | |
| `publication_date` | — | La fila compartida | **El único identificador nuevo de la feature.** Va en el `Text` y no en su fila: sobre el contenedor se propagaría al icono del calendario. Es lo que permite comprobar el apilado |
| `publication_share` · `publication_save` | La tarjeta | La fila compartida con la fecha | Conservan su área táctil de 48 puntos a cualquier talla |
| `home_menu` · `home_search` · `home_info` | La barra superior | **Igual** | |

> **Comprobado, no supuesto.** Volcados el árbol antes y después con el mismo escenario, el
> conjunto de identificadores difiere en **uno solo**: `publication_date`. `home_root`, `home_menu`,
> `home_search` y `home_info` conservan su nombre —no ha habido propagación—, `home_header` conserva
> su marco `{{0, 126}, {402, 107}}` con sus dos hijos distintos, los `chip_*` se siguen encontrando
> uno a uno, y `home_content` arranca en el mismo `y = 299`.

**Las tres caras de la trampa del árbol**, que esta feature vuelve a poner en juego porque mueve
cuatro contenedores de sitio:

1. Un identificador puesto sobre un contenedor **se propaga a sus descendientes** si el contenedor
   no se declara antes `.accessibilityElement(children: .contain)`.
2. Un contenedor cuyos hijos están todos ocultos **no entra en el árbol**.
3. **No se anidan dos contenedores declarados**: el de dentro desaparece.

Por eso el paso 6 del quickstart **vuelca el árbol con `app.debugDescription` y lo compara**, en vez
de fiarse de que las pruebas pasen: las tres se encontraron así en la 003.

---

## 6 · Lo que esta feature NO cambia

- **`Data`**: ni un fichero. No hay dato nuevo, ni consulta nueva, ni migración —por eso no hay
  `data-model.md`—. **`Domain` gana una propiedad calculada y nada más**: `titleWithoutIssuer`, que
  no lee ni escribe nada, solo deriva.
- **`AppContainer`**: ni una dependencia, ni una firma. `AppContainerTests` no se toca.
- **`HomeViewModel`, `HomeUiState`, `HomeView`, `MainView` y el panel lateral**: intactos.
- **La escala tipográfica**: sigue teniendo catorce estilos con los mismos tamaños.
  `BocThemeTests` tiene que seguir en verde **sin editarla**.
- **Los colores**: no se añade ninguno. Los dos de la zona fija ya existen.
- **El catálogo de cadenas**: ni una cadena nueva. Las mayúsculas son de presentación.
- **La costura de las pruebas de interfaz**: los mismos dos argumentos y los mismos cinco escenarios
  de datos. No hace falta uno nuevo.
- **Los dos planes de prueba**, el identificador de paquete y el proyecto de Firebase.
- **El detalle de la publicación**: no se toca. Sus dos divergencias con esta pantalla se anotan en
  el documento de diseño y **se deciden en la 005** (D-414).
