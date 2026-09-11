# Implementation Plan: Buscar con solo filtros

**Branch**: `015-buscar-solo-filtros` | **Date**: 9 de septiembre de 2026 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-buscar-solo-filtros/spec.md`

---

## Summary

Que los filtros de Buscar basten para buscar, y que el texto acote lo que los filtros ya recortaron.
**La consulta al almacén no cambia**: con el texto vacío el patrón ya coincide con todo y los filtros
ya recortan por su cuenta. Lo que cambia es **cuándo** se pregunta, y de paso se cierra una carrera
de la pantalla que este cambio haría rutinaria. El resumen técnico cabe en cuatro frases:

1. **`SearchQuery.isRunnable` pasa a ser «texto suficiente **o** algún filtro».** Una línea en
   dominio. `SearchPublicationsUseCase` y `SearchViewModel.contentFor` lo leen y no cambian. Con un
   filtro puesto, una letra acota; sin filtros, el mínimo de dos se conserva (D-701, D-702).
2. **El contenido de la pantalla se deriva de la consulta contestada, no de la actual.** El flujo de
   resultados emite la consulta que preguntó junto a su respuesta, y `combine` calcula `content` con
   esa pareja mientras el campo y las etiquetas siguen a la consulta viva. Sin estado de carga. Es lo
   que evita el destello de «No hemos encontrado publicaciones» al pulsar «Aplicar» (D-703).
3. **La telemetría se reporta desde la respuesta**, no desde cada reemisión del estado: la huella de
   deduplicación es la consulta contestada —texto normalizado, sin orden—, nunca se serializa, y el
   evento gana `has_text` (D-704).
4. **Nada más se toca.** Ni el DAO, ni el patrón `LIKE`, ni el repositorio, ni las rutas, ni Koin, ni
   Room. Una cadena cambia (`search_initial_body`) y un párrafo de `CLAUDE.md`.
5. **Enmienda tras el recorrido manual (US6).** La fila de etiquetas pasa a `FlowRow` y usa el nombre
   corto de sección, para que «Limpiar todo» se vea siempre; y `filtersOpen` pasa de `rememberSaveable`
   a `remember`, la convención de la casa, para que la hoja no vuelva abierta tras la muerte del
   proceso (D-710, D-711). Dos ficheros más de producto y dos regresiones instrumentadas.

La única decisión con enjundia es la 3: **el destello existía ya** —se veía al pasar de una a dos
letras— y la analítica de la 006 lleva desde entonces contando cero para la primera emisión de cada
búsqueda. Está en [research.md](./research.md) D-703 y D-704.

---

## Technical Context

**Language/Version**: Kotlin 2.2.10, JVM target 11, `minSdk 28` / `targetSdk` 37

**Primary Dependencies**: Jetpack Compose (BOM 2026.02.01) con Material 3, Koin 4.2.2 (BOM),
`kotlinx-coroutines` 1.11.0. **Ninguna nueva.** El catálogo `gradle/libs.versions.toml` no se toca

**Storage**: Room 2.8.4 en la **versión 6**, sin cambios: ni tabla, ni columna, ni migración, ni esquema
exportado nuevo. Ninguna `@Query` se modifica; `PublicationSearchDao` sigue con sus dos sentencias

**Testing**: JUnit 4, MockK, `kotlinx-coroutines-test`, Turbine 1.2.1, Robolectric 4.16.1 (DAO e
integración), Konsist 0.17.3 (`ArchitectureRulesTest`), `createComposeRule` en la única prueba
instrumentada que se ajusta

**Target Platform**: Android 9 (API 28) en adelante, teléfono, vertical, tema claro único

**Project Type**: aplicación Android de módulo único (`:app`), arquitectura limpia + MVVM

**Performance Goals**: una búsqueda por filtros solos es `LIKE '%%'` más los filtros `IS NULL OR …`
que ya existen, con `ORDER BY publication_date DESC … LIMIT 301` sobre un índice en `publication_date`.
Milisegundos sobre unos miles de filas; SC-001 lo fija en menos de un segundo desde «Aplicar»

**Constraints**: ningún texto ni valor de filtro a analítica ni a Crashlytics (FR-019); ni una consulta
nueva al almacén (FR-023); ni red (FR-024); todo texto en `strings.xml`; el recuento de una búsqueda con
texto y filtros **no puede cambiar** (SC-009)

**Scale/Scope**: cero clases de dominio nuevas; cero casos de uso nuevos; 1 propiedad de dominio
redefinida; 1 modelo de pantalla modificado con 1 tipo privado nuevo; 1 cadena modificada; ~7 clases de
prueba ampliadas y 1 instrumentada ajustada en una aserción

---

## Constitution Check

*Puerta obligatoria antes de la fase 0 y revisada de nuevo tras la fase 1.*

| Principio | Cómo se cumple | Veredicto |
|---|---|---|
| **I — SDD, no negociable** | `specify` → `plan` → `tasks` → `implement`. Rama `015-buscar-solo-filtros` creada por Spec Kit sobre `main` con la 014 fusionada (`e177277`). Ninguna línea de producto antes de `tasks.md` | ✅ |
| **II — Arquitectura limpia por capas** | La regla «los filtros bastan» vive en `domain/model/SearchQuery`, que es donde ya viven `isRunnable` y `hasFilters`. `data` no se toca. `ui` sigue hablando solo con casos de uso; el tipo privado `Answer` del modelo de pantalla envuelve dos tipos de dominio y no sale del fichero | ✅ |
| **III — MVVM** | `SearchUiState` y `SearchContentState` no cambian de forma. La derivación «contenido desde la consulta contestada» se hace en el `combine` del `ViewModel`, no en el componible; `SearchScreen` no se toca. `MutableStateFlow` privado, `StateFlow` de solo lectura | ✅ |
| **IV — Koin** | El grafo no cambia: ninguna dependencia nueva, ningún constructor distinto. `KoinModulesTest` no necesita retoque | ✅ |
| **V — Testing exigente, no negociable** | Dos pruebas de regresión que **fallan hoy**: «applying a filter with nothing typed searches by the filter alone» (la regla) y «a search is reported with the count the store answered, not the stale one» (la carrera). Las pruebas que hoy afirman «una letra no basta» se conservan con el matiz «sin filtros» en el nombre: ninguna se borra ni se ignora | ✅ |
| **VI — Observabilidad desacoplada** | Un parámetro nuevo, `has_text`, booleano. La huella de deduplicación es un `SearchQuery` en memoria que **nunca** se serializa; una prueba fija el vocabulario cerrado de claves y valores del evento, y otra que ni el organismo ni las fechas ISO llegan | ✅ |

**Restricciones tecnológicas**: sin dependencias nuevas; ningún color, tamaño ni espaciado; `java.time`
nativo como hasta ahora.

**Konsist**: las nueve reglas siguen en verde sin trabajo extra. `Answer` es un tipo **privado** de
`ui/search`, no una clase de dominio de nivel superior, así que la regla «toda clase de dominio tiene
su prueba» no lo alcanza; y no se introduce ningún `ViewModel` nuevo.

**Puertas de calidad**: las cuatro de siempre, en orden, con `navigation_mode 0` antes de la tanda
instrumentada y un único dispositivo conectado.

**Sin violaciones que justificar.** La sección de complejidad queda vacía a propósito.

---

## Project Structure

### Documentation (this feature)

```text
specs/015-buscar-solo-filtros/
├── spec.md                        24 FR, 10 SC, 5 historias
├── plan.md                        este fichero
├── research.md                    D-701 … D-709
├── data-model.md                  qué regla cambia y qué NO cambia (que es casi todo)
├── contracts/
│   └── internal-contracts.md      isRunnable antes/después, la tabla de verdad, el flujo del
│                                  ViewModel, el evento y la cadena
├── quickstart.md                  las cuatro puertas y el recorrido manual
├── checklists/
│   └── requirements.md            calidad de la especificación
└── tasks.md                       lo genera /speckit-tasks
```

### Source Code (repository root)

```text
app/src/main/java/com/jrblanco/boccantabria/
├── domain/model/SearchQuery.kt                     MODIFICADO  isRunnable = texto suficiente || hasFilters; KDoc
├── domain/usecase/SearchPublicationsUseCase.kt     SOLO KDOC   «sin texto suficiente ni filtros»; el tope con filtros solos
├── ui/search/SearchViewModel.kt                    MODIFICADO  Answer(asked, found); content desde asked;
│                                                               reportSearch sobre la respuesta; has_text; KDoc
├── ui/search/SearchUiState.kt                      SOLO KDOC   qué significa Initial ahora
├── ui/search/component/ActiveFilterChips.kt        MODIFICADO  US6: FlowRow en vez de Row desplazable; shortName
└── ui/search/SearchScreen.kt                       MODIFICADO  US6: filtersOpen con remember

app/src/main/res/values/strings.xml                 MODIFICADO  search_initial_body
CLAUDE.md                                           MODIFICADO  párrafo «Buscar existe desde la feature 006»

app/src/test/java/com/jrblanco/boccantabria/
├── domain/model/SearchQueryTest.kt                 AMPLIADO    filtros solos; una letra con filtro; el orden no cuenta
├── domain/usecase/SearchPublicationsUseCaseTest.kt AMPLIADO    filtros solos llegan al almacén con el mismo tope
├── data/repository/SearchRepositoryImplTest.kt     AMPLIADO    sin texto el patrón es «%%» y los filtros viajan
├── data/source/local/PublicationSearchDaoTest.kt   AMPLIADO    sin texto un filtro devuelve todo lo suyo; search_text vacío
├── data/source/local/LikePatternTest.kt            SOLO KDOC   «%%» ya no es «el problema del llamador»
├── ui/search/SearchViewModelTest.kt                AMPLIADO    la regla, la carrera, la restauración, el vocabulario del evento
└── integration/SearchFlowIntegrationTest.kt        AMPLIADO    sección sola; rango solo; rango vacío; borrar texto con filtro

app/src/androidTest/java/com/jrblanco/boccantabria/
└── ui/search/SearchContentTest.kt                  AMPLIADO    una aserción del estado inicial; US6: dos regresiones
                                                                (Limpiar todo a la vista; la hoja no vuelve) y el nombre corto
```

**Structure Decision**: módulo único `:app` con separación por paquetes, la del proyecto desde la feature
001. Esta feature no crea ningún paquete ni ningún fichero de producto: toca dos ficheros de código
(`SearchQuery.kt`, `SearchViewModel.kt`), dos KDoc y una cadena. Todo lo demás son pruebas.

---

## Fases

### Fase 0 — Investigación *(hecha)*

Nueve decisiones en [research.md](./research.md), D-701 a D-709. Las tres que deciden la forma del código:

- **D-701**: la regla va en `SearchQuery.isRunnable`, una línea, y no en el caso de uso ni en el
  modelo de pantalla. Los dos la leen ya; ponerla en uno de ellos dejaría al otro contando otra verdad.
- **D-703**: el contenido se deriva de la **consulta contestada**. El flujo de resultados emite
  `Answer(asked, found)`; `combine` usa `asked` para `content` y `current` para todo lo demás. Sin
  estado de carga —la decisión de `SearchUiState` se conserva—; lo que cambia es que `Empty` solo puede
  salir de una respuesta real.
- **D-704**: el evento se emite desde el flujo de respuestas, con `onEach`, no desde el estado. Así se
  dispara **una vez por respuesta del almacén** y lleva el recuento que esa respuesta trajo. La huella
  es la consulta contestada normalizada y sin orden; queda en memoria y nunca se escribe.

### Fase 1 — Diseño *(hecha)*

- [data-model.md](./data-model.md) — la regla de dominio antes y después, la tabla de verdad, la
  forma del evento, y la lista explícita de **lo que no cambia**, que en esta feature es casi todo.
- [contracts/internal-contracts.md](./contracts/internal-contracts.md) — `isRunnable` antes/después,
  las garantías del caso de uso, el flujo del `ViewModel` con qué campo sigue a qué consulta, el
  contrato del evento con su vocabulario cerrado, la cadena, y la lista de KDoc que quedan
  desactualizados.
- [quickstart.md](./quickstart.md) — las cuatro puertas, el subconjunto de pruebas para iterar, y el
  recorrido manual de siete pasos con las trampas ya pagadas de `adb`.

### Fase 2 — Tareas

`/speckit-tasks` descompone por historia de usuario. Las historias 1 y 2 (la regla) caen con la misma
línea de dominio y se prueban juntas; la 3 (el destello) es un cambio independiente del `ViewModel` con
sus propias pruebas de regresión; la 4 (restauración) es una prueba, no código; la 5 es una cadena y
una aserción instrumentada. Orden natural: regla → destello → telemetría → cadena → documentación.

### Fase 3 — Implementación

`/speckit-implement`. Cierre con las cuatro puertas en verde y `CLAUDE.md` actualizado en el párrafo de
Buscar: hoy dice que la pestaña «consulta todo lo almacenado, con filtros y orden» y debe añadir que los
filtros bastan para buscar y que el contenido se deriva de la consulta contestada, con el porqué.

---

## Riesgos, con su salida

| Riesgo | Salida |
|---|---|
| El tope de 300 se alcanza casi siempre con una sección sola y se lee como que «Buscar no enseña todo» | Es la decisión D-017 de la 006 conservada a conciencia (D-706). El aviso dice literalmente «Acota la búsqueda para verlas todas». Si el propietario lo encuentra corto, es un número en `SearchPublicationsUseCase.MAX_RESULTS` con su motivo, no parte de esta feature |
| Derivar el contenido de la consulta contestada introduce 250 ms de desfase entre las etiquetas y la lista | Ya existía entre tecla y tecla, porque el `debounce` es el mismo; ahora es explícito. Lo que se ve en ese lapso es lo que había, nunca «sin resultados». Quitar la última etiqueta deja la lista un cuarto de segundo antes de volver al inicial. Se anota en el contrato y se comprueba en el recorrido manual |
| Room reemite la misma consulta cuando cambia algo del almacén (guardar un resultado, una sincronización), y el evento se reportaría dos veces | La huella de deduplicación se conserva exactamente para eso: misma consulta contestada → un solo evento. Lo fija la prueba «the same answer arriving twice is reported once» |
| Alguien vuelve a leer `state.query` en `reportSearch` y la analítica vuelve a contar el resultado viejo | La prueba «a search is reported with the count the store answered, not the stale one» hace `advanceUntilIdle()` **antes** de escribir, que es lo que hoy nadie hace y por lo que el defecto llevaba desde la 006 sin verse |
| `LIKE '%%'` sobre miles de filas es lento | El `WHERE` restante usa los índices de `publication_date`, `section_code` y `subsection_code`, y el `LIMIT 301` corta pronto. Se mide en el recorrido manual (SC-001) con el archivo real del emulador |
| Las filas anteriores a la 006 con `search_text = ''` aparecen ahora por filtros pero no por texto, y alguien lo lee como inconsistencia | Está declarado en la spec como efecto lateral benigno y hay prueba de DAO que lo afirma. El relleno por lotes de `refresh()` sigue su curso y las alcanza |

---

## Complexity Tracking

Sin violaciones de la constitución. Tabla vacía a propósito.
