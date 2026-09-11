# Contratos internos — Feature 015

Lo que cambia de firma o de garantía, y lo que se conserva. Rutas relativas a
`app/src/main/java/com/jrblanco/boccantabria/`.

---

## 1. Dominio

### 1.1. `domain/model/SearchQuery.kt`

```kotlin
data class SearchQuery(
    val text: String = "",
    val from: LocalDate? = null,
    val to: LocalDate? = null,
    val sectionCode: String? = null,
    val subsectionCode: String? = null,
    val issuer: String? = null,
    val sort: SearchSort = SearchSort.DEFAULT,
) {
    val normalisedText: String                 // sin cambio
    /** Cierto con dos caracteres normalizados O con algún filtro activo (D-701). El orden no cuenta. */
    val isRunnable: Boolean                    // ← definición nueva
    val activeFilterCount: Int                 // sin cambio
    val hasFilters: Boolean                    // sin cambio
    val hasInvalidDateRange: Boolean           // sin cambio
    fun clearedFilters(): SearchQuery          // sin cambio
    fun withoutDateRange() / withoutSection() / withoutSubsection() / withoutIssuer()   // sin cambio
    fun withSection(code: String?): SearchQuery                                         // sin cambio
    companion object { const val MIN_TEXT_LENGTH: Int = 2 }                              // sin cambio
}
```

| Garantía | Antes | Después |
|---|---|---|
| `SearchQuery(text = "a").isRunnable` | false | **false** (sin cambio) |
| `SearchQuery(text = "ab").isRunnable` | true | true |
| `SearchQuery(sectionCode = "1").isRunnable` | false | **true** |
| `SearchQuery(from = d).isRunnable`, `(to = d)`, `(subsectionCode = "2.1")`, `(issuer = x)` | false | **true** |
| `SearchQuery(text = "a", sectionCode = "1").isRunnable` | false | **true**; el patrón lleva la «a» |
| `SearchQuery(sort = OLDEST_FIRST).isRunnable` | false | **false** |
| `SearchQuery(sectionCode = "1").clearedFilters().isRunnable` | false | false |

**KDoc a reescribir** (`SearchQuery.kt:30-36`): «una letra sola sigue sin ir al archivo; un filtro sí,
porque ya acota; y sobre un filtro una letra solo reduce».

### 1.2. `domain/usecase/SearchPublicationsUseCase.kt` — sin cambio de código

| Garantía | Detalle |
|---|---|
| Con `!query.isRunnable` no llama al repositorio y devuelve `flowOf(SearchResults.EMPTY)` | sin cambio; **ahora una consulta con filtros y sin texto sí llama** |
| Pide `MAX_RESULTS + 1`; entrega como mucho `MAX_RESULTS` y marca `isTruncated` | sin cambio; con filtros solos `isTruncated` será lo habitual |

**KDoc a reescribir**: `:18-19` («A query with nothing to search for never reaches the store» → «…with
neither enough text nor a filter…») y `:39` («With filters, three hundred is plenty» → con filtros
solos se supera a menudo y la pantalla lo dice; la salida sigue siendo acotar).

---

## 2. Presentación

### 2.1. `ui/search/SearchViewModel.kt`

Eventos públicos: **sin cambio**. `onQueryChanged`, `onClearQuery`, `onSortChanged`,
`onFiltersApplied`, `onClearFilters`, `onRemoveDateRange/Section/Subsection/Issuer`, `onToggleSaved`,
`onSaveFailureConsumed`, `onShare`, `onShareConsumed`.

Constantes públicas: **sin cambio**. `SCREEN_NAME`, `EVENT_SEARCH`, `KEY_*`, `DEBOUNCE_MILLIS`.

Internos que cambian:

```kotlin
/** La consulta que se envió y lo que contestó. Privado del fichero; nunca sale del modelo. */
private data class Answer(val asked: SearchQuery, val found: SearchResults)

private var lastReported: SearchQuery? = null          // antes Pair<String, Boolean>?

private val results: Flow<Answer> = query
    .debounce(DEBOUNCE_MILLIS)
    .flatMapLatest { asked -> searchPublications(asked).map { Answer(asked, it) } }
    .onEach(::reportSearch)                            // el efecto se muda aquí (D-704)

val uiState: StateFlow<SearchUiState> = combine(query, results, issuers, saved, shareState) {
    current, answer, issuers, (savedKeys, failed), share ->
    SearchUiState(
        query = current,                                // el campo y las etiquetas siguen a la consulta viva
        content = contentFor(answer.asked, answer.found), // el contenido, a la consulta contestada (D-703)
        …
    )
}.stateIn(…, initialValue = SearchUiState(query = query.value))

private fun contentFor(asked: SearchQuery, found: SearchResults): SearchContentState  // sin cambio de cuerpo

private fun reportSearch(answer: Answer) {
    if (!answer.asked.isRunnable) return
    val fingerprint = answer.asked.copy(text = answer.asked.normalisedText, sort = SearchSort.DEFAULT)
    if (fingerprint == lastReported) return
    lastReported = fingerprint
    analytics.track(AnalyticsEvent(EVENT_SEARCH, mapOf(
        "has_filters" to answer.asked.hasFilters.toString(),
        "has_text"    to answer.asked.normalisedText.isNotEmpty().toString(),
        "results"     to bucketOf(answer.found.items.size),
    )))
}
```

| Garantía | Detalle |
|---|---|
| `content` nunca combina una consulta nueva con una respuesta vieja | `content` sale de `answer`, cuya `asked` es la consulta a la que `found` responde |
| `Empty` solo aparece como destino de una respuesta real | consecuencia de lo anterior; FR-014, FR-015 |
| Una respuesta a una consulta ya sustituida no se muestra ni se reporta | `flatMapLatest` cancela la anterior; FR-016 |
| Hasta la primera respuesta, `content` es `Initial` | `initialValue` del `stateIn`; `combine` no emite hasta que `results` emite |
| Entre cambio de consulta y respuesta, la pantalla mantiene lo que mostraba | 250 ms de `debounce` + lectura; se anota en el recorrido manual |
| El evento se dispara una vez por respuesta, deduplicado | `onEach` sobre `results` + huella; una reemisión de Room con la misma consulta no reporta dos veces |
| `lastReported` es solo memoria | nunca a `CrashReporter`, `SavedStateHandle` ni parámetro; `SearchQuery.toString()` llevaría el texto |
| `combine` sigue con **cinco** flujos | no se cae en la sobrecarga `vararg` documentada en `CLAUDE.md` |

**KDoc a reescribir**: `:71-77` (`lastReported` «is the normalised text» → es la consulta contestada
normalizada, y por qué no se escribe), `:81-83` («The floor of two characters lives in the use case»
→ el suelo y la excepción de los filtros viven en `SearchQuery`), `:102-104` (el comentario del
`onEach` sobre el estado se muda al `onEach` sobre las respuestas y dice por qué ahí).

### 2.2. `ui/search/SearchUiState.kt` — sin cambio de forma

**KDoc a reescribir** (`:35`): `Initial` — «Ni texto suficiente ni filtros, o el almacén aún no ha
contestado nada. Neither an empty result nor a failure».

### 2.3. `ui/search/component/ActiveFilterChips.kt` — US6 (D-710)

Firma pública **sin cambio**. Cambian el layout y dos etiquetas:

| | Antes | Después |
|---|---|---|
| Contenedor | `Row` + `horizontalScroll(rememberScrollState())` | `FlowRow` con `horizontalArrangement = spacedBy(space2)`, `verticalArrangement = spacedBy(space1)`; el `TAG_SEARCH_CHIPS`, el `fillMaxWidth()` y el `padding(horizontal = screenMargin)` se conservan en el contenedor |
| Orden | fechas → sección → subsección → organismo → «Limpiar todo» | igual |
| Etiqueta de sección | `"Sección: " + name` («Sección: Disposiciones generales») | `"Sección: " + shortName` («Sección: Disposiciones»); `code` si el catálogo no lo tiene |
| Etiqueta de subsección | `"Subsección: " + name` | `"Subsección: " + shortName` |
| Etiqueta de fechas, organismo | `dd/MM/yyyy - dd/MM/yyyy`, `"Organismo: " + issuer` | sin cambio |
| Descripción accesible del aspa | `search_filter_remove` con la etiqueta | igual; cambia con la etiqueta |

Etiquetas de prueba **sin cambio**: `TAG_SEARCH_CHIPS`, `TAG_SEARCH_CHIPS_CLEAR_ALL`, `searchChipTag(kind)`.

### 2.4. `ui/search/SearchScreen.kt` — `SearchContent.filtersOpen` — US6 (D-711)

```kotlin
// Antes
var filtersOpen by rememberSaveable { mutableStateOf(false) }
// Después
var filtersOpen by remember { mutableStateOf(false) }
```

| Garantía | Detalle |
|---|---|
| Tras la muerte del proceso la hoja no se compone | `remember` no sobrevive; `SearchFiltersSheet` solo se monta con `filtersOpen == true` |
| Los filtros aplicados sí vuelven | los guarda `SearchViewModel.persist()` en el `SavedStateHandle`; ni las etiquetas ni la lista dependen de esta bandera |
| El botón de la barra sigue abriendo la hoja | `TAG_SEARCH_FILTERS_OPEN` → `filtersOpen = true`, sin cambio |

Resto de etiquetas de prueba, todas **sin cambio**: `TAG_SEARCH_SCREEN`, `TAG_SEARCH_RESULTS`,
`TAG_SEARCH_INITIAL`, `TAG_SEARCH_EMPTY`, `TAG_SEARCH_COUNT`, `TAG_SEARCH_TRUNCATED`,
`TAG_SEARCH_FILTERS_OPEN`, `TAG_SEARCH_TITLE`, las de la hoja.

---

## 3. Datos — sin cambio, con prueba nueva

### 3.1. `data/source/local/PublicationSearchDao.kt`

Las dos `@Query` **intactas**. Garantía que ahora se declara y se prueba: con `pattern = '%%'` y un
filtro no nulo, devuelve **todas** las filas que el filtro permite, incluidas las que tienen
`search_text = ''`.

### 3.2. `data/source/local/LikePattern.kt`

`likeContains("") == "%%"` **intacto**. El KDoc de su prueba (`LikePatternTest.kt:42`) deja de
llamarlo «el problema del llamador»: ahora es la forma en que una búsqueda por filtros solos pide todo.

### 3.3. `data/repository/SearchRepositoryImpl.kt`

**Intacto**. Garantía que ahora se prueba: con texto vacío el patrón que llega al DAO es `%%` y los
cinco filtros viajan tal cual.

---

## 4. Telemetría — el evento `boc_search`

| Clave | Valores admitidos | Origen |
|---|---|---|
| `has_filters` | `true` \| `false` | `asked.hasFilters` |
| `has_text` | `true` \| `false` | `asked.normalisedText.isNotEmpty()` ← nuevo |
| `results` | `0` \| `1-9` \| `10-99` \| `100+` | `bucketOf(found.items.size)` |

**Ninguna otra clave.** Una prueba afirma `keys == setOf("has_filters", "has_text", "results")` y que
todos los valores están en el conjunto cerrado; otra, que ni el organismo ni una fecha ISO aparecen en
ningún valor.

---

## 5. Cadenas

| Clave | Antes | Después |
|---|---|---|
| `search_initial_body` | Escribe al menos dos letras y verás las publicaciones que coincidan. | Escribe al menos dos letras o aplica un filtro y verás las publicaciones que coincidan. |

---

## 6. Pruebas — qué se renombra, qué nace

### 6.1. Existentes que cambian de nombre, no de aserción

| Fichero | Nombre actual | Nombre nuevo |
|---|---|---|
| `domain/model/SearchQueryTest.kt:24` | `one character is not enough to go to the archive with` | `without a filter, one character is not enough to go to the archive with` |
| `domain/usecase/SearchPublicationsUseCaseTest.kt:19` | `a query too short never reaches the store` | `a short query with no filters never reaches the store` |
| `ui/search/SearchViewModelTest.kt:59` | `a single character never reaches the store` | `a single character with no filters never reaches the store` |

Sin cambio: `SearchQueryTest` :30, :36, :42; `SearchPublicationsUseCaseTest` :27;
`SearchViewModelTest` :50, :139 y las de filtros; `SearchFlowIntegrationTest` :155;
`FakeSearchRepository`; todas las instrumentadas salvo la aserción de §6.3.

### 6.2. Nuevas, unitarias (`app/src/test`)

| Fichero | Prueba | Qué afirma |
|---|---|---|
| `SearchQueryTest` | `a filter alone is enough to go to the archive with` | una aserción por filtro: desde, hasta, sección, subsección, organismo |
| | `the order alone is not a filter and runs nothing` | `SearchQuery(sort = OLDEST_FIRST).isRunnable == false` |
| | `with a filter on, a single character is runnable and keeps its text` | `isRunnable` y `normalisedText == "a"` |
| | `clearing the last filter with nothing typed leaves nothing to run` | `clearedFilters().isRunnable == false` |
| `SearchPublicationsUseCaseTest` | `filters alone reach the store, with the same cap` | `queries.single().sectionCode == "1"`, `limits.single() == 301` |
| | `the order alone never reaches the store` | `queries.isEmpty()` |
| `SearchRepositoryImplTest` | `with nothing typed the pattern matches everything` | patrón `%%`, filtros reenviados |
| `PublicationSearchDaoTest` | `with no text, a filter brings back every row it allows` | tres filas de la sección 1 y una de la 2 → tres claves |
| | `a row whose searchable text was never filled in is still found by a filter` | `searchText = ""` → aparece con `%%` y filtro |
| `SearchViewModelTest` | `applying a filter with nothing typed searches by the filter alone` | **regresión: falla hoy**; `Results` y `queries.last().sectionCode` |
| | `clearing the text with a filter on keeps the filtered results` | `Results` tras `onClearQuery()` |
| | `removing the last filter with nothing typed goes back to the initial state` | `Initial` tras `onRemoveSection()` |
| | `changing the order with nothing typed and no filters searches nothing` | `Initial`, `queries.isEmpty()` |
| | `a model rebuilt from saved state with filters and no text searches at once` | `SavedStateHandle(mapOf(KEY_SECTION to "1"))` → `Results` |
| | `applying a filter never shows the empty state before the store answers` | con `awaitItem()` en bucle: ningún `Empty` entre `Initial` y `Results` |
| | `a search is reported with the count the store answered, not the stale one` | **regresión: falla hoy**; `advanceUntilIdle()` **antes** de escribir; `results == "1-9"` |
| | `the same answer arriving twice is reported once` | dos `emit` iguales del fake → un evento |
| | `two different filter sets with no text are reported twice` | sección 1 y luego sección 2 → dos eventos |
| | `every parameter of the search event comes from a closed vocabulary` | claves y valores exactos (§4) |
| | `what a filter says never reaches telemetry either` | ni el organismo ni `2026-` en ningún valor |
| `SearchFlowIntegrationTest` | `a section chosen with nothing typed brings back everything filed under it` | fixture real, sección «1» |
| | `a date range with nothing typed brings back what was published in it` | `from = to = 2026-08-27` |
| | `a range nothing falls in is an empty state, never an error` | `Empty` |
| | `clearing the text but not the filter keeps the results` | `Results` |

### 6.3. Instrumentada (`app/src/androidTest`)

`ui/search/SearchContentTest.before_there_is_anything_to_search_for_the_screen_says_so_without_saying_empty`
gana una aserción: `composeRule.onNodeWithText("aplica un filtro", substring = true).assertIsDisplayed()`.
Sobre el nodo de texto, **no** sobre el volcado de semántica (trampa documentada en `CLAUDE.md`).

### 6.4. Instrumentadas de US6 (`SearchContentTest`)

| Prueba | Qué afirma | Antes del cambio |
|---|---|---|
| `every_chip_and_the_clear_all_action_are_displayed_with_four_filters` | con fechas, sección «7», subsección «7.3» y organismo, las cuatro `searchChipTag(...)` y `TAG_SEARCH_CHIPS_CLEAR_ALL` pasan `assertIsDisplayed()` | **falla**: en el `Row` desplazable el botón queda fuera del viewport y recortado, y `assertIsDisplayed()` lo ve como no mostrado |
| `the_filter_sheet_does_not_come_back_open_after_the_process_dies` | con `StateRestorationTester`: abrir la hoja, `emulateSavedInstanceStateRestore()`, la hoja **no existe** y el chip de sección sigue | **falla**: `rememberSaveable` restaura `true` y la hoja vuelve |
| `each_applied_filter_shows_up_as_a_chip_that_names_it` (:213) | `"Sección: Subvenciones"` en vez de `"Sección: Subvenciones y ayudas"` | ajuste por FR-026 |

---

## 7. Documentación que se toca

| Fichero | Qué |
|---|---|
| `CLAUDE.md`, párrafo «Buscar existe desde la feature 006» | añade: los filtros bastan para buscar (015), con filtro una letra acota, y el contenido se deriva de la consulta contestada para que `Empty` nunca salga de una respuesta vieja |
| `specs/006-buscar/*` | **no se edita** (D-709) |
