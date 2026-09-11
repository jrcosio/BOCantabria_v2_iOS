---

description: "Task list for feature 015 — Buscar con solo filtros"
---

# Tasks: Buscar con solo filtros

**Input**: Design documents from `/specs/015-buscar-solo-filtros/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/internal-contracts.md](./contracts/internal-contracts.md),
[quickstart.md](./quickstart.md)

**Tests**: **obligatorios**. El principio V de la constitución es no negociable y SC-010 lo recoge.
Ninguna tarea se da por terminada sin su prueba en verde, y está prohibido `@Ignore`, comentar o
borrar una prueba para que pase la build. Las pruebas que hoy afirman «una letra no basta» **se
conservan** con el matiz «sin filtros» en el nombre; ninguna aserción existente se debilita.

**Dos pruebas tienen que estar en rojo antes de su cambio**, porque las dos corrigen algo que hoy
ocurre: T003 (los filtros no buscan) y T017 (el evento lleva el recuento viejo). Se escriben primero,
se ven fallar, y entonces se toca el código.

**Organization**: por historia de usuario. US1 lleva el cambio de dominio que también sirve a US2 y
US4 —una sola línea, `SearchQuery.isRunnable`—, así que esas dos dependen de US1. US3 (el destello) y
US5 (la cadena) son independientes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ir en paralelo (fichero distinto, sin dependencias pendientes)
- **[Story]**: US1 … US5, la historia de `spec.md` a la que sirve
- Toda tarea lleva la ruta exacta del fichero

## Path Conventions

Aplicación Android de módulo único. Producto en
`app/src/main/java/com/jrblanco/boccantabria/`, recursos en `app/src/main/res/`, pruebas unitarias en
`app/src/test/java/com/jrblanco/boccantabria/` e instrumentadas en
`app/src/androidTest/java/com/jrblanco/boccantabria/`.

---

## Phase 1: Setup

**Purpose**: partir de una línea base conocida, para que cualquier rojo posterior sea de esta feature.

- [X] T001 Confirmar que la rama activa es `015-buscar-solo-filtros` y que parte de `main` con la feature 014 integrada (`e177277`), con `git branch --show-current` y `git log --oneline -1 main`
- [X] T002 Dejar la línea base en verde antes de tocar nada: `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"` y después `./gradlew :app:assembleDebug` y `./gradlew :app:testDebugUnitTest --tests "*Search*"`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: ninguno.

**Esta fase está vacía a propósito.** Esta feature no introduce ninguna entidad, ningún caso de uso,
ninguna dependencia, ninguna migración y ningún cambio en el grafo de Koin (`data-model.md` §1). El
único cambio que sirve a varias historias —la línea de `isRunnable`— va en la primera historia que lo
necesita, US1, que es donde el template manda ponerlo. Inventar aquí una tarea «preparatoria» sería
separar una línea de la prueba que la justifica.

**Checkpoint**: con T001 y T002 hechas, US1, US3 y US5 pueden empezar, en paralelo si hay manos.

---

## Phase 3: User Story 1 — Ver todo lo que cumple un filtro sin escribir nada (Priority: P1) 🎯 MVP

**Goal**: que aplicar un filtro con el campo vacío busque y muestre todo lo que cumple el filtro, con
recuento y aviso de truncado si toca.

**Independent Test**: en Buscar, sin texto, aplicar una sección y ver su lista; repetir con fecha,
rango, subsección y organismo.

**Requisitos que cierra**: FR-001, FR-002, FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, FR-023.

### Prueba de regresión, primero

- [X] T003 [US1] Añadir a `app/src/test/java/com/jrblanco/boccantabria/ui/search/SearchViewModelTest.kt`, en la sección «Filters and order», la prueba `applying a filter with nothing typed searches by the filter alone`: `searchRepository.emit(listOf(publication("boc:1")))`, construir el modelo, `onFiltersApplied(SearchQuery(sectionCode = "1"))`, `advanceUntilIdle()`, y afirmar `content is SearchContentState.Results` y `searchRepository.queries.last().sectionCode == "1"` con `text == ""`. Ejecutarla con `./gradlew :app:testDebugUnitTest --tests "*SearchViewModelTest*applying a filter with nothing typed*"` y **confirmar que falla** (hoy `content` es `Initial` y `queries` está vacío)

### Implementación

- [X] T004 [US1] En `app/src/main/java/com/jrblanco/boccantabria/domain/model/SearchQuery.kt:37`, cambiar `isRunnable` a `normalisedText.length >= MIN_TEXT_LENGTH || hasFilters` y reescribir su KDoc (:30-36) según el contrato §1.1: una letra sola sigue sin ir al archivo; un filtro sí, porque ya acota; y sobre un filtro una letra solo reduce. **No** añadir ninguna propiedad nueva (research D-702)
- [X] T005 [US1] En `app/src/main/java/com/jrblanco/boccantabria/domain/usecase/SearchPublicationsUseCase.kt`, actualizar los dos KDoc sin tocar código: :18-19 («…with neither enough text nor a filter never reaches the store») y :39 (con filtros solos el tope se supera a menudo y la pantalla lo dice; la salida sigue siendo acotar). `MAX_RESULTS` sigue en 300 (research D-706)
- [X] T006 [US1] Volver a ejecutar T003 y confirmar que ahora pasa

### Pruebas

- [X] T007 [P] [US1] En `app/src/test/java/com/jrblanco/boccantabria/domain/model/SearchQueryTest.kt`: renombrar `one character is not enough to go to the archive with` (:24) a `without a filter, one character is not enough to go to the archive with` **sin tocar sus aserciones**; añadir `a filter alone is enough to go to the archive with` con cinco aserciones —`from`, `to`, `sectionCode`, `subsectionCode`, `issuer`, cada una sola y con `text = ""`— y `the order alone is not a filter and runs nothing` (`SearchQuery(sort = SearchSort.OLDEST_FIRST).isRunnable == false`)
- [X] T008 [P] [US1] En `app/src/test/java/com/jrblanco/boccantabria/domain/usecase/SearchPublicationsUseCaseTest.kt`: renombrar `a query too short never reaches the store` (:19) a `a short query with no filters never reaches the store`; añadir `filters alone reach the store, with the same cap` (`useCase(SearchQuery(sectionCode = "1")).first()`, `repository.queries.single().sectionCode == "1"`, `repository.limits.single() == SearchPublicationsUseCase.MAX_RESULTS + 1`) y `the order alone never reaches the store`
- [X] T009 [P] [US1] En `app/src/test/java/com/jrblanco/boccantabria/data/repository/SearchRepositoryImplTest.kt`, añadir `with nothing typed the pattern matches everything`: con `SearchQuery(sectionCode = "1", issuer = "X")` el patrón que llega al DAO es `"%%"` y los filtros viajan tal cual, siguiendo el estilo del caso `a filter nobody set travels as null` (:93)
- [X] T010 [P] [US1] En `app/src/test/java/com/jrblanco/boccantabria/data/source/local/PublicationSearchDaoTest.kt`, añadir con el `search(...)` privado (:248) y `entity(...)`: `with no text, a filter brings back every row it allows` (tres filas de la sección «1» y una de la «2»; `search("", sectionCode = "1")` devuelve exactamente las tres) y `a row whose searchable text was never filled in is still found by a filter` (una entidad con `searchText = ""` aparece con texto vacío y filtro de sección). Reformular el KDoc de `LikePatternTest.kt:42`: `%%` deja de ser «el problema del llamador» y pasa a ser cómo una búsqueda por filtros pide todo (research D-707)
- [X] T011 [US1] En `SearchViewModelTest.kt`: renombrar `a single character never reaches the store` (:59) a `a single character with no filters never reaches the store` sin tocar aserciones; añadir `changing the order with nothing typed and no filters searches nothing` (`onSortChanged(OLDEST_FIRST)`, `advanceUntilIdle()`, `content == Initial`, `queries.isEmpty()`)
- [X] T012 [US1] En `app/src/test/java/com/jrblanco/boccantabria/integration/SearchFlowIntegrationTest.kt`, con el `synchronise()` y `searchViewModel()` que ya tiene, añadir: `a section chosen with nothing typed brings back everything filed under it` (fixture real, `onFiltersApplied(SearchQuery(sectionCode = "1"))` sin texto → `Results` con todas las de la sección 1); `a date range with nothing typed brings back what was published in it` (`synchronise` con dos `rssItem` de fechas `2026-08-01` y `2026-08-27`, `from = to = 2026-08-27` → solo la segunda); `a range nothing falls in is an empty state, never an error` (`from = to = 2026-01-01` → `Empty`)
- [X] T013 [US1] Ejecutar `./gradlew :app:testDebugUnitTest --tests "*Search*"` y dejarlo en verde

**Checkpoint**: US1 completa y demostrable sola. US2 y US4 pueden empezar.

---

## Phase 4: User Story 2 — El texto concreta lo que los filtros ya acotaron (Priority: P1)

**Goal**: que con un filtro puesto el texto acote desde la primera letra, que borrar el texto devuelva
la lista del filtro, y que quitar la última etiqueta sin texto vuelva al estado inicial.

**Independent Test**: con una sección aplicada, escribir una letra y ver la lista acotarse; borrar y
verla volver; quitar la etiqueta y ver el estado inicial.

**Requisitos que cierra**: FR-003, FR-010, FR-011.

**Depende de US1**: es la misma línea de dominio. Esta fase solo añade pruebas.

### Pruebas

- [X] T014 [P] [US2] En `SearchQueryTest.kt`, añadir `with a filter on, a single character is runnable and keeps its text` (`SearchQuery(text = "a", sectionCode = "1")`: `isRunnable` y `normalisedText == "a"`) y `clearing the last filter with nothing typed leaves nothing to run` (`SearchQuery(sectionCode = "1").clearedFilters().isRunnable == false`)
- [X] T015 [P] [US2] En `SearchViewModelTest.kt`, añadir: `a single character with a filter on reaches the store and narrows` (`onFiltersApplied(SearchQuery(sectionCode = "1"))`, `onQueryChanged("a")`, `advanceUntilIdle()`, `queries.last().text == "a"` y `sectionCode == "1"`); `clearing the text with a filter on keeps the filtered results` (filtro + `onQueryChanged("pielagos")` + `onClearQuery()` → `Results`, y `queries.last().text == ""` con el filtro); `removing the last filter with nothing typed goes back to the initial state` (filtro solo, `onRemoveSection()`, `advanceUntilIdle()` → `Initial`)
- [X] T016 [P] [US2] En `SearchFlowIntegrationTest.kt`, añadir `clearing the text but not the filter keeps the results`: `synchronise()`, filtro de sección «1», texto «pielagos», `onClearQuery()` → `Results` con las de la sección
- [X] T017 [US2] Ejecutar `./gradlew :app:testDebugUnitTest --tests "*SearchQueryTest*" --tests "*SearchViewModelTest*" --tests "*SearchFlowIntegrationTest*"` y dejarlo en verde

**Checkpoint**: US2 completa. Las dos vías —texto y filtros— se componen.

---

## Phase 5: User Story 3 — Sin destellos: la pantalla no dice «no hay nada» antes de saberlo (Priority: P2)

**Goal**: que el contenido se derive de la consulta contestada, para que `Empty` solo salga de una
respuesta real, y que el evento de analítica lleve el recuento contestado, una vez por respuesta.

**Independent Test**: desde el estado inicial, aplicar una sección con coincidencias y observar la
secuencia de estados sin `Empty` en medio; comprobar que el evento lleva `results` distinto de `0`.

**Requisitos que cierra**: FR-014, FR-015, FR-016, FR-019, FR-020, FR-021.

**Independiente de US1 en código.** T019 solo tiene sentido con US1 hecha (sin ella los filtros no
son ejecutables), pero T018 falla hoy tal cual.

### Pruebas de regresión, primero

- [X] T018 [US3] Añadir a `SearchViewModelTest.kt`, en la sección de telemetría, `a search is reported with the count the store answered, not the stale one`: `searchRepository.emit(listOf(publication("boc:1")))`, construir el modelo, **`advanceUntilIdle()` antes de escribir** —es lo que hace emitir `results` una vez y arma la carrera—, después `onQueryChanged("pielagos")`, `advanceUntilIdle()`, y afirmar que **ningún** evento `boc_search` lleva `results == "0"` y que el último lleva `"1-9"`. Ejecutarla y **confirmar que falla** (hoy el primer evento sale con `0` y la huella bloquea el real)
- [X] T019 [US3] Añadir `applying a filter never shows the empty state before the store answers`: emitir una publicación, construir el modelo, `advanceUntilIdle()`, `onFiltersApplied(SearchQuery(sectionCode = "1"))`, y recoger con `awaitItem()` en bucle hasta ver `Results`, afirmando que ningún item intermedio tiene `content == Empty`. Con US1 hecha y antes de T020, **falla** (sale `Empty` un instante)

### Implementación

- [X] T020 [US3] En `app/src/main/java/com/jrblanco/boccantabria/ui/search/SearchViewModel.kt`: declarar al final del fichero `private data class Answer(val asked: SearchQuery, val found: SearchResults)`; cambiar `results` (:80-84) a `Flow<Answer>` con `flatMapLatest { asked -> searchPublications(asked).map { Answer(asked, it) } }`; en `combine` (:86-101) calcular `content = contentFor(answer.asked, answer.found)` y dejar `query = current`; **mantener cinco flujos** en `combine`. Reescribir el KDoc :81-83 (el suelo y la excepción de los filtros viven en `SearchQuery`) según el contrato §2.1 y research D-703
- [X] T021 [US3] En el mismo fichero: mover el efecto —quitar `.onEach(::reportSearch)` de la cadena de `uiState` (:105) y ponerlo sobre `results`—; cambiar `reportSearch` a `(answer: Answer)`, con `if (!answer.asked.isRunnable) return`, huella `answer.asked.copy(text = answer.asked.normalisedText, sort = SearchSort.DEFAULT)`, `lastReported: SearchQuery?`, recuento de `answer.found.items.size`, y el parámetro nuevo `"has_text" to answer.asked.normalisedText.isNotEmpty().toString()`. Reescribir el KDoc de `lastReported` (:71-77): es la consulta contestada normalizada, solo memoria, y **nunca** se serializa porque `toString()` llevaría el texto. Mover y reescribir el comentario del `onEach` (:102-104) (research D-704)
- [X] T022 [US3] Volver a ejecutar T018 y T019 y confirmar que pasan

### Pruebas

- [X] T023 [P] [US3] En `SearchViewModelTest.kt`, añadir: `the same answer arriving twice is reported once` (dos `searchRepository.emit(...)` con la misma lista tras una búsqueda → un solo evento `boc_search`); `two different filter sets with no text are reported twice` (sección «1», luego sección «2», sin texto → dos eventos); `every parameter of the search event comes from a closed vocabulary` (para todo evento `boc_search`: `parameters.keys == setOf("has_filters", "has_text", "results")` y cada valor en `setOf("true", "false", "0", "1-9", "10-99", "100+")`); `what a filter says never reaches telemetry either` (filtro con `issuer = "Ayuntamiento de Piélagos"` y `from = LocalDate.of(2026, 8, 27)` → ningún valor contiene `"Piélagos"`, `"pielagos"` ni `"2026-"`)
- [X] T024 [US3] Confirmar **sin modificarlas** que `the query text never reaches telemetry` (:409) y `clearing the text goes back to the initial state` (:139) siguen en verde: la primera porque el evento sigue saliendo con `"1-9"`, la segunda porque tras `advanceUntilIdle()` la respuesta a la consulta vacía llega y `contentFor("", EMPTY)` es `Initial`
- [X] T025 [US3] Ejecutar `./gradlew :app:testDebugUnitTest --tests "*SearchViewModelTest*" --tests "*SearchFlowIntegrationTest*"` y dejarlo en verde

**Checkpoint**: US3 completa. `Empty` solo puede salir de una respuesta real y la analítica cuenta lo
que se mostró.

---

## Phase 6: User Story 4 — Volver y encontrarlo igual, también sin texto (Priority: P2)

**Goal**: que un modelo restaurado con filtros y sin texto relance la búsqueda solo.

**Independent Test**: aplicar una sección sin texto, matar el proceso, volver: la lista aparece sin
intervención.

**Requisitos que cierra**: FR-017.

**Depende de US1.** No hay código: `persist()` y `restoreQuery()` ya escriben y leen todos los filtros;
lo que cambia es que ahora lo restaurado es ejecutable. Esta fase es una prueba (research D-708).

### Pruebas

- [X] T026 [US4] En `SearchViewModelTest.kt`, añadir `a model rebuilt from saved state with filters and no text searches at once`: `searchRepository.emit(listOf(publication("boc:1")))`, `viewModel(SavedStateHandle(mapOf(SearchViewModel.KEY_SECTION to "1")))`, `advanceUntilIdle()`, y afirmar `content is Results`, `state.query.text == ""`, `state.query.sectionCode == "1"` y `queries.single().sectionCode == "1"`
- [X] T027 [US4] Confirmar **sin modificarlas** que `app/src/androidTest/java/com/jrblanco/boccantabria/ui/search/SearchStateRestoredTest.kt` y `app/src/androidTest/java/com/jrblanco/boccantabria/ui/SearchHandoffTest.kt` no necesitan cambio: la primera prueba la persistencia del `SavedStateHandle`, que no cambia; la segunda, el puente, que tampoco (FR-018). Dejar constancia en el mensaje de commit
- [X] T028 [US4] Ejecutar `./gradlew :app:testDebugUnitTest --tests "*SearchViewModelTest*"` y dejarlo en verde

**Checkpoint**: US4 completa.

---

## Phase 7: User Story 5 — El estado inicial ofrece las dos vías (Priority: P3)

**Goal**: que el estado inicial diga que se puede escribir **o** aplicar un filtro.

**Independent Test**: abrir Buscar sin nada y leer el estado inicial.

**Requisitos que cierra**: FR-012, FR-013, FR-022.

### Implementación

- [X] T029 [P] [US5] En `app/src/main/res/values/strings.xml:148`, cambiar `search_initial_body` a `Escribe al menos dos letras o aplica un filtro y verás las publicaciones que coincidan.` **Ninguna otra cadena** se toca: `search_empty_body` ya cubre los dos casos y `SearchContentTest.kt:143` la afirma por subcadena (research D-705)
- [X] T030 [P] [US5] En `app/src/main/java/com/jrblanco/boccantabria/ui/search/SearchUiState.kt:35`, reescribir el KDoc de `Initial`: «Neither enough text nor a filter, or the store has not answered anything yet. Neither an empty result nor a failure» (contrato §2.2)

### Pruebas

- [X] T031 [US5] En `app/src/androidTest/java/com/jrblanco/boccantabria/ui/search/SearchContentTest.kt`, dentro de `before_there_is_anything_to_search_for_the_screen_says_so_without_saying_empty` (:63), añadir `composeRule.onNodeWithText("aplica un filtro", substring = true).assertIsDisplayed()`. Sobre el nodo de texto, **no** sobre `fetchSemanticsNode().config.toString()` (trampa documentada en `CLAUDE.md`). No crear ninguna clase nueva (research D-708)
- [X] T032 [US5] Ejecutar la clase con `./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.jrblanco.boccantabria.ui.search.SearchContentTest` (recordatorio: `--tests` **no existe** en `connectedDebugAndroidTest`)

**Checkpoint**: las cinco historias completas.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T033 [P] Actualizar `CLAUDE.md`, párrafo «**Buscar existe desde la feature 006 y son dos búsquedas, no una.**»: añadir que desde la 015 los filtros bastan para buscar y con un filtro una letra acota, que el mínimo de dos letras se conserva sin filtros, y que el contenido de la pantalla se deriva de la **consulta contestada** para que «sin resultados» nunca salga de una respuesta vieja —con la nota de que ese destello existía desde la 006 y la analítica contaba cero por él— (research D-709)
- [X] T034 Comprobaciones de no-regresión: `git diff --stat main -- app/schemas/ app/src/main/java/com/jrblanco/boccantabria/data/ gradle/libs.versions.toml app/build.gradle.kts app/src/main/java/com/jrblanco/boccantabria/ui/search/SearchScreen.kt app/src/main/java/com/jrblanco/boccantabria/core/di/` debe salir **vacío** en los seis (FR-023, `data-model.md` §1). En `domain/` solo puede aparecer `SearchQuery.kt` y `SearchPublicationsUseCase.kt`
- [X] T035 Puerta 1: `./gradlew :app:assembleDebug`
- [X] T036 Puerta 2: `./gradlew :app:testDebugUnitTest`
- [X] T037 Puerta 3: `adb shell settings put secure navigation_mode 0` y después `./gradlew :app:connectedDebugAndroidTest` con **un solo dispositivo** conectado o `ANDROID_SERIAL` fijado. Tarda dos o tres horas; lanzarla en segundo plano
- [X] T038 Puerta 4: `./gradlew :app:lintDebug`; el número de incidencias debe ser el mismo que en `main`
- [X] T039 Recorrido manual completo de `quickstart.md` §4, los siete pasos, en emulador con datos sincronizados, cronometrando el paso 1 (SC-001) y mirando que el paso 6 muestre el vacío **después** de un instante y no antes (SC-005); y §4 bis, la analítica en logcat, comprobando que el evento de una sección sin texto lleva `has_filters=true`, `has_text=false` y un tramo distinto de `0` (SC-006, SC-008)

---

## Phase 9: User Story 6 — Las etiquetas se ven enteras y la hoja no vuelve sola (Priority: P3)

**Goal**: que todas las etiquetas y «Limpiar todo» se vean sin desplazar, con el nombre corto de
sección, y que la hoja de filtros no se restaure abierta tras la muerte del proceso.

**Independent Test**: aplicar fechas, sección y organismo y ver «Limpiar todo» sin desplazar; abrir la
hoja, matar el proceso y volver: la hoja no está, las etiquetas sí.

**Requisitos que cierra**: FR-025, FR-026, FR-027, FR-028.

**Añadida el 9 de septiembre de 2026, tras el recorrido manual**, por decisión del propietario
(research D-710 y D-711): fila que envuelve más nombres cortos, hoja que vuelve cerrada, dentro de la
015. Independiente de las demás historias en código; se hace la última porque sus dos hallazgos salieron
al cerrar las otras cinco.

### Documentación

- [X] T040 [US6] Enmendar la documentación de la 015: `spec.md` (US6, FR-025 a FR-028, dos edge cases, SC-011 y SC-012, el bloque «Requisitos de features anteriores» —FR-039 se amplía, FR-045 se mantiene— y la última asunción), `research.md` (D-710, D-711), `contracts/internal-contracts.md` (§2.3, §2.4, §6.4), `quickstart.md` (§4 pasos 8 y 9) y `plan.md` (Summary y árbol)

### Pruebas de regresión, primero

- [X] T041 [US6] Añadir a `app/src/androidTest/java/com/jrblanco/boccantabria/ui/search/SearchContentTest.kt`: `every_chip_and_the_clear_all_action_are_displayed_with_four_filters` (estado con fechas 7→7, sección «7», subsección «7.3» y organismo; `assertIsDisplayed()` sobre las cuatro `searchChipTag(...)` y `TAG_SEARCH_CHIPS_CLEAR_ALL`) y `the_filter_sheet_does_not_come_back_open_after_the_process_dies` (`StateRestorationTester(composeRule)`, pulsar `TAG_SEARCH_FILTERS_OPEN`, afirmar `TAG_SEARCH_FILTERS_SHEET`, `emulateSavedInstanceStateRestore()`, afirmar que la hoja no existe y el chip de sección sí). Ejecutar la clase con `-Pandroid.testInstrumentationRunnerArguments.class=com.jrblanco.boccantabria.ui.search.SearchContentTest` y **confirmar que las dos fallan**

### Implementación

- [X] T042 [US6] En `app/src/main/java/com/jrblanco/boccantabria/ui/search/SearchScreen.kt:150`, `rememberSaveable` → `remember`, con un comentario de dos líneas (convención de la casa; el borrador tampoco se guarda; los filtros viven en el ViewModel); retirar el import de `rememberSaveable`, que queda sin uso (research D-711)
- [X] T043 [US6] En `app/src/main/java/com/jrblanco/boccantabria/ui/search/component/ActiveFilterChips.kt`: sustituir el `Row` + `horizontalScroll` por `FlowRow(modifier.fillMaxWidth().padding(horizontal = screenMargin).testTag(TAG_SEARCH_CHIPS), horizontalArrangement = spacedBy(space2), verticalArrangement = spacedBy(space1))` siguiendo `KeywordChipsInput.kt:94-97`; alinear chip y botón (`itemVerticalAlignment = Alignment.CenterVertically` si compila con este BOM; si no, un `Box` de la altura del chip alrededor del botón); etiquetas de sección y subsección con `shortName`; retirar los imports de `horizontalScroll`, `Row` y `rememberScrollState`; KDoc con el porqué de la `FlowRow` (el argumento de `PageChip.kt:83`) y del nombre corto (research D-710)
- [X] T044 [US6] En `SearchContentTest.kt:213`, `"Sección: Subvenciones y ayudas"` → `"Sección: Subvenciones"`; ejecutar la clase: las dos regresiones y el resto en verde
- [X] T045 [US6] Añadir al párrafo de la 015 en `CLAUDE.md` una frase: la fila de etiquetas envuelve en vez de desplazarse y usa el nombre corto, y la hoja de filtros no se restaura abierta porque abierto/cerrado va con `remember` en toda la app
- [X] T046 Repetir las cuatro puertas (`assembleDebug`, `testDebugUnitTest`, `connectedDebugAndroidTest`, `lintDebug`), el recorrido manual de `quickstart.md` §4 pasos 8 y 9, y añadir una segunda entrada al «Cierre» de este fichero

**Checkpoint**: las seis historias completas.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (fase 1)**: sin dependencias.
- **Foundational (fase 2)**: vacía a propósito. No bloquea nada.
- **US1 (fase 3)**: depende solo de la fase 1.
- **US2 (fase 4)** y **US4 (fase 6)**: dependen de US1 (T004, la línea de `isRunnable`).
- **US3 (fase 5)**: depende solo de la fase 1 en código; T019 requiere US1 para ser significativa.
- **US5 (fase 7)**: depende solo de la fase 1.
- **US6 (fase 9)**: depende solo de la fase 1 en código; toca `ActiveFilterChips.kt`, `SearchScreen.kt`
  y `SearchContentTest.kt`, que ninguna otra historia toca salvo US5 (una aserción en la misma clase).
- **Polish (fase 8)**: depende de las historias que se quieran entregar.

### Dependencias entre historias

| Historia | Ficheros de producto | Ficheros de prueba | Depende de |
|---|---|---|---|
| US1 | `SearchQuery.kt`, `SearchPublicationsUseCase.kt` (KDoc) | `SearchQueryTest`, `SearchPublicationsUseCaseTest`, `SearchRepositoryImplTest`, `PublicationSearchDaoTest`, `LikePatternTest` (KDoc), `SearchViewModelTest`, `SearchFlowIntegrationTest` | — |
| US2 | ninguno | `SearchQueryTest`, `SearchViewModelTest`, `SearchFlowIntegrationTest` | US1 |
| US3 | `SearchViewModel.kt` | `SearchViewModelTest` | — (T019: US1) |
| US4 | ninguno | `SearchViewModelTest` | US1 |
| US5 | `strings.xml`, `SearchUiState.kt` (KDoc) | `SearchContentTest` | — |

**El único acoplamiento de ficheros es `SearchViewModelTest.kt`**, que tocan US1, US2, US3 y US4. Si
las hace una sola persona, van seguidas en el orden de las fases y no hay conflicto. Si van en paralelo,
US3 y US1 tocan secciones distintas de la clase (telemetría frente a filtros) y se resuelven a mano.

### Dentro de cada historia

**Prueba de regresión antes que código** donde se corrige algo que hoy ocurre (T003 en US1, T018 y
T019 en US3): se escribe, se ve fallar, se cambia el código, se ve pasar. El resto de pruebas, después
de la implementación. Dentro de la implementación: dominio → modelo de pantalla → recursos.

### Parallel Opportunities

- **US1, US3 y US5 pueden arrancar a la vez** tras la fase 1: dominio, modelo de pantalla y cadena
  son ficheros distintos.
- Dentro de US1, T007-T010 son cuatro clases de prueba distintas: en paralelo.
- Dentro de US2, T014-T016 son tres clases distintas: en paralelo.
- T029 y T030 (US5) son dos ficheros distintos: en paralelo.
- T033 (`CLAUDE.md`) puede escribirse en cualquier momento tras US3, que es la última que decide algo
  que la guía tiene que contar.

---

## Parallel Example: reparto entre dos

```text
Persona A: US1 → US2 → US4     (la regla y sus consecuencias; todo pasa por isRunnable)
Persona B: US3 → US5           (el destello y la cadena; ninguno toca dominio)
```

Y después, quien termine primero, la fase 8.

---

## Implementation Strategy

### MVP (US1 sola)

1. Fase 1 (T001-T002).
2. Fase 3 (T003-T013).
3. **Parar y validar**: aplicar una sección sin texto muestra la lista. Es la petición literal del
   propietario, cerrada.

### Entrega incremental

1. Fase 1 → línea base.
2. US1 → los filtros buscan solos → demostrable. **La petición del propietario está cerrada.**
3. US2 → el texto acota lo filtrado → demostrable.
4. US3 → sin destello y con analítica veraz → demostrable con logcat.
5. US4 → restaurar relanza → demostrable matando el proceso.
6. US5 → el estado inicial dice las dos vías → demostrable.
7. Fase 8 → `CLAUDE.md`, no-regresión, las cuatro puertas y el recorrido manual.

---

## Notes

- **Ni una consulta, ni una migración, ni una dependencia, ni una pantalla.** Si en la implementación
  aparece la necesidad de tocar `data/` (producto), `app/schemas/`, `gradle/libs.versions.toml`,
  `SearchScreen.kt` o Koin, hay que parar: o es un error de ejecución, o la especificación se quedó
  corta y hay que ampliarla antes de seguir.
- **Prohibido `@Ignore`.** Las tres pruebas que se renombran (T007, T008, T011) conservan sus
  aserciones íntegras: siguen siendo ciertas sin filtros. Ninguna otra se toca salvo para añadir.
- **`combine` sigue con cinco flujos.** Si alguien se ve tentado de añadir `results` y otro flujo por
  separado, recuerde la sobrecarga `vararg` que `CLAUDE.md` documenta.
- **La huella de telemetría no se escribe en ningún sitio.** Ni a `CrashReporter.log`, ni al
  `SavedStateHandle`, ni a un parámetro: es un `SearchQuery` y su `toString()` lleva el texto.
- Un commit por tarea o por grupo lógico, en español, imperativo, con prefijo Conventional Commits,
  **cuando el propietario lo pida**. La rama `015-buscar-solo-filtros` se conserva tras el merge.
- Se puede parar en cualquier checkpoint y validar la historia sola.

---

## Cierre — 9 de septiembre de 2026

**Las cuatro puertas en verde**, con un solo dispositivo (`emulator-5554`, API 37, navegación de tres
botones):

| Puerta | Resultado |
|---|---|
| `assembleDebug` | ✅ |
| `testDebugUnitTest` | ✅ **1.274** pruebas, 0 fallos (163 clases); 128 de ellas de búsqueda, frente a las 110 de la línea base |
| `connectedDebugAndroidTest` | ✅ **229** pruebas, 0 fallos, en 94 s |
| `lintDebug` | ✅ **23** incidencias, todas en `gradle/` y en recursos preexistentes; ninguna en un fichero de esta feature. Son 6 más que las 17 de la 014, y las 6 son `GradleDependency` sobre `libs.versions.toml`, que esta rama no toca (`git diff main` vacío): versiones publicadas después del 6 de septiembre, no incidencias nuevas |

**Las dos regresiones fallaron antes y pasan después**, como exige el principio V: T003 (`applying a
filter with nothing typed searches by the filter alone`) fallaba con `content` en `Initial`; T018
(`a search is reported with the count the store answered`) fallaba con un único evento
`{has_filters=false, results=0}` y ninguno con el recuento real; T019 (`never shows the empty state
before the store answers`) fallaba, con US1 hecha, viendo la secuencia `[Empty, Results]`.

**Recorrido manual de `quickstart.md` §4 hecho sobre el emulador con 1.709 publicaciones
sincronizadas**, conducido con `uiautomator`:

1. Sección «Disposiciones generales» sin texto → etiqueta, **100 resultados**, lista; «No hemos
   encontrado publicaciones» **no apareció en ningún volcado** entre «Aplicar» y la lista.
2. Rango 07/09/2026–07/09/2026 sobre la sección → **1 resultado**, la única fecha visible es el 7.
3. Con la sección puesta, «piscinas» → **1 resultado**; borrar el texto → vuelven los 100 sin pasar por
   el inicial ni el vacío. Con «a» y «al» el recuento se quedó en 100: la sección se llama
   «generales» y su nombre forma parte del texto buscable de las cien filas, así que las dos cadenas
   coinciden con todas. No es un defecto.
4. Quitar la etiqueta de fechas → 100; quitar la de sección → estado inicial, cuyo cuerpo dice
   «…o aplica un filtro…».
5. Sin filtros, «a» → estado inicial; «ab» → **300 resultados** y «Hay más de 300 publicaciones».
6. Rango 06/09/2026–06/09/2026 (domingo) → «No hemos encontrado publicaciones», con las dos etiquetas
   encima.
7. Sección aplicada, Inicio, `am kill`, reabrir → Buscar vuelve con la etiqueta y **100 resultados**
   sin tocar nada.

**Analítica en logcat** (`setprop log.tag.FA VERBOSE`, que hace falta además del de depuración): el
evento de la búsqueda restaurada llegó como `has_filters=true, has_text=false, results=100+`, y el del
rango vacío como `results=0` — un cero **real**, de una respuesta vacía de verdad. Ningún valor con
fecha, organismo ni texto.

**Lo que el recorrido NO puede medir, y por qué.** SC-001 pide menos de un segundo desde «Aplicar»;
cada volcado de `uiautomator` tarda más de un segundo, así que lo único afirmable es que la lista
estaba **en el primer volcado** tras la pulsación. Y SC-005 —cero destellos— tiene la misma
granularidad: un destello de 250 ms se le escapa a `uiautomator`. La guarda real de las dos es
`SearchViewModelTest`: la lectura es local y el `debounce` son 250 ms, y T019 afirma la secuencia de
estados sin `Empty`.

**Dos hallazgos ajenos a esta feature, anotados y no tocados:**

- **Con dos etiquetas activas, «Limpiar todo» queda fuera de pantalla** en la fila desplazable de
  chips, y hay que desplazar para llegar a él. Es comportamiento de la 006, no de esta feature; se
  deja al propietario decidir si la acción debe estar siempre visible.
- **La hoja de filtros abierta sobrevive a la muerte del proceso**: su estado es `rememberSaveable`,
  así que quien muere con la hoja abierta la recupera abierta. Coherente, pero sorprende; también de
  la 006.

### Segunda entrada — 9 de septiembre de 2026, enmienda US6

Tras el primer cierre el propietario decidió arreglar aquí los dos hallazgos (research D-710 y D-711).
**Las cuatro puertas otra vez en verde**, mismo emulador:

| Puerta | Resultado |
|---|---|
| `assembleDebug` | ✅ |
| `testDebugUnitTest` | ✅ **1.274** pruebas, 0 fallos: US6 no toca dominio ni ViewModel |
| `connectedDebugAndroidTest` | ✅ **231** pruebas, 0 fallos, en 95 s (las 229 más las dos regresiones) |
| `lintDebug` | ✅ **23** incidencias, las mismas que en la primera entrada; ninguna en `ActiveFilterChips.kt` ni en `SearchScreen.kt` |

**Las dos regresiones fallaron antes y pasan después.**
`every_chip_and_the_clear_all_action_are_displayed_with_four_filters` fallaba con «The component with
TestTag = 'search_chip_subsection' is not displayed!»: con cuatro filtros, la **tercera** etiqueta ya
estaba recortada fuera del `Row` desplazable, no solo el botón.
`the_filter_sheet_does_not_come_back_open_after_the_process_dies` fallaba con «Did not expect any node
but found '1' node … TestTag = 'search_filters_sheet'»: `rememberSaveable` restauraba la hoja.

**Recorrido manual, pasos 8 y 9 de `quickstart.md` §4**, con 1.709 publicaciones sincronizadas:

8. Fechas 07/09→07/09, sección «Autoridades y personal» y subsección «Nombramientos, ceses y otras
   situaciones» → tres etiquetas en **dos líneas** —«07/09/2026 - 07/09/2026», «Sección: Personal»,
   «Subsección: Nombramientos»— y «Limpiar todo» en la segunda, en `[685,673][886,726]` de 1.080 px de
   ancho: a la vista sin desplazar. 11 resultados. Pulsar «Limpiar todo» → estado inicial (SC-011).
9. Sección aplicada y hoja abierta, Inicio, `am kill`, reabrir → la hoja **no** está («Close sheet» y
   «Drag handle» ausentes del volcado), la etiqueta «Sección: Disposiciones» y los 100 resultados sí
   (SC-012).

Detalle de implementación que conviene saber: `FlowRow` compiló **sin `@OptIn`** con este BOM, y
`Modifier.align(Alignment.CenterVertically)` dentro de su ámbito alinea el chip (32 dp) con el botón de
texto (40 dp) sin envoltorios; no hizo falta `itemVerticalAlignment`.
