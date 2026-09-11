# Modelo de datos: boletín del día

Once tipos nuevos de dominio, dos registros de datos, dos tablas y dos estados de pantalla. La
premisa es la de siempre, y aquí se nota más que en ninguna feature anterior: **tres vocabularios que
no se mezclan** —lo que llega por la red, lo que se guarda y lo que el negocio entiende—, y entre
ellos traducción real, no copia de campos.

```text
19 fuentes oficiales
      │  GET
      ▼
RssChannelDTO / RssItemDTO          todo anulable: refleja lo que llega, no lo que debería llegar
      │  BocRssParser (SAX, @concurrent)
      ▼
PublicationNormalizer  +  BocFeedCatalog        la fuente es la clasificación autoritativa
      │
      ▼
PublicationRecord  ──upsert──▶  publications          ← el único escritor es el coordinador
      │
      │  ValueObservation ─▶ AsyncStream<AppResult<[Publication]>>
      ▼
Publication (dominio)  ──▶  HomeUiState  ──▶  HomeContentView
```

La flecha de vuelta no existe: **ninguna vista llega a un DTO ni a un registro**, y las reglas 3 y 10
lo comprueban.

---

## `BocDate` · `Domain/Model`

Una fecha del calendario, sin hora y sin zona. Swift no tiene `LocalDate` y `Date` es un instante, así
que se declara (D-314).

| Campo | Tipo | Reglas |
|---|---|---|
| `year` | `Int` | 1583 … 9999 |
| `month` | `Int` | 1 … 12 |
| `day` | `Int` | 1 … días reales del mes, bisiestos incluidos |

- `init?(iso:)` acepta **exactamente** `AAAA-MM-DD`: diez caracteres, tres tramos, **todos dígitos
  ASCII**. `+2026-08-26`, `2026-8-26`, `26-08-26`, `2026-13-01` y `2026-02-30` devuelven `nil`. La
  comprobación de dígitos no es adorno: `Int("+1")` vale 1, y ésa es la trampa que ya cazó
  `AppVersion`.
- `var iso: String` rellena con ceros, de modo que `iso` e `init?(iso:)` son inversas.
- `Comparable` sobre la terna año-mes-día, que coincide con el orden cronológico.
- No sabe formatearse: eso es `Core/Util/BocDateFormatting`, y es deliberado (D-316). El dato y su
  presentación no viven juntos.

---

## `Publication` · `Domain/Model`

Un anuncio del BOC, tal como el resto de la aplicación lo entiende.

| Campo | Tipo | Reglas |
|---|---|---|
| `externalKey` | `String` | Identidad estable. No vacía. `boc:439765` cuando el enlace trae identificador |
| `blobId` | `String?` | El identificador del enlace, si lo hay |
| `idSource` | `IdSource` | Cuál de los tres escalones de la cascada se usó |
| `feedId` | `String` | La fuente de la que se obtuvo. **Es la clasificación autoritativa** |
| `sectionCode` | `String` | `1` … `9`. Viene del catálogo, **nunca** de `categorias` |
| `subsectionCode` | `String?` | `2.1`, `7.3`… Nulo en las secciones sin subsección |
| `title` | `String` | Íntegro, tal como se recibe. No vacío |
| `issuer` | `String?` | Organismo emisor deducido. Nulo si no se pudo deducir |
| `organizationPath` | `[String]` | Ruta jerárquica, de más general a más concreta. Sin elementos vacíos |
| `editionType` | `EditionType` | Ordinaria, extraordinaria o desconocida |
| `publicationDate` | `BocDate` | Interpretada como `AAAA-MM-DD` |
| `documentUrl` | `URL` | Enlace al documento oficial. **Siempre HTTPS** |
| `rawCategories` | `String?` | El campo original, sin tocar |
| `warnings` | `Set<ParserWarning>` | Anomalías detectadas. **Nunca motivo de descarte** |

**Invariantes**, todos comprobados en `PublicationTests`: clave externa no vacía; título no vacío;
esquema HTTPS; ruta de organismo sin elementos vacíos. Lo que **no** es invariante: que `warnings`
esté vacío. Una publicación con advertencias es una publicación válida (FR-015).

---

## Los cuatro enumerados · `Domain/Model/PublicationFacets` y `BocSection`

| Tipo | Casos | Para qué |
|---|---|---|
| `EditionType` | `ordinary` · `extraordinary` · `unknown` | El tipo de edición, detectado en cualquier posición (FR-014) |
| `IdSource` | `blobId` · `canonicalUrl` · `contentHash` | Qué escalón de la cascada dio la identidad. Sirve para saber si un registro es sustituible por otro mejor identificado |
| `ParserWarning` | `categoryDoesNotMatchFeed` · `editionTypeMissing` · `categoryOrderUnreliable` · `categoriesAbsent` | Lo que se detectó al normalizar. Se guarda, no se muestra |
| `SectionColorGroup` | `general` · `personnel` · `contracting` · `economy` · `announcements` | **Es un tipo de dominio, no un color.** La traducción a color vive en `Core/UI/Theme` |

Los cuatro entran en la lista de exentos de la regla 9: no tienen comportamiento, y su semántica se
prueba donde vive (D-325).

---

## `BocSection` · `Domain/Model`

| Campo | Tipo | Reglas |
|---|---|---|
| `code` | `String` | `1`, `2`, `2.1`, `7.5`… Único |
| `name` | `String` | Nombre oficial completo |
| `shortName` | `String` | El del chip y el del panel |
| `parentCode` | `String?` | Nulo en las nueve principales |
| `order` | `Int` | Orden oficial de presentación |
| `colorGroup` | `SectionColorGroup` | El del reparto de D-326 |

**Nueve principales y catorce subsecciones**, veintitrés filas en total:

```text
1 Disposiciones Generales                   (fuente propia)
2 Autoridades y Personal                    ── SIN fuente propia
    2.1 Nombramientos, Ceses y Otras Situaciones
    2.2 Cursos, Oposiciones y Concursos
    2.3 Otros
3 Contratación Administrativa               (fuente propia)
4 Economía, Hacienda y Seguridad Social     ── SIN fuente propia
    4.1 Actuaciones en materia Presupuestaria
    4.2 Actuaciones en materia Fiscal
    4.3 Actuaciones en materia de Seguridad Social      ← nueve entradas, la última de 2021
    4.4 Otros
5 Expropiación Forzosa                      (fuente propia)
6 Subvenciones y Ayudas                     (fuente propia)
7 Otros Anuncios                            ── SIN fuente propia
    7.1 Urbanismo
    7.2 Medio Ambiente y Energía
    7.3 Estatutos y Convenios Colectivos
    7.4 Particulares
    7.5 Varios
8 Procedimientos Judiciales                 ── SIN fuente propia
    8.1 Subastas                                        ← canal válido con cero publicaciones
    8.2 Otros Anuncios
9 Elecciones                                (fuente propia)
```

**La consecuencia que hay que tener presente al consultar**: las secciones **2, 4, 7 y 8 no tienen
fuente propia**. Su contenido es la unión del de sus subsecciones, así que una consulta por sección
principal tiene que recoger también a sus descendientes. Es lo que hace que el prefijo del código sea
el criterio, y no la igualdad.

---

## `HomeSelection` · `Domain/Model`

Lo que la pantalla está mostrando. Determina el listado, el texto y el rótulo de la cabecera, y si hay
segunda fila de chips.

```text
HomeSelection
├── todaysBulletin                          → la fecha más reciente, de todas las secciones
└── section(code, subsectionCode: String?)  → esa sección entera, sin límite de fecha
```

| Caso | Listado | Rótulo de la cabecera | Segunda fila |
|---|---|---|---|
| `todaysBulletin` | Publicaciones de `MAX(publication_date)` | `Edición del …` | No |
| `section("1", nil)` | Todas las de la sección 1 | `Última publicación: …` | No — la 1 no tiene subsecciones |
| `section("2", nil)` | Todas las de la 2 **y sus tres hijas** | `Última publicación: …` | Sí, con `Toda la sección` marcado |
| `section("2", "2.2")` | Solo las de la 2.2 | `Última publicación: …` | Sí, con `2.2` marcado, y la **2 sigue marcada arriba** |

**Se persiste como el código, no como un índice ni como una posición.** Al restaurar se resuelve
contra el catálogo y, si no casa, se cae a `todaysBulletin` en silencio (D-318). Un código guardado
que ya no exista tumbaría Inicio en el único camino que nadie recorre a mano.

---

## `BulletinHeader` y `SyncSummary` · `Domain/Model`

`BulletinHeader` es lo que la cabecera editorial necesita y nada más: `title`, `date: BocDate?` y
`count: Int`. **La fecha es opcional a propósito**: sin fecha no se pinta rótulo (FR-035), y un
«Edición del» huérfano en la primera ejecución sería peor que la fecha desnuda que sustituye.

`SyncSummary` es lo que una actualización devuelve:

| Campo | Tipo | Qué decide |
|---|---|---|
| `succeededFeeds` | `Int` | — |
| `unchangedFeeds` | `Int` | Las que la huella dejó fuera sin reprocesar |
| `failedFeeds` | `Int` | — |
| `inserted` / `updated` / `rejected` | `Int` | Diagnóstico y telemetría, solo recuentos |

Derivadas: `allFailed` cuando ninguna fuente tuvo éxito; `isComplete` cuando ninguna falló. Son las
dos que la pantalla consulta, y por eso `SyncSummary` **no** es exento de la regla 9.

---

## Capa de datos: los DTO

```text
RssChannelDTO(title: String?, link: String?, description: String?, declaredSize: Int?, items: [RssItemDTO])
RssItemDTO(title: String?, link: String?, pubDateRaw: String?, categoriesRaw: String?)
```

**Todo anulable a propósito**: el DTO refleja lo que llega, no lo que debería llegar. `declaredSize` es
informativo; si no coincide con el número real de nodos, **mandan los nodos** y se registra aviso. Es
lo que comprueba `feed_size_incorrecto.xml`.

## Capa de datos: el catálogo

`BocFeedDefinition(feedId, url, sectionCode, subsectionCode, order, enabled)` — **diecinueve entradas
con la dirección escrita entera**. Prohibido componerla por cálculo (FR-002), y no es un capricho: los
identificadores no son correlativos —faltan varios en medio y dos pertenecen a otro rango— porque el
servicio los asignó cuando quiso.

---

## Esquema: `boc.db`, versión 1

### Tabla `publications`

| Columna | Tipo | Índice |
|---|---|---|
| `external_key` | TEXT | **Clave primaria** |
| `blob_id` | TEXT? | **Único cuando no es nulo** |
| `id_source` | TEXT | |
| `feed_id` | TEXT | Compuesto con `publication_date` |
| `section_code` | TEXT | Sí |
| `subsection_code` | TEXT? | Sí |
| `title` | TEXT | |
| `issuer` | TEXT? | |
| `organization_path` | TEXT | Ruta serializada |
| `edition_type` | TEXT | |
| `publication_date` | TEXT | Sí. ISO, ordena igual que cronológicamente (D-315) |
| `document_url` | TEXT | |
| `raw_categories` | TEXT? | |
| `warnings` | TEXT | Conjunto serializado |
| `first_seen_at` | INTEGER | Se fija al insertar y **no se toca al actualizar** |
| `last_seen_at` | INTEGER | Se actualiza en cada aparición |

### Tabla `feed_sync_state`

| Columna | Tipo | Significado |
|---|---|---|
| `feed_id` | TEXT | Clave primaria |
| `body_hash` | TEXT? | SHA-256 del último cuerpo procesado. Es lo que evita reanalizar cien anuncios idénticos |
| `etag` | TEXT? | Si el servicio llega a publicarlo. Hoy no lo hace |
| `last_modified` | TEXT? | Ídem |
| `last_success_at` | INTEGER? | La base del cálculo de la caducidad de treinta minutos |
| `consecutive_failures` | INTEGER | Diagnóstico |

### Reglas de escritura, que son invariantes y no estilo

1. **Upsert por `external_key`.** Una publicación conocida se actualiza, nunca se duplica (FR-020).
2. **No existe ninguna operación de borrado sobre `publications`.** Salir de la ventana de cien de una
   fuente **no elimina nada** (FR-021). Si aparece un borrado en una revisión, se rechaza; y además
   hay una prueba que recoge las sentencias ejecutadas y lo demuestra (D-324).
3. **La actualización es una lista blanca de columnas.** `first_seen_at` no está en ella. Cuando
   lleguen la marca de guardado y la de evaluación pendiente, tampoco lo estarán, y no hará falta
   acordarse de protegerlas.
4. **Escribe el padre, una transacción por fuente** (D-308).

### Migraciones

Ninguna todavía: la v1 es el punto de partida, con el esquema versionado desde el primer día
precisamente para poder escribir la prueba de migración cuando llegue la v2 —que será, casi seguro, la
columna de texto normalizado de la feature de Buscar (D-332)—. `eraseDatabaseOnSchemaChange` vale
`false` y tiene su aserción.

---

## Consultas

| Necesidad | Forma |
|---|---|
| Fecha más reciente | `SELECT MAX(publication_date) FROM publications` |
| Boletín del día | `WHERE publication_date = (SELECT MAX(publication_date) FROM publications)` |
| Sección principal | `WHERE section_code = :code` — recoge a sus subsecciones porque comparten `section_code` |
| Subsección | `WHERE subsection_code = :code` |
| Recuento de la selección | `COUNT(*)` sobre el mismo filtro |

**El orden, en todas ellas:**

```sql
ORDER BY publication_date DESC, CAST(blob_id AS INTEGER) DESC, external_key DESC
```

El tercer criterio es el desempate determinista de FR-028. Sin él, dos ejecuciones pueden dar órdenes
distintos porque las diecinueve fuentes responden en orden distinto, y eso se ve: la lista cambia sola
al refrescar.

---

## Presentación

```text
HomeUiState                                    (inmutable)
  selection:      HomeSelection
  header:         BulletinHeader?
  sectionChips:   [SectionChip]                «Boletín de hoy» + las nueve
  subsectionChips:[SectionChip]                vacío cuando no procede (FR-052)
  content:        HomeContent
  isRefreshing:   Bool                         ─┐ ejes independientes
  isOffline:      Bool                         ─┘ del contenido

HomeContent
├── skeleton              primera carga con la base vacía
├── publications([Publication])
├── empty                 la selección no tiene publicaciones — NO es un error
└── error(DomainError)    no hay nada que mostrar y la sincronización falló
```

**`isRefreshing` e `isOffline` son banderas, no casos.** Es la decisión que impide el enumerado de
doce estados que nadie sabe leer, y es también la razón por la que `DomainError` no crece con un caso
de «sin conexión pero con contenido» (D-331): eso no es un error, es un resultado correcto con una
bandera.

### Transiciones

```text
                       hay contenido guardado
   [entrada] ──────────────────────────────────▶ publications ──refresh()──▶ publications
       │  base vacía                                   ▲                          │ allFailed
       ▼                                               └──────────────────────────┘ + isOffline
   skeleton ──refresh() con items───────────────▶ publications
       ├──refresh() sin items──────────────────▶ empty
       └──refresh() falla y no hay nada────────▶ error ──onRetry()──▶ skeleton

   cualquier estado ──cambio de selección──▶ publications | empty     (NUNCA skeleton)
```

**Cambiar de selección no vuelve nunca a los esqueletos**: los datos ya están guardados, así que la
transición es inmediata. Los esqueletos son solo para la primera carga con la base vacía.

### El panel

```text
MainUiState
  sections:   [SectionRow]        el árbol completo, ordenado
  expanded:   Set<String>         qué secciones están desplegadas
  selection:  HomeSelection

SectionRow { section: BocSection; children: [BocSection] }
```

El abierto/cerrado del panel **no está aquí**: es `@State` de la vista, porque es efímero y no
sobrevive a nada (D-319). Lo que sí sobrevive es `selection`, y `expanded` no: volver a abrir el panel
lo presenta contraído, que es lo que el documento de diseño dibuja.

---

## Tokens de diseño que esta feature consume

| Elemento | Token |
|---|---|
| Fondo de la pantalla | `colors.background` |
| Cabecera editorial | `colors.primary` · `typography.headlineLarge` · `typography.bodyLarge` · `spacing.lg` |
| Distintivo del recuento | contorno en `colors.onPrimaryMuted` · `typography.labelLarge` |
| Chip de sección, en reposo | `colors.surface` · borde `colors.outline` · `typography.labelLarge` · `shape.chip` |
| Chip de sección, elegido | `colors.secondary` · texto `colors.onPrimary` |
| Chip de subsección, en reposo | `colors.surfaceSoft` · `typography.labelMedium` · `colors.textSecondary` |
| Tarjeta | `colors.surface` · `shape.medium` · `spacing.md` · `elevation.level1` |
| Línea de sección de la tarjeta | los cinco `colors.section*` de D-326, 4 pt, separada `spacing.sm` |
| Organismo · Título · Fecha | `typography.labelMedium` / `titleMedium` / `bodySmall` |
| Esqueleto | `colors.surfaceStrong`, cinco como máximo |
| Aviso sin conexión | `shape.banner` · `colors.surfaceSoft` · icono `ic_cloud_off` |
| Velo del panel | `colors.scrim`, **nuevo** (D-319) |
| Fila del panel | 72 pt mínimo · icono 28 pt en el color de grupo · `typography.titleMedium` |
| Subsecciones del panel | `colors.surfaceSoft` · `shape.small` · sangría `spacing.lg` |
| Barra inferior | `colors.surface` · icono 24 pt · `typography.labelMedium` · separación `spacing.xxs` |

Los nueve iconos de sección —`ic_section_general` … `ic_section_elections`— y `ic_calendar`,
`ic_share`, `ic_bookmark`, `ic_menu`, `ic_arrow_back`, `ic_expand_more`, `ic_cloud_off`, `ic_search`,
`ic_info`, `ic_home` **ya están en el catálogo** desde la 001. No se dibuja ninguno nuevo.
