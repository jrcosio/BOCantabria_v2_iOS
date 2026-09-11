# Implementation Plan: La tarjeta se lee de un vistazo, y la cabecera no se va

**Branch**: `004-tarjeta-y-cabecera` | **Date**: 12 de septiembre de 2026 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-tarjeta-y-cabecera/spec.md`

## Summary

Dos retoques de composición sobre la pantalla que la 003 dejó funcionando. **Ni un dato entra, ni un
dato sale.**

El primero es la **jerarquía de la tarjeta**: los cuatro datos suben o bajan de peldaño dentro de la
escala tipográfica que ya existe —la sección de 11 a 15, el organismo de 12 a 16 y en mayúsculas, el
título de 17 a 20, la fecha de 12 a 14—, y la fila de la fecha se funde con la de las acciones. El
segundo es **quién se desplaza**: hoy la pantalla entera vive dentro de un `ScrollView` y a las dos
tarjetas se ha perdido de vista qué se está mirando; pasa a ser un `VStack` con la barra superior,
la cabecera, los filtros y el aviso fijos, y un `ScrollView` que envuelve solo el listado.

El enfoque técnico es **no inventar nada nuevo y no medir nada que no haga falta**. La escala de
catorce no se toca: lo que cambia es qué peldaño usa cada dato, así que `BocThemeTests` sigue en
verde sin tocarla y no aparece ni un tamaño escrito a mano. Y la cabecera que encoge no observa el
desplazamiento: observa **un booleano derivado de un umbral**, publicado por
`onScrollGeometryChange`. Publicar el desplazamiento redibujaría la cabecera en cada fotograma para
decir lo mismo sesenta veces por segundo.

**Sin `data-model.md`, y decirlo es parte del plan.** Esta feature no introduce, no modifica y no
consulta ningún dato: no hay entidad, no hay columna, no hay consulta y no hay migración. Es la
misma `Publication` que la 003 guarda y observa, pintada de otra forma. Un `data-model.md` vacío
diría que se miró y no había nada; no escribirlo, y escribir por qué, dice lo mismo sin dejar un
fichero que alguien tenga que mantener. **Y sin `/speckit-analyze`**: veinte requisitos sobre tres
ficheros de producción no dan para una tabla de coherencia que no se vea de un vistazo.

## Technical Context

**Language/Version**: Swift 6.0 (modo de lenguaje 6, concurrencia estricta, aislamiento por defecto
`nonisolated`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`), Xcode 26.6

**Primary Dependencies**: SwiftUI y nada más. **Esta feature no toca GRDB, no toca URLSession, no
toca Firebase y no añade ninguna dependencia.** Del sistema se usan tres API de SwiftUI que el
proyecto no había necesitado hasta ahora: `ViewThatFits` (iOS 16.0), `scrollBounceBehavior`
(iOS 16.4) y `onScrollGeometryChange` (iOS 18.0). Las tres están comprobadas en la interfaz del SDK
instalado, no recordadas (D-404, D-407, D-408).

**Storage**: ninguno. No se abre la base, no se lee y no se escribe. La pantalla sigue observando lo
que la 003 dejó montado.

**Testing**: Swift Testing para lo unitario; XCUITest para la interfaz. **Los dos planes de prueba
no cambian** y no hace falta ni un escenario nuevo de la costura: `-boc-data-scenario=today` ya
siembra bastante contenido para que el listado se desplace.

**Target Platform**: iOS 18.0 o superior, solo iPhone, solo vertical, apariencia clara fijada.

**Project Type**: aplicación móvil. Un único target, separación por carpetas.

**Performance Goals**: los de la 003 se conservan y ninguno se relaja. Lo que esta feature añade es
un objetivo propio: **la cabecera no puede redibujarse por fotograma al desplazar**, que es la razón
de que lo publicado sea un booleano y no una cifra (D-408).

**Constraints**: ningún color, tamaño ni espaciado nuevo fuera del tema —los cuatro peldaños salen
de la escala de catorce y los dos colores de la zona fija ya existen—; las pruebas siguen sin
depender del idioma del dispositivo; y **ninguna prueba se silencia**: las dos que esta feature pone
rojas se arreglan diciendo lo que querían decir (D-412).

**Scale/Scope**: **3 ficheros de producción modificados** —la tarjeta, el contenido de Inicio y la
cabecera editorial—, **0 nuevos**, **0 retirados**. 1 fichero de prueba nuevo, 3 modificados.
Además, 3 documentos enmendados. Ni una cadena nueva en el catálogo.

## Constitution Check

*GATE: comprobado antes de la investigación y vuelto a comprobar tras el diseño.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| **I. SDD obligatorio** | ✅ | La feature recorre el ciclo completo en su rama `004-tarjeta-y-cabecera`. **No está exenta**: la lista de exentos es cerrada —configuración de Xcode, subidas de versión, erratas y documentación— y esto es código de producto que cambia lo que se ve. Es además la **primera feature del proyecto sin origen en Android**, así que aquí no hay requisitos que reutilizar: se escribieron mirando la pantalla |
| **II. Arquitectura limpia** | ✅ | No se toca `Domain` ni `Data`. Los tres ficheros que cambian son de `Core/UI/Component` y de `UI/Home`, y ninguno gana un `import` nuevo: los tres ya importan `SwiftUI` y nada más. Las reglas 1, 2, 3, 6 y 10 no tienen nada nuevo que ver |
| **III. MVVM** | ⚠️ | `HomeUiState` **no cambia**: el estado compacto de la cabecera no es estado de pantalla. Es `@State` de `HomeContentView` (D-409), igual que el abierto/cerrado del panel lo es de `MainView` (D-319 de la 003). La consecuencia es que `HomeContentView` deja de ser literalmente «sin estado» y su cabecera lo dice hoy; se declara abajo en *Complexity Tracking* |
| **IV. Composition root** | ✅ | El grafo no cambia: ni una dependencia nueva, ni una firma de inicializador tocada en `AppContainer`. `AppContainerTests` no se toca |
| **V. Testing exigente** | ✅ | Una prueba unitaria nueva que pone en rojo cualquier intento de igualar los cuatro peldaños (D-403, FR-018), una prueba de interfaz nueva para la cabecera que se queda y encoge (FR-019) y dos existentes ampliadas. **Ninguna se desactiva, se comenta ni se debilita**: las dos que el cambio pone rojas se arreglan diciendo lo que querían decir desde el principio (D-412) |
| **VI. Observabilidad desacoplada** | ✅ | No se emite ni un evento nuevo, no se registra ni una línea nueva y ningún SDK se acerca a estos tres ficheros. Que la fecha cambie de fila no le interesa a nadie fuera del dispositivo |
| **Restricciones tecnológicas** | ✅ | SwiftUI, sin UIKit y sin Storyboards. Sin Combine y sin `DispatchQueue`: `onScrollGeometryChange` entrega en el actor principal. Tema único claro: los dos colores de la zona fija son `colors.surface` y `colors.divider`, que ya existen, así que **la regla 7 no tiene nada nuevo que cazar y la 8 sigue intacta** |

**Tres desviaciones, las tres declaradas** en *Complexity Tracking*. Ninguna toca una capa, ninguna
añade una dependencia y ninguna introduce un patrón que el proyecto no use ya.

## Project Structure

### Documentation (this feature)

```text
specs/004-tarjeta-y-cabecera/
├── plan.md              # Este fichero
├── research.md          # Decisiones D-401 … D-415
├── quickstart.md        # Doce pasos de verificación
├── contracts/
│   └── internal-contracts.md
├── checklists/
│   └── requirements.md
├── spec.md
└── tasks.md             # Lo genera /speckit-tasks

# SIN data-model.md, a propósito: no entra ni sale un dato. El motivo está en el Summary.
```

### Source Code (repository root)

```text
BOCantabria-ios/
├── Core/UI/Component/PublicationCard.swift         MODIFICADO  cuatro peldaños, mayúsculas y una
│                                                               sola fila para fecha y acciones
└── UI/Home/
    ├── HomeContentView.swift                       MODIFICADO  VStack fijo + ScrollView solo en el
    │                                                           listado; gana un @State booleano
    └── Component/BulletinHeaderView.swift          MODIFICADO  gana isCompact

BOCantabria-iosTests/
└── Core/PublicationCardTypographyTests.swift       NUEVO       los cuatro peldaños son distintos y
                                                                salen de la escala (FR-018, FR-008)

BOCantabria-iosUITests/Home/
├── HomeStickyHeaderUITests.swift                   NUEVO       se queda, encoge y vuelve (FR-019)
├── AccessibilityUITests.swift                      MODIFICADO  el organismo se compara sin
│                                                               distinguir mayúsculas (D-412)
└── HomeBackgroundUITests.swift                     MODIFICADO  la posición de lectura se mide,
                                                                no se supone (FR-016, D-413)

docs/diseno/especificaciones-diseno.md              MODIFICADO  §6.3, §12.1, §14.6, §18.2 y §18.3
specs/003-boletin-del-dia/contracts/
    internal-contracts.md                           MODIFICADO  dos firmas que ya no coincidían
CLAUDE.md                                           MODIFICADO  la tabla de orden de portado
```

**Structure Decision**: no hay estructura que decidir. Los tres ficheros de producción ya están en
su sitio desde la 003 y ninguna carpeta nace ni desaparece. La única ubicación que hay que elegir es
la de la prueba nueva, y va a `BOCantabria-iosTests/Core/` junto a `BocThemeTests.swift`, porque
habla de la escala tipográfica y del componente compartido, no de una pantalla.

### Cómo queda la composición de Inicio

```text
VStack(spacing: 0) {
    HomeTopBar(…)                          fija
    BulletinHeaderView(…, isCompact:)      fija · encoge al desplazar          ┐
    SectionChipRow(secciones)              fija                                │ fondo `surface`
    [SectionChipRow(subsecciones)]         fija · solo cuando procede          │ y divisor inferior
    [OfflineBanner]                        fija · solo sin conexión            ┘ (§14.6)
    ScrollView { listado }                 ← lo ÚNICO que se desplaza
        .refreshable { … }                 el gesto va aquí (FR-015)
        .scrollBounceBehavior(.always)     o el gesto muere en vacío y error (D-407)
        .onScrollGeometryChange { … }      publica un booleano, no el desplazamiento (D-408)
}
```

## Complexity Tracking

Tres desviaciones. Ninguna añade una capa, un patrón nuevo ni una dependencia.

| Desviación | Por qué hace falta | Alternativa más simple, y por qué se rechaza |
|---|---|---|
| **`HomeContentView` gana un `@State`** y deja de ser literalmente «sin estado», que es lo que dice su propia cabecera y lo que el principio III pide de las vistas reutilizables | El umbral solo lo conoce el `ScrollView`, y el `ScrollView` vive dentro de esta vista. El dato es efímero, no sobrevive a nada, no lo consulta nadie más y no describe el boletín: describe dónde está el dedo. El proyecto ya tiene el precedente exacto —el abierto/cerrado del panel es `@State` de `MainView` (D-319)—, así que esto no abre una puerta, entra por una que ya estaba abierta. **La cabecera del fichero se corrige en el mismo cambio**, que es lo que evita que la mentira se quede escrita | **Subirlo a `HomeUiState`**: mete en el estado de la pantalla algo que el modelo de pantalla no puede decidir ni comprobar, y obliga a que cada fotograma de desplazamiento cruce el actor principal hasta el modelo y vuelva. **Izarlo a `HomeView` con un `Binding`**: el estado sube un nivel para que lo escriba la misma vista que hoy, y las tres vistas previas pasan a necesitar un `.constant(false)` que no aporta nada |
| **El umbral y la histéresis se escriben como constantes con nombre**, y no salen de `BocTheme`, cuando la guía operativa dice que ningún tamaño se escribe fuera del tema | No son tamaños del sistema de diseño: son **un umbral de gesto**. El documento de diseño no los declara y no debería, porque no describen nada que se vea. Meterlos en `BocSpacing` diría que son parte de la escala de espaciados y que alguien puede usarlos para separar dos vistas. Van con nombre y con comentario, exactamente como los `48` del área táctil que la tarjeta ya declara citando el §12.1 | **Un token nuevo en el tema**: contamina la escala con un valor que nadie más puede usar. **Escribirlos en línea sin nombre**: es el literal suelto que la guía prohíbe con razón, porque nadie sabe después de dónde salió el 24 |
| **FR-018 se cumple con una prueba unitaria sobre los cuatro peldaños, no con una prueba de interfaz que mida cuatro alturas** —que es lo que el requisito dice literalmente | La tarjeta se declara `.accessibilityElement(children: .combine)` porque un lector de pantalla tiene que recorrerla de un gesto, no de cuatro. Con eso, **los cuatro textos no existen en el árbol de accesibilidad** y ninguna prueba de interfaz puede medirlos. La prueba unitaria comprueba más: que los cuatro son distintos, que van en el orden declarado y que los cuatro salen de la escala de catorce (D-403) | **Romper el `.combine` y dar identificador a cada texto**: sacrifica la accesibilidad real de la tarjeta para poder medirla, que es medir otra cosa. **Renunciar a la comprobación**: es justo lo que FR-018 existe para impedir, porque igualar cuatro tokens es un cambio de una línea que nadie nota en revisión |

**Lo que NO se desvía, y conviene dejar escrito.** La escala tipográfica **no se toca**:
`BocThemeTests` afirma que tiene catorce estilos y tres tamaños concretos, y esa prueba tiene que
seguir en verde sin que nadie la edite —es la señal de que esta feature cambió el uso y no la
norma—. La costura de las pruebas de interfaz **no crece**: siguen siendo los dos argumentos de la
003 y los cinco escenarios de datos de siempre. `HomeViewModel`, `HomeUiState`, `AppContainer` y los
dos planes de prueba **no se tocan**. Y la 003 **no se reescribe**: está cerrada e integrada, y lo
único que se corrige de ella son **dos firmas de sus contratos** que ya no coincidían con su propio
código antes de esta feature (D-415).
