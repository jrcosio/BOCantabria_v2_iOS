# Modelo de datos — Feature 015

**Esta feature no toca datos.** Ni una entidad, ni una columna, ni una migración, ni una consulta. Room
se queda en la versión 6 y `app/schemas/` no gana ningún fichero. Lo que sigue describe **una regla de
dominio** que cambia de definición, **un tipo privado** del modelo de pantalla, **la forma de un evento**
de analítica, y —con el mismo detalle— lo que **no** cambia, porque en esta feature esa lista es casi todo
el diseño.

---

## 1. Lo que NO cambia

Se enumera a propósito: cualquier cambio aquí sería un defecto introducido por esta feature.

| Elemento | Estado |
|---|---|
| `PublicationSearchDao.searchNewestFirst()` / `searchOldestFirst()` — las dos `@Query` | **intactas** |
| `LikePattern.likeContains()` — `likeContains("")` devuelve `%%` | **intacta**, ahora con prueba que lo declara por diseño |
| `SearchRepositoryImpl.search()` — construye el patrón con `normalisedText` | **intacto** |
| `SearchQuery` — campos, `normalisedText`, `activeFilterCount`, `hasFilters`, `withSection()`, `clearedFilters()`… | **intactos**; solo cambia la definición de `isRunnable` (§2) |
| `SearchQuery.MIN_TEXT_LENGTH = 2` | **intacta** |
| `SearchResults`, `SearchSort` | **intactos** |
| `SearchPublicationsUseCase` — `if (!query.isRunnable) return flowOf(EMPTY)`, `MAX_RESULTS = 300`, «una fila más» | **intacto** en código; KDoc actualizado |
| `GetSearchIssuersUseCase`, `FilterPublicationsUseCase` | **intactos** |
| `SearchUiState`, `SearchContentState` (`Initial` / `Results` / `Empty`) | **intactos** en forma; KDoc de `Initial` actualizado |
| `SearchViewModel` — eventos públicos, `persist()`, `restoreQuery()`, claves del `SavedStateHandle`, `DEBOUNCE_MILLIS`, `contentFor()` | **intactos** |
| `SearchScreen`, `SearchField`, `SearchFiltersSheet`, `ActiveFilterChips`, `SortSelector` y sus etiquetas de prueba | **intactos** |
| `Route.Search(query)` y el puente desde Inicio | **intactos** |
| Los módulos de Koin | **intactos** |
| El catálogo de versiones de Gradle | **intacto** |
| `search_initial_title`, `search_empty_title`, `search_empty_body`, `search_truncated`, `search_result_count` | **intactas** |

---

## 2. `SearchQuery.isRunnable` — la regla, antes y después

```kotlin
// Antes (006)
val isRunnable: Boolean get() = normalisedText.length >= MIN_TEXT_LENGTH

// Después (015)
val isRunnable: Boolean get() = normalisedText.length >= MIN_TEXT_LENGTH || hasFilters
```

`hasFilters` ya existe: `activeFilterCount > 0`, donde el recuento mira `from != null || to != null`,
`sectionCode != null`, `subsectionCode != null` e `issuer != null`. **El orden no entra**, así que
FR-004 se cumple por la definición que ya había.

### Tabla de verdad

| Texto normalizado | Algún filtro | Orden | `isRunnable` | Contenido tras la respuesta |
|---|---|---|---|---|
| `""` | no | cualquiera | **false** | `Initial` |
| `"a"` (1 carácter) | no | cualquiera | **false** | `Initial` |
| `"ab"` (≥ 2) | no | cualquiera | true | `Results` o `Empty` |
| `""` | **sí** | cualquiera | **true** ← nuevo | `Results` o `Empty` |
| `"a"` | **sí** | cualquiera | **true** ← nuevo | `Results` o `Empty`, acotado por la letra |
| `"ab"` | sí | cualquiera | true | `Results` o `Empty` |
| `"   "` (solo espacios) | no | cualquiera | false | `Initial` (normaliza a `""`) |
| `"   "` | sí | cualquiera | true | como `""` con filtro |

Lo que viaja al almacén cuando `isRunnable` es cierto: `likeContains(normalisedText)` —`%%` si el
texto está vacío—, los cinco filtros tal cual (`null` = no recorta), el orden y `MAX_RESULTS + 1`.

---

## 3. `Answer` — un tipo privado del modelo de pantalla

```kotlin
// ui/search/SearchViewModel.kt, privado del fichero
private data class Answer(
    val asked: SearchQuery,     // la consulta que se envió al caso de uso
    val found: SearchResults,   // lo que contestó
)
```

Envuelve dos tipos de dominio que ya existen. Es lo que emite el flujo de resultados y lo que
`combine` usa para calcular `content`. **No sale del fichero**: no está en `SearchUiState`, no se
persiste, no se registra. Al ser privado y vivir en `ui/search`, la regla de Konsist «toda clase de
dominio de nivel superior tiene su prueba» no lo alcanza, y no es un `ViewModel`.

### De dónde sale cada campo del estado

| Campo de `SearchUiState` | Se deriva de |
|---|---|
| `query` (campo de texto, etiquetas, orden del selector) | `current` — la consulta viva |
| `content` | `contentFor(answer.asked, answer.found)` — la consulta **contestada** |
| `issuers`, `share`, `savedKeys`, `saveFailed` | sus flujos, sin cambio |

Entre que `current` cambia y `answer` lo alcanza —250 ms de `debounce` más la lectura— el campo y las
etiquetas ya muestran lo nuevo y el contenido muestra lo último contestado. Nunca una combinación de
consulta nueva con respuesta vieja.

### Transiciones de `content`

```
Initial ──(filtro aplicado, almacén responde con filas)──▶ Results
Initial ──(filtro aplicado, almacén responde vacío)──────▶ Empty
Results ──(texto añadido, responde con menos filas)──────▶ Results
Results ──(texto borrado con filtro, responde)───────────▶ Results   (la lista del filtro)
Results ──(última etiqueta quitada sin texto, responde)──▶ Initial
Results ──(otro filtro, aún sin respuesta)───────────────▶ Results   (la lista anterior, FR-014)
Empty   ──(filtro cambiado, aún sin respuesta)───────────▶ Empty     (lo que había; nunca Empty «nuevo» sin respuesta)
```

`Empty` solo aparece como **destino de una respuesta real**. Es la propiedad que la feature añade.

---

## 4. El evento `boc_search` — forma antes y después

| | Antes (006, D-021) | Después (015, D-704) |
|---|---|---|
| Cuándo se dispara | en cada reemisión del estado, deduplicado por huella | en cada **respuesta del almacén**, deduplicado por huella |
| Huella de deduplicación | `Pair(normalisedText, hasFilters)` | `asked.copy(text = normalisedText, sort = DEFAULT)` — un `SearchQuery` en memoria |
| `has_filters` | `"true"` / `"false"` | igual |
| `has_text` | — | `"true"` / `"false"` ← nuevo (`normalisedText.isNotEmpty()`) |
| `results` | `"0"`, `"1-9"`, `"10-99"`, `"100+"` | igual, pero del recuento **contestado** |

**Vocabulario cerrado**, que una prueba fija: claves exactamente `{has_filters, has_text, results}`;
valores en `{true, false, 0, 1-9, 10-99, 100+}`. Ningún texto, ninguna fecha ISO, ningún nombre de
organismo, ningún código de sección.

---

## 5. Cadenas

| Clave | Antes | Después |
|---|---|---|
| `search_initial_body` | Escribe al menos dos letras y verás las publicaciones que coincidan. | Escribe al menos dos letras **o aplica un filtro** y verás las publicaciones que coincidan. |

Ninguna otra cadena cambia ni se añade.
