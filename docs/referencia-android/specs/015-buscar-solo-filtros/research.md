# Investigación — Feature 015: Buscar con solo filtros

Decisiones D-701 a D-711. Formato: **Decisión / Razón / Alternativas descartadas**.

Esta feature no tiene incógnitas técnicas: no hay biblioteca nueva, ni servicio ajeno, ni dato que
persistir. Lo que se investiga aquí es **dónde poner una regla de una línea** para que no haya dos
verdades, y **cómo cerrar una carrera** que ya existía sin inventar un estado de carga.

---

## D-701 · La regla vive en `SearchQuery.isRunnable`, y en ningún otro sitio

**Decisión.** `isRunnable` pasa de `normalisedText.length >= MIN_TEXT_LENGTH` a
`normalisedText.length >= MIN_TEXT_LENGTH || hasFilters`. `hasFilters` ya existe justo debajo, ya
cuenta los cinco filtros y ya excluye el orden. Ni `SearchPublicationsUseCase` ni
`SearchViewModel.contentFor` cambian de código: los dos leen `isRunnable`.

**Razón.** Hoy hay **tres** lecturas del mismo predicado —el caso de uso decide si va al almacén, el
modelo de pantalla decide si pinta `Initial`, y la telemetría decide si reporta— y las tres coinciden
porque leen la misma propiedad. Cambiar la propiedad es cambiar las tres a la vez. Cualquier otra
opción crea la posibilidad de que una diga «busca» y otra «no has buscado».

**Alternativas descartadas.**

- *Comprobar `hasFilters` en `contentFor`.* La pantalla dejaría de pintar `Initial`, pero el caso de
  uso seguiría devolviendo vacío sin ir al almacén: se pintaría `Empty` con filtros que sí tienen
  coincidencias. Es exactamente la clase de defecto que la propiedad única evita.
- *Comprobar `hasFilters` en el caso de uso.* Iría al almacén, pero `contentFor` seguiría pintando
  `Initial` sobre una lista que sí llegó. Simétrico al anterior.

---

## D-702 · Con un filtro puesto, una letra acota; no hay un segundo «texto»

**Decisión.** El patrón `LIKE` se construye, como hoy, con `normalisedText` entero. Con un filtro
activo y una sola letra, la consulta acota por esa letra. No se añade ninguna propiedad
`searchableText` que ignore el texto corto, y `SearchRepositoryImpl` no se toca.

**Razón.** Es literalmente lo pedido: «el texto concreta». El motivo de D-011 de la 006 era el
volumen —una letra sobre el archivo entero devolvía medio archivo—, y una letra sobre un conjunto ya
filtrado solo lo **reduce**. El mínimo de dos letras conserva su sentido justo donde aplica, la búsqueda
sin filtros. Y una segunda propiedad con nombre parecido sería una trampa: quien construya un patrón o
una huella con `normalisedText` —el nombre obvio— obtendría en silencio otro comportamiento.

**Alternativas descartadas.**

- *`searchableText = if (hasEnoughText) normalisedText else ""`* en dominio, y el repositorio
  construyendo el patrón con ella. Conservaba D-011 al pie de la letra, pero en pantalla teclear «a»
  con una sección puesta dejaba «300 resultados» sin moverse, que se lee como cuelgue, y creaba la
  trampa de nombres de arriba.
- *Hacerlo en el repositorio.* Peor aún: «texto corto cuenta como vacío» es una regla de negocio, y el
  repositorio declara en su KDoc que su trabajo es normalizar y escapar, nada más.

---

## D-703 · El contenido se deriva de la consulta contestada, no de la actual

**Decisión.** El flujo de resultados del `ViewModel` deja de emitir `SearchResults` a secas y emite la
pareja **consulta preguntada + respuesta**:

```kotlin
private data class Answer(val asked: SearchQuery, val found: SearchResults)

private val results: Flow<Answer> = query
    .debounce(DEBOUNCE_MILLIS)
    .flatMapLatest { asked -> searchPublications(asked).map { Answer(asked, it) } }
```

En `combine`, `content = contentFor(answer.asked, answer.found)`; el resto del estado —`query`,
etiquetas, campo— sigue a `current`. `SearchUiState` y `SearchContentState` no cambian de forma.

**Razón.** `combine(query, results, …)` reemite en cuanto cambia **cualquiera** de sus flujos. Al
cambiar `query`, reemite al instante con el `found` **anterior**, y durante los 250 ms del `debounce`
más lo que tarde el almacén, `contentFor(nueva, vieja)` es una mentira: hoy, al pasar de una a dos
letras, `contentFor("ab", EMPTY)` pinta «No hemos encontrado publicaciones» un instante. Con filtros
ejecutables, pulsar «Aplicar» desde `Initial` lo haría **siempre**, porque el `found` anterior es
justamente el `EMPTY` con que se contesta a una consulta no ejecutable. Derivar `content` de la
consulta que de verdad se contestó hace imposible esa combinación: `Empty` solo puede salir de una
respuesta real a esa consulta (FR-014, FR-015). Y como `flatMapLatest` cancela la búsqueda anterior al
llegar la siguiente, una respuesta de una consulta ya sustituida no se emite (FR-016).

Consecuencia que se acepta y se anota: entre que cambia la consulta y llega su respuesta, las
etiquetas ya dicen lo nuevo y la lista aún dice lo viejo. Ya pasaba entre tecla y tecla; ahora también
al quitar la última etiqueta, que deja la lista un cuarto de segundo antes de volver a `Initial`.

**Alternativas descartadas.**

- *Un estado `Loading`.* `SearchUiState` decidió no tenerlo, y con razón: la lectura es local e
  inmediata, no hay espera que amortiguar, y sería una rama más del `when` de la pantalla que
  parpadearía en cada tecla. El problema no es que no se vea que se está buscando; es que se muestra
  una respuesta a otra pregunta.
- *`distinctUntilChanged` o `filter` sobre `results`.* No toca el problema: la reemisión indebida la
  provoca `combine` al cambiar `query`, no `results`.
- *Un `Pair<SearchQuery, SearchResults>`.* Funciona igual; el `data class` privado se lee mejor en el
  `combine` y en las pruebas. Es privado y vive en `ui/search`: la regla de Konsist «toda clase de
  dominio tiene prueba» no lo alcanza, y no es un `ViewModel`.
- *Vaciar `results` al cambiar la consulta.* Volvería a pintar `Initial` entre teclas, que es peor que
  conservar la lista anterior mientras llega la nueva.

---

## D-704 · La telemetría se reporta desde la respuesta, con huella completa y `has_text`

**Decisión.** `reportSearch` deja de ser un `onEach` del estado y pasa a ser un `onEach` del flujo de
respuestas: se dispara **una vez por respuesta del almacén**, con `answer.asked` y
`answer.found.items.size`. La huella de deduplicación pasa de `normalisedText to hasFilters` a la
consulta contestada normalizada y sin orden:

```kotlin
private var lastReported: SearchQuery? = null
val fingerprint = answer.asked.copy(text = answer.asked.normalisedText, sort = SearchSort.DEFAULT)
```

El evento `boc_search` gana un parámetro, `has_text`, booleano. Sigue sin llevar el texto ni ningún
valor de filtro.

**Razón.** Dos defectos a la vez. **Recuento**: hoy el evento se dispara en la primera reemisión del
estado tras cambiar la consulta, que es la que lleva el `found` viejo, y la huella lo marca como ya
reportado, de modo que el recuento real nunca llega: la 006 lleva desde su fusión reportando «0» para
la primera emisión de cada búsqueda (FR-020). Reportar desde la respuesta hace que el recuento sea el
contestado por construcción. **Huella**: `normalisedText to hasFilters` colapsa dos filtros distintos
sin texto en un solo evento (FR-021); la consulta entera los distingue. Se quita el orden de la huella
porque cambiar el orden no es buscar otra cosa, y se normaliza el texto porque «Piélagos» y «pielagos»
son la misma búsqueda. `has_text` es lo único que permite distinguir en el panel las búsquedas por
filtros solos, que son la novedad de esta feature.

La huella es un `SearchQuery`, que es `data class` y cuyo `toString()` lleva texto, fechas y organismo.
**Nunca se serializa**: ni a `CrashReporter.log`, ni al `SavedStateHandle`, ni a un parámetro. Una
prueba fija el vocabulario cerrado del evento —claves `{has_filters, has_text, results}`, valores en
`{true, false, 0, 1-9, 10-99, 100+}`—, que es la forma de comprobar que no se filtra nada sin tener
que adivinar qué palabra buscar.

**Alternativas descartadas.**

- *Seguir reportando desde el estado, pero con `asked`.* Obliga a colar `asked` en el estado o en una
  tupla paralela solo para el efecto, y sigue disparándose en cada reemisión por motivos ajenos
  —guardar un resultado— confiando en la huella. Desde la respuesta es más simple y más honesto.
- *Huella `Triple(texto, filtros, orden)`.* Lo mismo con un tipo peor.
- *Enviar los códigos de sección a analítica.* Un código de sección no es personal, pero FR-019 y la
  regla de la casa se cumplen mejor enviando solo booleanos y tramos; el día que haga falta saber qué
  secciones se filtran, es un evento nuevo con su motivo.

---

## D-705 · El estado inicial dice las dos vías, y el vacío no cambia

**Decisión.** `search_initial_body` pasa de «Escribe al menos dos letras y verás las publicaciones que
coincidan.» a «Escribe al menos dos letras o aplica un filtro y verás las publicaciones que
coincidan.». `search_initial_title`, `search_empty_title` y `search_empty_body` se conservan.

**Razón.** El texto actual afirma algo que deja de ser cierto (FR-012). El del estado vacío —«Prueba
con otras palabras o quita alguno de los filtros»— ya cubre los dos casos y `SearchContentTest`
afirma su segunda mitad por subcadena: cambiarlo costaría 46 segundos de tanda instrumentada para no
ganar nada (FR-013).

**Alternativas descartadas.** «Escribe o filtra para buscar en todo el BOC» —repite el título—.
«Usa el texto o los filtros» —«texto» no es cómo la persona llama al campo—.

---

## D-706 · El tope de 300 se conserva, y con filtros solos se alcanzará casi siempre

**Decisión.** `SearchPublicationsUseCase.MAX_RESULTS = 300` no cambia, ni la lógica de «pedir una fila
más». Se actualiza su KDoc: hoy dice «con filtros, trescientos es de sobra», y con filtros **solos** ya
no lo es; lo que sigue siendo cierto es que el aviso dice cómo acotar.

**Razón.** Es D-017 de la 006: sin paginación, una lista recortada tiene que decirlo. El aviso «Hay
más de 300 publicaciones. Acota la búsqueda para verlas todas» es exactamente la respuesta correcta a
una sección entera. Paginar sería una dependencia nueva y otro modelo de datos para una pantalla.

**Alternativas descartadas.** Subir el tope a 500 o 1000: mueve el problema y carga la lista; si el
propietario lo quiere tras usarlo, es un número con su motivo. Paginación: descartada en la 006.

---

## D-707 · Ni el DAO, ni el patrón, ni el repositorio cambian; se les añade prueba

**Decisión.** `PublicationSearchDao`, `LikePattern.likeContains` y `SearchRepositoryImpl` quedan
intactos. Se añaden pruebas que afirman lo que ahora se **depende** de ellos: sin texto el patrón es
`%%` y coincide con todo; un filtro solo devuelve todas las filas que permite; una fila con
`search_text = ''` —anterior al relleno de la 006— se encuentra por filtros. El KDoc de
`LikePatternTest` que llama al `%%` «el problema del llamador» se reformula: ahora es por diseño.

**Razón.** La consulta ya era correcta con texto vacío; lo que faltaba era que alguien la llamara así.
Una dependencia nueva sobre un comportamiento existente merece una prueba que lo diga en voz alta,
para que quien un día toque `likeContains("")` sepa que hay una pantalla entera detrás.

---

## D-708 · Una aserción instrumentada, ninguna clase nueva

**Decisión.** La única prueba instrumentada que se toca es
`SearchContentTest.before_there_is_anything_to_search_for_the_screen_says_so_without_saying_empty`,
que gana una aserción: el cuerpo del estado inicial contiene «filtro», con
`onNodeWithText(…, substring = true)` sobre el subárbol. No se añade ninguna clase. La restauración con
filtros y sin texto (US4) se afirma en `SearchViewModelTest` construyendo el modelo con un
`SavedStateHandle` que solo lleva `searchSection`; `SearchStateRestoredTest` no se amplía.

**Razón.** Lo único visible que cambia es una cadena; el resto es comportamiento del modelo de
pantalla, que se prueba sin emulador. Cada clase instrumentada cuesta ~46 s en la tanda con
independencia de lo que haga, y `SearchStateRestoredTest` recorre el grafo de navegación real para
comprobar la persistencia del `SavedStateHandle`, que no cambia: lo que cambia es qué hace el modelo
con lo restaurado, y eso es unitario.

---

## D-709 · La 006 no se edita; se referencia. `CLAUDE.md` sí se actualiza

**Decisión.** Los ficheros de `specs/006-buscar/` quedan como están. La spec de la 015 declara qué
requisitos de la 006 quedan acotados, superados o enmendados, con la marca de cada uno, siguiendo el
precedente de la 013. `CLAUDE.md` actualiza el párrafo «Buscar existe desde la feature 006» con dos
frases: los filtros bastan para buscar, y el contenido se deriva de la consulta contestada.

**Razón.** Una especificación es el registro de lo que se decidió **entonces**; reescribirla borra la
historia y hace ilegible el `git blame`. La guía operativa, en cambio, tiene que contar la verdad de
hoy, y su cabecera exige actualizarla en el mismo cambio.

---

## D-710 · Las etiquetas envuelven en una `FlowRow` y usan el nombre corto

**Decisión.** `ActiveFilterChips` deja de ser un `Row` con `horizontalScroll` y pasa a ser una
`FlowRow` que salta de línea, con «Limpiar todo» el último, como hasta ahora. Las etiquetas de sección
y subsección usan `BocSection.shortName` en vez de `name`.

**Razón.** El recorrido manual de esta feature mostró que con dos etiquetas —un rango de fechas y una
sección— «Limpiar todo» ya quedaba fuera de pantalla, y era lo primero que se perdía por ir al final
de una fila desplazable. El documento de diseño (§17) pedía que lo aplicado «quede visible como chips
con su aspa, más Limpiar todo», y una fila que hay que desplazar para descubrir no es visible. Como
mucho hay cinco elementos, así que como mucho dos líneas. `FlowRow` es estable en este BOM y ya se usa
en `PageChip.kt`, `SuggestedQuestions.kt` y `KeywordChipsInput.kt` —esta última es una `FlowRow` de
`InputChip` con aspa, el mismo vocabulario—; el KDoc de `PageChip` ya explica por qué una `Row` no
sirve para chips que no caben. Y `shortName` está documentado en el modelo «para los chips de filtro,
donde el nombre oficial no cabe»: los chips de Inicio ya lo usan, y aquí recorta «Sección:
Disposiciones generales» a «Sección: Disposiciones».

**Alternativas descartadas.**

- *Anclar «Limpiar todo» fuera del desplazamiento, a la derecha.* Siempre visible, sin altura extra,
  pero las etiquetas largas seguían recortadas y había que desplazar para leer qué filtros hay puestos.
  El propietario prefirió verlo todo.
- *Poner «Limpiar todo» el primero*, que es el patrón de los chips de Inicio («Boletín de hoy» va fijo
  al principio). Resuelve el botón, no las etiquetas, y se lee raro: la acción de quitar antes de lo
  que quita.
- *Solo el nombre corto.* Alivia el caso habitual y con fechas, sección y organismo sigue desbordando.

---

## D-711 · La hoja de filtros no se restaura abierta

**Decisión.** `filtersOpen` en `SearchContent` pasa de `rememberSaveable` a `remember`.

**Razón.** Es la convención de toda la aplicación para lo que está abierto o cerrado: el panel lateral
(`rememberDrawerState`, sin saver), los menús de las tarjetas de avisos, los diálogos de permisos y los
desplegables usan `remember`; `rememberSaveable` se reserva para contenido escrito por la persona y
para la posición de lectura del visor. `filtersOpen` era la única excepción, y además incoherente con
su propio hijo: el borrador de la hoja es `remember(query)`, así que tras la muerte del proceso la hoja
volvía **abierta pero vacía de cambios** —el contenedor sobrevivía y el contenido no—. FR-045 de la 006
no lo pierde: la consulta y los filtros los guarda el `SavedStateHandle` del ViewModel, y las etiquetas
y la lista vuelven igual que antes.

**Alternativas descartadas.** *Restaurar la hoja entera*, guardando también el borrador (hace falta un
`Saver` para una consulta con fechas), el calendario abierto y el desplegable abierto: más código para
un caso raro y para conservar algo que ninguna otra pantalla conserva.
