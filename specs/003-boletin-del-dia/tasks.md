# Tasks: Boletín del día — lectura del BOC y pantalla de Inicio

**Input**: Documentos de diseño en `specs/003-boletin-del-dia/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: **OBLIGATORIOS.** El principio V de la constitución los declara no negociables y la
especificación los exige en FR-082 … FR-088. Dentro de cada historia, la prueba de una pieza se
escribe **con** la pieza y ninguna tarea se da por terminada sin su prueba en verde. **Prohibido**
`.disabled`, comentar o borrar una prueba para que pase la build.

**Organization**: por historia de usuario, de forma que cada una pueda implementarse, probarse y
demostrarse por separado.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizable (ficheros distintos, sin dependencias entre sí)
- **[Story]**: a qué historia pertenece (US1, US2, US3, US4)
- Las rutas son exactas y relativas a la raíz del repositorio

**Abreviaturas**: `APP/` = `BOCantabria-ios/` · `TEST/` = `BOCantabria-iosTests/` ·
`UITEST/` = `BOCantabria-iosUITests/`

---

## Phase 1: Setup

**Purpose**: las carpetas, los textos y los tokens que todo lo demás necesita, y la comprobación de
que GRDB compila dentro del proyecto.

- [X] T001 Crear las carpetas nuevas: `APP/Data/Sync/`, `APP/UI/Main/`, `APP/UI/Home/Component/`,
      `APP/UI/Search/`, `APP/UI/Saved/` y `UITEST/Main/`. Los grupos sincronizados las recogen
      solas: **no se toca `project.pbxproj`** para fuentes.
- [X] T002 [P] **FR-079**: añadir a `APP/Localizable.xcstrings` las veinticinco cadenas de esta
      feature, con los textos literales de `docs/referencia-android/res/strings.xml` y cada una con
      su `comment`: `app_bar_title`, `app_bar_open_sections`, `app_bar_search`, `app_bar_info`,
      `home_bulletin_today`, `home_header_date_bulletin`, `home_header_date_section`,
      `chip_todays_bulletin`, `chip_whole_section`, `home_empty_today`, `home_empty_section`,
      `home_error_sync`, `home_offline`, `publication_save`, `publication_unsave`,
      `publication_share`, `publication_share_chooser`, `publication_section`, `sections_expand`,
      `sections_collapse`, `sections_close`, `nav_home`, `nav_search`, `nav_saved`, `coming_soon`.
- [X] T003 [P] **D-316**: añadir a `APP/Localizable.xcstrings` los doce nombres de mes en minúscula
      y el **primer plural del catálogo**, `home_publication_count` («%lld anuncio» / «%lld
      anuncios»). Es `%lld` y no `%d`: en 64 bits un `Int` no cabe en `%d`.
- [X] T004 [P] `APP/Core/UI/Strings.swift`: añadir `enum Home`, `enum Sections`, `enum Nav` y
      `enum Card` con las claves nuevas, siguiendo el patrón del `enum Splash`.
- [X] T005 [P] **D-326 y D-319**: añadir a `APP/Core/UI/Theme/BocColors.swift` los cinco colores de
      sección del apartado 4.4 del documento de diseño —`sectionGeneral` `#1565C0`,
      `sectionPersonnel` `#6A4C93`, `sectionContracting` `#00838F`, `sectionEconomy` `#2E7D32`,
      `sectionAnnouncements` `#AD5B00`— y el token `scrim` del velo del panel. Son los seis únicos
      tokens nuevos; **la regla 7 exige que se construyan aquí y solo aquí**.
- [X] T006 **FR-080** `TEST/Core/BocThemeTests.swift`: afirmar los seis valores nuevos, y que
      **ninguno tiene variante oscura** —la regla 8, que ya existe, es la que lo protege— y retirar de la cabecera
      del fichero de colores la nota de que los de sección «quedan fuera a propósito», que deja de
      ser cierta.
- [X] T007 **Prueba de humo de GRDB**: un `import GRDB` en un fichero de `APP/Data/Source/Local/` y
      una construcción. Confirma lo que el plan da por hecho: la biblioteca está enlazada desde la
      001 y **no hay que tocar `project.pbxproj`**. Si esto falla, no se sigue.

**Checkpoint**: ✅ el árbol compila con GRDB dentro —comprobado con un fichero de humo que se
retira acto seguido— y la suite pasa: **118 pruebas en 19 suites, 0,188 s**, todas en verde (eran
116 al empezar; las dos nuevas son las de los seis tokens de color).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: el dominio entero, el catálogo, las costuras transversales, las reglas de arquitectura
nuevas y la retirada de la rodaja de relleno. ⚠️ **Bloquea las cuatro historias.**

### Dominio

- [X] T008 [P] **D-314** `APP/Domain/Model/BocDate.swift`: `struct BocDate: Sendable, Hashable,`
      `Comparable, Codable` con año, mes y día, `init?(iso:)` estricto y `var iso`. Swift no tiene
      `LocalDate` y `Date` es un instante: ésta es una de las decisiones que **no se heredan** de
      Android.
- [X] T009 `TEST/Domain/BocDateTests.swift`: la tabla de entradas malas —`+2026-08-26`, `2026-8-26`,
      `26-08-26`, `2026-13-01`, `2026-02-30`, vacía—, el ida y vuelta con `iso`, y el orden. **La
      del signo es la que importa**: `Int("+1")` vale 1, y es la misma trampa que ya cazó
      `AppVersion`. La cazó una prueba, no una revisión.
- [X] T010 [P] `APP/Domain/Model/PublicationFacets.swift`: `EditionType`, `IdSource` y
      `ParserWarning`. **FR-014, FR-015 y FR-017.**
- [X] T011 [P] `APP/Domain/Model/Publication.swift`: los catorce campos de `data-model.md`.
- [X] T012 `TEST/Domain/PublicationTests.swift`: los cuatro invariantes —clave externa no vacía,
      título no vacío, esquema HTTPS, ruta sin elementos vacíos— y que **tener advertencias no es
      un invariante roto** (**FR-015**).
- [X] T013 [P] `APP/Domain/Model/BocSection.swift`: `BocSection` y `SectionColorGroup`, con el
      catálogo de las **veintitrés** filas —nueve secciones y catorce subsecciones—.
- [X] T014 `TEST/Domain/BocSectionTests.swift`: **SC-006**. Veintitrés filas; las cuatro secciones
      sin fuente propia (2, 4, 7 y 8) tienen hijas; cada sección mapea a uno de los cinco grupos
      cromáticos y **ninguna se queda sin color** (**D-326**); el orden es el oficial.
- [X] T015 [P] `APP/Domain/Model/HomeSelection.swift`: `todaysBulletin` y `section(code:,`
      `subsectionCode:)`, con el código como cadena. **Nunca un índice** (**D-318**).
- [X] T016 `TEST/Domain/HomeSelectionTests.swift`: la tabla de cuatro filas de `data-model.md`
      —qué lista, qué rótulo y si hay segunda fila— y que un código desconocido se resuelve a
      `todaysBulletin`.
- [X] T017 [P] `APP/Domain/Model/BulletinHeader.swift`: título, `date: BocDate?` y recuento. **La
      fecha es opcional a propósito**: sin fecha no se pinta rótulo (**FR-035**).
- [X] T018 [P] `APP/Domain/Model/SyncSummary.swift`: los seis recuentos y las derivadas `allFailed`
      e `isComplete`.
- [X] T019 `TEST/Domain/SyncSummaryTests.swift`: las dos derivadas, incluido el caso de cero
      fuentes.
- [X] T020 **D-331** `APP/Domain/Model/DomainError.swift`: añadir `storage` y `cancelled`. Es un
      enumerado cerrado, así que **el compilador va a señalar los `switch` de la portada y de
      Inicio**: eso es la característica, no el coste.
- [X] T021 [P] `APP/Domain/Repository/PublicationRepository.swift`,
      `BocSectionRepository.swift` y `HomeSelectionStore.swift`: los tres protocolos de
      `contracts/internal-contracts.md` §1. **Ninguno lanza**; el error viaja en `AppResult`.
- [X] T022 [P] `APP/Domain/UseCase/`: `ObservePublicationsUseCase`, `ObserveBulletinHeaderUseCase`,
      `RefreshPublicationsUseCase` y `GetBocSectionsUseCase`, `struct … : Sendable` con un único
      `callAsFunction`.

### Catálogo de fuentes

- [X] T023 **FR-001, FR-002** `APP/Data/Source/Remote/BocFeedCatalog.swift`: las diecinueve
      definiciones con **la dirección escrita entera**. Prohibido componerla por cálculo, y no es
      un capricho: los identificadores no son correlativos y dos pertenecen a otro rango.
- [X] T024 `TEST/Data/BocFeedCatalogTests.swift`: **SC-006**. Diecinueve entradas; todas HTTPS;
      todas apuntan al servicio oficial; cada una casa con una sección o subsección del catálogo de
      dominio; y **ninguna dirección se construye concatenando**. **FR-003**: desactivar una entrada
      la retira de la lista que se consulta **sin tocar el proceso de lectura**, y una entrada nueva
      entra sin tocarlo tampoco.
- [X] T025 [P] `APP/Data/Repository/BocSectionRepositoryImpl.swift` y su prueba en
      `TEST/Data/BocSectionRepositoryImplTests.swift`: devuelve el árbol ordenado. No lee de la
      base: es catálogo.

### Costuras transversales

- [X] T026 **D-317** `APP/Core/Util/AppClock.swift`: añadir `nonisolated func now() -> Date`. La
      caducidad de treinta minutos lo necesita **síncrono**: comparar dos fechas no puede contagiar
      `await` a media aplicación.
- [X] T027 **D-317** `TEST/Fakes/Fakes.swift`: reescribir `ManualClock` de `actor` a
      `final class … @unchecked Sendable` con `Mutex`, **conservando `waitUntilSleeping(count:)`**.
      La trampa sigue viva palabra por palabra: adelantar el reloj antes de que la espera esté
      registrada hace que el adelanto se pierda y la prueba **se cuelgue en vez de fallar**. Y
      `ImmediateClock` recibe una fecha fija por inicializador, **no `Date()`**, o vuelve a ser el
      reloj del sistema disfrazado.
- [X] T028 `TEST/Core/ManualClockTests.swift`: que `now()` no avanza solo, que `advance(by:)` lo
      mueve, y que `waitUntilSleeping` espera de verdad.
- [X] T029 [P] **D-310** `APP/Core/Util/AppRandom.swift`: `protocol AppRandom: Sendable { func`
      `fraction() -> Double }` con `SystemRandom`, y `FixedRandom` en `TEST/Fakes/Fakes.swift`. La
      constitución exige que la aleatoriedad se inyecte y hoy no existe la costura; un
      `RandomNumberGenerator` no sirve porque su `next()` es `mutating` y el protocolo no es
      `Sendable`.
- [X] T030 [P] **D-316** `APP/Core/Util/BocDateFormatting.swift`: función pura sobre `BocDate` que
      compone el formato largo español desde el catálogo de cadenas. **Sin `Date`, sin `Calendar`,
      sin `TimeZone` y sin `DateFormatter`**, y la zona `Europe/Madrid` fijada en un solo sitio para
      decidir qué es «hoy».
- [X] T031 **SC-011, FR-087** `TEST/Core/BocDateFormattingTests.swift`: las doce fechas con la
      cadena exacta; los
      **dos** rótulos distintos (**FR-034**); que sin fecha **no se compone ningún rótulo**
      (**FR-035**); el plural en uno y en cero; y una prueba que cambia la zona del entorno y
      afirma que la fecha del boletín no se mueve.

### Reglas de arquitectura

- [X] T032 **D-323** `TEST/Architecture/SourceTree.swift`: añadir `rawCode` —comentarios fuera,
      **cadenas dentro**— junto al `code` actual, que no se toca. Sin esto, una regla que busque un
      borrado dentro de una sentencia SQL **no ve nada y pasa siempre**, que es exactamente el
      fallo que este proyecto ya cometió al traducir la regla de capas.
- [X] T033 `TEST/Architecture/SourceTreeTests.swift`: su caso propio. Añadir una regla obliga a
      añadir su prueba, y aquí además se está tocando el lector, que tiene pruebas propias.
- [X] T034 **D-325** `TEST/Architecture/ArchitectureRulesTests.swift`: ampliar la **regla 6** a
      GRDB. Es una entrada en una lista que ya existe.
- [X] T035 **D-325** `TEST/Architecture/ArchitectureRulesTests.swift`: **regla 10** — nadie fuera de
      `Data/Source/Local/` **nombra** un tipo de GRDB. Es la que las importaciones no cubren:
      dentro de un módulo Swift, un `import` en un fichero hace nombrable el tipo en todos los
      demás. Lista explícita y corta: `DatabaseQueue`, `DatabasePool`, `DatabaseWriter`,
      `DatabaseReader`, `Database`, `ValueObservation`, `DatabaseMigrator`, `Row`.
- [X] T036 **D-325** `TEST/Architecture/ArchitectureRulesTests.swift`: **regla 11** — fuera de
      `Core/Util` nadie construye `Date()` ni usa `Locale.current`, `Calendar.current`,
      `TimeZone.current` ni `DateFormatter(`. La constitución exige pruebas «sin reloj del sistema»
      y **hoy no lo comprueba nada**.
- [X] T037 **D-325** `TEST/Architecture/ArchitectureRulesTests.swift`: **regla 12** —
      `Task.detached` prohibido. Un solo identificador. Es lo que se escribe cuando lo correcto es
      `@concurrent`, y pierde la cancelación estructurada. Y **regla 13** — ninguna consulta
      declara un borrado sobre `publications`, que es la única que mira `rawCode` y, separada de
      las demás, dice **qué** invariante se rompió.
- [X] T038 **D-325** `TEST/Architecture/ArchitectureRulesTests.swift`: añadir a
      `domainTypesWithoutBehaviour` **solo** `EditionType`, `IdSource`, `ParserWarning` y
      `SectionColorGroup` —**FR-085 y SC-012** son lo que esta regla hace verificable—.
      `Publication`, `BocDate`, `BocSection`, `HomeSelection` y `SyncSummary`
      **no se eximen**: tienen comportamiento y ya tienen su fichero. Se decide aquí y en frío.
      Y **actualizar la cita del comentario**, que dice SC-002: en la 001 ése era el criterio de la
      cobertura de pruebas y **en esta feature SC-002 es el tiempo del boletín del día**. Aquí el
      criterio que la regla hace verificable es **SC-012**.
- [X] T039 **Paso 5 del quickstart**: provocar a mano una violación de cada regla nueva y comprobar
      que se pone en rojo. **Una regla que no puede fallar no protege nada.** Revertir después.

### Retirada de la rodaja de relleno — bloque indivisible

> Las siete tareas siguientes van juntas. Entre T040 y T046 el árbol no compila, y eso es normal:
> el punto de control es T047. Alcanza a **veinticinco ficheros**.

- [X] T040 Retirar de `APP/Domain/`: `Model/ContentItem.swift`,
      `Repository/ContentRepository.swift` y `UseCase/GetContentItemsUseCase.swift`.
- [X] T041 Retirar de `APP/Data/`: `Source/Remote/ContentItemDTO.swift`,
      `Source/Remote/ContentRemoteDataSource.swift`, `Source/Local/ContentItemRecord.swift`,
      `Source/Local/ContentLocalDataSource.swift` y `Repository/ContentRepositoryImpl.swift`.
- [X] T042 **D-322** `APP/Core/Util/LaunchConfiguration.swift`: retirar `contentScenario` y
      `argumentPrefix`. Su cabecera prometía que la costura «se sustituye, no se amplía, cuando la
      feature del boletín traiga el origen real»: **ésta es esa feature**.
- [X] T043 `APP/Core/DI/AppContainer.swift`: retirar el origen local, el origen de ejemplo, el
      repositorio de contenido y la fábrica que los usaba.
- [X] T044 `APP/UI/Home/`: reducir `HomeUiState` a su estado de carga y `HomeViewModel` a lo mínimo
      que compila. **Es provisional y dura una fase**: la US1 lo reescribe entero contra la cadena
      real.
- [X] T045 Retirar `TEST/Data/ContentRepositoryImplTests.swift`,
      `TEST/Domain/GetContentItemsUseCaseTests.swift` e
      `TEST/Integration/ContentFlowIntegrationTests.swift`, y de `TEST/Fakes/Fakes.swift` los cuatro
      dobles del relleno y sus constructores. **No se borra ninguna prueba de comportamiento
      vigente**: se borra lo que probaba una pieza que ya no existe.
- [X] T046 `UITEST/Home/HomeStatesUITests.swift` y `HomeBackgroundUITests.swift`: reescribir contra
      el estado de carga, **sin `.disabled` y sin comentar nada**. La US1 les devuelve los cinco
      escenarios.
- [X] T047 `TEST/Integration/AppContainerTests.swift`: que el contenedor se siga construyendo entero
      sin el relleno.

**Checkpoint**: ✅ el árbol **compila sin la rodaja de relleno**, las **trece** reglas de
arquitectura —nueve más las cuatro de esta feature— están en verde y se comprobó que las cinco
nuevas muerden provocando su violación, y las dos suites pasan: **172 pruebas sin interfaz en 30
suites, 0,262 s** y **13 de interfaz en 63,5 s**. A partir de aquí, las cuatro historias pueden
empezar.

> **Trampa encontrada aquí, y va a `CLAUDE.md`.** Anidar dos
> `.accessibilityElement(children: .contain)` **hace desaparecer el identificador del de dentro**.
> La guía ya decía que un contenedor necesita `.contain` para entrar en el árbol; faltaba la otra
> mitad: si su padre ya es un contenedor declarado, el hijo no aparece. Costó cuatro pruebas de
> interfaz en rojo con la pantalla correcta delante.

---

## Phase 3: User Story 1 — Ver el boletín del día nada más abrir (Priority: P1) 🎯 MVP

**Goal**: que la aplicación vaya al BOC, recoja lo publicado y lo presente en Inicio, con su
cabecera rotulada y sus tarjetas.

**Independent Test**: instalar en un dispositivo limpio, abrir con conexión y comprobar que aparecen
publicaciones reales con su organismo, su título y su fecha, y que la cabecera dice «Edición del …»
con el recuento. Es el paso 6 del quickstart.

### El analizador

- [X] T048 [US1] **D-300, D-312, FR-008** `APP/Data/Source/Remote/RssDTO.swift` y
      `BocRssParser.swift`: `@concurrent func parseFeed(_:limit:) throws -> RssChannelDTO`, con
      `XMLParser`. **`XMLDocument` no existe en iOS.** El delegado es una subclase de `NSObject`
      creada dentro de la función y sostenida en un `let`: **no se declara `@unchecked Sendable`**;
      si nada escapa, el compilador no pide nada.
- [X] T049 [US1] **D-313** `APP/Data/Source/Remote/BocRssParser.swift`: la guarda contra
      `<!DOCTYPE` y `<!ENTITY` **sobre bytes**, no sobre texto decodificado —la codificación
      declarada puede no ser UTF-8, y una decodificación fallida convertiría la guarda en un pase
      libre—, más `shouldResolveExternalEntities = false` y
      `externalEntityResolvingPolicy = .never`. Dos capas.
- [X] T050 [US1] **FR-082** `TEST/Data/BocRssParserTests.swift`: las diez muestras de
      `TEST/Fixtures/`. `feed_1_disposiciones` normal; `feed_8_1_vacio` **es un resultado válido**
      (**FR-009**); `feed_size_incorrecto` manda el recuento real; `feed_campos_desconocidos` se
      ignora sin fallar; `feed_con_doctype` y `feed_con_entidad_externa` se rechazan, y la segunda
      **además** afirma que no se hizo ninguna petición de red.
- [X] T051 [US1] **D-312** `TEST/Data/BocRssParserTests.swift`: las tres trampas, una prueba cada
      una. **El delegado es débil** —se pone roja si alguien «simplifica» la asignación—; **el
      texto llega troceado**, con una muestra de título largo con entidades; y **el booleano de
      `parse()`**, con un XML truncado, porque ignorarlo convierte un XML roto en «cero anuncios»,
      indistinguible de un feed vacío legítimo.
- [X] T052 [US1] **D-309** `TEST/Data/BocRssParserTests.swift`: cancelar a mitad de una muestra
      grande devuelve menos items y propaga la cancelación. `XMLParser.parse()` es síncrono y no
      comprueba cancelación: cambiar de hilo no hace cancelable un trabajo bloqueante.

### El normalizador

- [X] T053 [US1] **FR-011 … FR-018** `APP/Data/Source/Remote/PublicationNormalizer.swift`: las once
      reglas de `contracts/internal-contracts.md` §2. **La sección la manda la fuente**; el campo de
      clasificación se conserva íntegro y solo enriquece y verifica.
- [X] T054 [US1] **FR-082** `TEST/Data/PublicationNormalizerTests.swift`: la matriz completa. Tres,
      cuatro y cinco componentes; tipo de edición al principio, en medio, al final y ausente;
      clasificación que no corresponde a la fuente; componentes vacíos y barra final; **el
      desorden real del feed 4.3**, que ni rompe ni descarta; enlace sin identificador, con los tres
      escalones de la cascada; y título muy largo, que se guarda entero.
- [X] T055 [US1] **FR-010** `TEST/Data/PublicationNormalizerTests.swift`: los rechazos individuales
      —título vacío, enlace no HTTPS, fecha ilegible— **con su motivo** y sin detener el resto de la
      fuente. Muestra: `feed_fecha_invalida.xml`.

### La descarga

- [X] T056 [US1] `APP/Data/Source/Remote/FeedDownloader.swift`: el protocolo y `FeedFetchResult`.
      **Es la única interfaz del proyecto que puede fallar sin lanzar**, y es deliberado: devuelve
      el fallo como valor para que el orquestador siga con las demás (**FR-004**).
- [X] T057 [US1] **D-311, FR-005 … FR-008** `APP/Data/Source/Remote/HttpFeedDownloader.swift`:
      `URLSession.bytes(for:)` **contando bytes mientras llegan** —`data(for:)` bufea antes de que
      puedas comprobar nada—, rechazo previo por longitud declarada, tope de 5 MB, validación del
      esquema y del host **sobre la dirección final** porque las redirecciones se siguen solas,
      `waitsForConnectivity = false` —con `true` el estado «sin conexión» no llega nunca— y
      `User-Agent` y `Accept` en la configuración.
- [X] T058 [US1] **FR-006** `APP/Data/Source/Remote/HttpFeedDownloader.swift`: tres intentos con
      espera creciente **más jitter inyectado**, solo ante agotamiento de tiempo, error de
      conexión, 408, 429 y 5xx; **nunca** ante 400, 401, 403, 404 ni cuerpo inválido.
- [ ] T059 [US1] `TEST/Data/HttpFeedDownloaderTests.swift`: con un `URLProtocol` de prueba
      **declarado en el target de pruebas, no en producción**. Tope de tamaño, redirección a otro
      host, tipo de contenido incorrecto, cuerpo truncado, y la lista exacta de esperas con
      `FixedRandom` y `ManualClock` (**D-310**).
- [X] T060 [US1] **FR-022** `APP/Data/Source/Remote/HttpFeedDownloader.swift`: la huella SHA-256 del
      cuerpo y la respuesta «sin cambios» cuando coincide con la conocida. Es lo que evita analizar
      cien anuncios idénticos diecinueve veces al día.

### La base

- [X] T061 [US1] **D-301, D-306** `APP/Data/Source/Local/BocDatabase.swift`: `DatabaseQueue` con
      `journalMode = .wal`, en Application Support —**no en cachés**: el sistema puede vaciarlas y
      ésta es la procedencia de lo que la pantalla muestra— y con protección
      `.completeUntilFirstUserAuthentication`, pensando en la sincronización en segundo plano de la
      feature de Avisos. Es el **único** fichero que abre la base.
- [X] T062 [US1] `APP/Data/Source/Local/BocMigrations.swift`: la v1 con las dos tablas y sus
      índices de `data-model.md`. `eraseDatabaseOnSchemaChange` se queda en `false` **y merece su
      aserción**: es la bandera que uno enciende en desarrollo y se deja puesta.
- [X] T063 [US1] [P] `APP/Data/Source/Local/PublicationRecord.swift` y `FeedSyncStateRecord.swift`,
      con el mapeo a dominio. **La conversión de `BocDate` vive aquí** (**D-315**): el registro
      guarda texto ISO y el mapeo convierte, para no ponerle a un tipo de dominio una capacidad que
      solo existe por la capa de datos.
- [X] T064 [US1] **FR-019, FR-020, FR-021, FR-028**
      `APP/Data/Source/Local/PublicationQueries.swift`: el upsert por clave externa con **lista
      blanca de columnas** —`first_seen_at` no está en ella—, las cuatro consultas de
      `data-model.md` y el orden estable de tres criterios. **Ni un borrado.**
- [ ] T065 [US1] `TEST/Data/BocDatabaseTests.swift`: base en memoria. Migración v1; upsert que
      actualiza y no duplica; `first_seen_at` que no se mueve y `last_seen_at` que sí; y el modo de
      diario comprobado sobre un fichero temporal real, **declarando que la base en memoria lo
      ignora** (**D-301**).
- [ ] T066 [US1] **FR-037, FR-038** `TEST/Data/PublicationQueriesTests.swift`: el boletín del día es
      la fecha máxima **de todas las secciones**;
      una sección principal **recoge a sus subsecciones**; una subsección no recoge a su hermana; el
      recuento casa con la lista; y el desempate determinista con dos publicaciones de la misma
      fecha (**FR-028**).
- [X] T067 [US1] **D-305** `APP/Domain/UseCase/PrepareStartupUseCase.swift` y
      `APP/Core/DI/AppContainer.swift`: abrir y migrar la base como un paso más de la comprobación
      previa. Un fallo de migración es un desenlace de la portada, **no un cierre inesperado**;
      hoy la portada es el único sitio con indicador, límite de espera y reintento.
- [ ] T068 [US1] `TEST/Domain/PrepareStartupUseCaseTests.swift`: que un fallo al abrir la base
      publica el estado terminal con reintento, y que el camino feliz no lo altera.

### El coordinador y el repositorio

- [X] T069 [US1] **D-307, D-308, FR-004, FR-005** `APP/Data/Sync/FeedSyncCoordinator.swift`:
      `actor` con la tarea guardada; ventana explícita de cuatro simultáneas; **escribe el padre**,
      una transacción por fuente conforme terminan. Un solo escritor.
- [ ] T070 [US1] `TEST/Data/FeedSyncCoordinatorTests.swift`: el tope de cuatro con un descargador
      falso que es un `actor`, cuenta las que hay en vuelo, guarda el máximo y **se queda suspendido
      hasta que la prueba lo libera**. Sin ese mecanismo la prueba mide la velocidad de la máquina,
      no el tope.
- [ ] T071 [US1] **FR-004** `TEST/Data/FeedSyncCoordinatorTests.swift`: una fuente que falla no
      impide las demás, y todas las que respondieron se escriben.
- [X] T072 [US1] `APP/Data/Repository/PublicationRepositoryImpl.swift`: las **cinco filas** de la
      política de `refresh(force:)` de `contracts/internal-contracts.md` §1.
- [X] T073 [US1] **D-302, D-303, D-304** `APP/Data/Repository/PublicationRepositoryImpl.swift`: la
      observación como `AsyncStream<AppResult<[Publication]>>` sobre `values(in:scheduling: .task)`
      —**nunca `.immediate`**, que hace una lectura síncrona de SQLite en el actor principal—, con
      el mapeo registro→dominio **dentro del cierre de lectura** y la tarea que bombea cancelada
      desde `onTermination`.
- [ ] T074 [US1] `TEST/Data/PublicationRepositoryImplTests.swift`: las cinco filas de la política,
      una prueba por fila. Y la de la observación: arrancar, **cancelar**, escribir, y afirmar que
      no llega otro valor. Contando suscripciones dentro del propio flujo, porque tomar el primer
      valor no permite ver que un flujo termina.

### La pantalla

- [ ] T075 [US1] **FR-030, FR-039 … FR-042** `APP/UI/Home/HomeUiState.swift`: reescrito entero,
      con `HomeContent` de cuatro casos y las banderas de refresco y sin conexión como **ejes
      independientes**, no como casos del enumerado.
- [ ] T076 [US1] `APP/UI/Home/HomeViewModel.swift`: reescrito. `@MainActor @Observable`,
      `private(set) var state`, `apply(_:)` que **no retorna hasta publicar el primer estado** y
      comprobación de cancelación antes de publicar.
- [ ] T077 [US1] `TEST/UI/HomeViewModelTests.swift`: reescrito. Carga con contenido, carga vacía,
      error con reintento, y que la analítica de vista de pantalla se emite **una sola vez por
      instancia**.
- [ ] T078 [US1] [P] **FR-039, FR-040** `APP/Core/UI/Component/PublicationCard.swift`: organismo,
      título, fecha con icono y acciones, con la línea vertical del color de su sección **siempre
      acompañada de texto**. Sube a `Core` porque la van a usar tres pantallas.
- [ ] T079 [US1] [P] **FR-041** `APP/Core/UI/Component/PublicationCardSkeleton.swift`: marcadores
      con la forma del contenido final, **cinco como máximo**, nunca un indicador giratorio grande.
- [ ] T080 [US1] [P] **FR-032 … FR-036** `APP/UI/Home/Component/BulletinHeaderView.swift`: la
      denominación, la fecha **con su rótulo** y el distintivo perfilado del recuento. **Ningún
      número de boletín**: el servicio no lo publica, y escribirlo sería presentar un dato inventado
      como oficial.
- [ ] T081 [US1] [P] **FR-031** `APP/UI/Home/Component/HomeTopBar.swift`: control del panel, escudo,
      nombre, lupa e información. **Sin campana.**
- [ ] T082 [US1] `APP/UI/Home/HomeContentView.swift` y `HomeView.swift`: la composición de FR-030,
      la vista de contenido sin estado y previsualizable por estado, y los identificadores de
      accesibilidad de `contracts/internal-contracts.md` §5.
- [ ] T083 [US1] **D-320** `APP/UI/Home/`: todo contenedor que tenga que encontrarse se declara
      `.accessibilityElement(children: .contain)` **antes** del identificador. Sin eso no entra en
      el árbol, aunque se vea en pantalla.
- [ ] T084 [US1] **D-322** `APP/Data/Sync/ScenarioDatabaseSeeder.swift` y
      `APP/Core/Util/LaunchConfiguration.swift`: `-boc-data-scenario=` con `today`, `empty`,
      `failing`, `offline` y `slow`, sembrando la base con un conjunto **sintetizado en código**,
      en memoria o fichero temporal, **jamás la de la persona**. Sustituye a la costura vieja:
      siguen siendo dos argumentos, los mismos que hoy. **No se leen las muestras de
      `TEST/Fixtures/`**: viajan solo en el bundle de pruebas y este código corre en el proceso de
      la aplicación, que no las ve; y embarcarlas en el binario que se publica es justo lo que la
      promesa de costura acotada evita.
- [ ] T085 [US1] **FR-086** `UITEST/Home/HomeStatesUITests.swift`: devolverle los cinco escenarios,
      con **los mismos identificadores** de la 001, que son contrato. **D-328**: esperar por
      existencia, nunca reposo — el esqueleto pulsa sin fin por diseño y una espera de reposo se
      cuelga en lugar de fallar.
- [ ] T086 [US1] **D-316** `UITEST/`: lanzar fijando idioma y región por argumentos. El sistema de
      preferencias lee el dominio de argumentos por su cuenta, así que **no se toca una línea de
      producción**.
- [ ] T087 [US1] `TEST/Integration/SyncFlowIntegrationTests.swift`: el grafo real sobre base en
      memoria con descargador falso. Primera sincronización con las diez muestras, y el estado que
      la pantalla acaba viendo.
- [ ] T088 [US1] **FR-029, D-327** `APP/Data/Sync/FeedSyncCoordinator.swift` y
      `TEST/Data/FeedSyncCoordinatorTests.swift`: el evento `boc_sync` lleva **solo recuentos**
      —fuentes con éxito, sin cambios, fallidas, insertadas, actualizadas, rechazadas— y el registro
      `OSLog` de categoría `sync` dice fase, número de fuentes, bytes y motivo. La prueba, sobre
      `RecordingAnalyticsTracker`, afirma que **ningún parámetro lleva texto libre**: ni un título,
      ni un organismo, ni una dirección.
- [X] T089 [US1] **D-300** `TEST/Data/BocRssParserTests.swift`: la prueba que afirma, **dentro** de
      la función analizadora, que no se está en el hilo principal. Se pone roja si alguien quita
      `@concurrent`. Sin ella, el atributo es una convención.

**Checkpoint**: instalación limpia con conexión → publicaciones reales en Inicio en menos de 15 s,
con cabecera rotulada y recuento. **US1 es el MVP y ya es demostrable.**

---

## Phase 4: User Story 2 — Que lo consultado siga estando sin conexión (Priority: P1)

**Goal**: que lo guardado se vea al instante y sin cobertura, y que actualizar no vacíe la pantalla.

**Independent Test**: abrir con conexión, cerrar, modo avión, volver a abrir. Mismo contenido, de
inmediato, con el aviso. Pasos 7 y 8 del quickstart.

- [ ] T090 [US2] **FR-023, D-317** `APP/Data/Repository/PublicationRepositoryImpl.swift`:
      `isCacheStale()` contra `last_success_at` y el `now()` inyectado. **Un transcurrido negativo o
      una marca en el futuro se tratan como caducado**, no como recién sincronizado: si no, la
      caché se congela hasta que el reloj del dispositivo alcance ese valor.
- [ ] T091 [US2] `TEST/Data/PublicationRepositoryImplTests.swift`: a los veintinueve minutos no
      sincroniza, a los treinta y uno sí, y con la marca en el futuro sí. Con `ManualClock`, las
      tres en microsegundos. **`ImmediateClock` no vale aquí**: gana toda carrera contra un límite.
- [ ] T092 [US2] **FR-024, FR-025, FR-026** `APP/UI/Home/HomeViewModel.swift`: `onRefresh()` con
      `force: true`, que **siempre** sale a la red; `isRefreshing` mientras dura; y el contenido
      existente **intacto** durante toda la actualización.
- [ ] T093 [US2] **FR-025, D-307** `TEST/Data/FeedSyncCoordinatorTests.swift`: dos llamadas
      concurrentes producen **diecinueve** descargas, no treinta y ocho, y **las dos devuelven el
      mismo resumen**. La segunda espera y comparte; ignorarla haría que el indicador desapareciera
      antes que la sincronización.
- [ ] T094 [US2] [P] **FR-043** `APP/Core/UI/Component/OfflineBanner.swift`: aviso con icono
      `ic_cloud_off` **que no oculta el contenido**.
- [ ] T095 [US2] **FR-027** `APP/UI/Home/HomeViewModel.swift` y `HomeContentView.swift`: las dos
      ramas del fallo total —con contenido guardado, se muestra y se enciende el aviso; sin nada
      guardado, mensaje con reintento—.
- [ ] T096 [US2] **SC-003** `TEST/UI/HomeViewModelTests.swift`: las dos ramas anteriores —en ninguna
      de las dos se llega a una pantalla vacía sin explicación—, más que una
      actualización sin novedades **deja el contenido intacto y no muestra ningún error**.
- [ ] T097 [US2] **FR-021, FR-084, SC-005, D-324** `TEST/Integration/NoDeleteRegressionTests.swift`:
      configurar la base para **recoger cada sentencia que se ejecuta**, correr una sincronización
      completa y afirmar que ninguna borra de `publications`. Es la garantía de verdad: GRDB borra
      sin que la palabra aparezca en ninguna cadena del fuente, así que la regla textual **no puede
      verlo**.
- [ ] T098 [US2] `TEST/Integration/NoDeleteRegressionTests.swift`: con la misma traza, que la
      actualización de la sincronización es una **lista blanca de columnas** y no menciona
      `first_seen_at`. Es la infraestructura que Guardados y Avisos van a necesitar tal cual.
- [ ] T099 [US2] **SC-004** `TEST/Integration/SyncFlowIntegrationTests.swift`: cinco
      sincronizaciones seguidas no duplican nada y **el recuento no baja**, ni siquiera cuando una
      publicación deja de aparecer en la fuente.
- [ ] T100 [US2] **FR-083** `TEST/Integration/SyncFlowIntegrationTests.swift`: **la matriz completa
      de la sincronización, los nueve casos nombrados uno a uno**: primera obtención; segunda sin
      cambios, que **no reescribe nada** porque la huella coincide; publicación nueva; publicación
      actualizada, que conserva `first_seen_at`; publicación que **sale de la ventana de cien** y
      sigue guardada; una fuente que falla; todas fallan **con** contenido guardado; todas fallan
      **sin** contenido guardado; y un duplicado entre dos fuentes, que da **un solo registro**.
- [ ] T101 [US2] **FR-086** `UITEST/Home/HomeStatesUITests.swift`: el escenario `offline` muestra el
      aviso **sin tapar el contenido**, y el escenario `slow` sigue siendo necesario — comprobar la
      carga contra una latencia corta es una carrera contra el arranque, y subir el tiempo de espera
      no arregla nada porque el problema es el contrario.

**Checkpoint**: el contenido sobrevive sin cobertura, deslizar actualiza sin vaciar, y hay una
prueba que demuestra que nada borra.

---

## Phase 5: User Story 3 — Explorar el BOC por secciones (Priority: P2)

**Goal**: el panel lateral y las dos filas de chips, con la selección viva y persistente.

**Independent Test**: abrir el panel, desplegar una sección con subsecciones y elegir una; la lista,
la cabecera y las dos filas cambian. Pasos 9, 10 y 11 del quickstart.

- [ ] T102 [US3] **FR-068, D-318** `APP/Data/Source/Local/UserDefaultsSelectionStore.swift`: guarda
      **el código como cadena** y al restaurar lo **resuelve contra el catálogo**; si no casa, cae a
      «Boletín de hoy» en silencio. **Nunca un índice** y nunca un `init(rawValue:)` sin su
      alternativa explícita detrás: las subsecciones del BOC pueden cambiar, y un código guardado
      que ya no exista tumbaría Inicio en el único camino que nadie recorre a mano.
- [ ] T103 [US3] `TEST/Data/UserDefaultsSelectionStoreTests.swift`: guarda, lee, código desconocido
      y cadena vacía. Los cuatro casos.
- [ ] T104 [US3] `APP/UI/Main/MainUiState.swift` y `MainViewModel.swift`: la selección, el árbol de
      secciones y el conjunto de desplegadas. **El abierto/cerrado del panel no está aquí**: es
      `@State` de la vista, porque es efímero y no sobrevive a nada (**D-319**).
- [ ] T105 [US3] `TEST/UI/MainViewModelTests.swift`: elegir, desplegar, contraer, y **un valor
      guardado inválido que se resuelve a «Boletín de hoy»**.
- [ ] T106 [US3] **FR-057, FR-064, D-319** `APP/UI/Main/SectionsDrawer.swift`: pila en profundidad
      alineada al inicio con contenido, velo y panel; entrada por encima del contenido; cierre por
      deslizar y por tocar fuera. **No se construye gesto de apertura desde el borde**: ese borde ya
      lo usan el gesto de volver y los del sistema, y esto es una decisión del propietario, no una
      omisión.
- [ ] T107 [US3] **FR-060 … FR-063** `APP/UI/Main/SectionsDrawer.swift`: la cabecera con el escudo,
      «BOC Cantabria» y, **al final de la fila**, la flecha que recoge el panel, con descripción
      accesible. **Sin campo de filtro**, y sin nada de su lógica: ni filtrado, ni poda de
      subsecciones, ni apertura automática, ni estado vacío de «ninguna sección coincide».
- [ ] T108 [US3] **FR-058, FR-059, FR-066** `APP/UI/Main/SectionsDrawerRow.swift`: fila de 72 pt
      mínimo, icono de sección en el color de su grupo, número y nombre, chevron con rotación y
      divisor; subsecciones sobre `surfaceSoft` con sangría. El panel se recorre entero con todo
      desplegado.
- [ ] T109 [US3] **D-320** `APP/UI/Main/SectionsDrawer.swift`: el panel se mantiene montado con
      `.accessibilityHidden(!isOpen)` **y** `.allowsHitTesting(isOpen)`, más el rasgo modal mientras
      está abierto y la acción de escape. Un panel a mano no trae gratis lo que una hoja nativa sí.
      **FR-067**: y una aserción de que el panel **no contiene campana ni tarjeta de alertas**, que
      hoy se cumple por ausencia y mañana es lo que impide que alguien las reintroduzca sin pensar.
- [ ] T110 [US3] **D-320** `UITEST/Main/SectionsDrawerUITests.swift`: **antes de abrir nada**,
      afirmar que una etiqueta exclusiva del panel **no existe**. La aserción es sobre existencia,
      **no sobre pulsabilidad**: `allowsHitTesting(false)` a secas deja el elemento en el árbol, y
      comprobar lo segundo es comprobar la mitad equivocada.
- [ ] T111 [US3] **FR-065, SC-008** `UITEST/Main/SectionsDrawerUITests.swift`: contar los toques
      hasta una subsección, que son **tres como máximo**; abrir con el botón; cerrar tocando el
      velo; cerrar arrastrando; cerrar con la flecha **sin que cambie la selección**; y elegir una
      subsección comprobando que el panel se retira y la cabecera la nombra **por identificador**,
      nunca por texto.
- [ ] T112 [US3] **FR-045, FR-046, FR-054** `APP/UI/Home/Component/SectionChipRow.swift`: una sola
      vista que sirve a las dos filas, con estilo primario y secundario. El primer chip dice
      **«Boletín de hoy»**, no «Todo»: el comportamiento era correcto y la palabra era la
      equivocada.
- [ ] T113 [US3] **FR-047 … FR-053, FR-055** `APP/UI/Home/HomeViewModel.swift` y
      `HomeContentView.swift`: la segunda fila solo cuando procede; `Toda la sección`; **un solo
      toque hace las dos cosas**; la primera fila sigue marcando la sección padre; y llegar desde el
      panel produce el mismo resultado que llegar desde los chips.
- [ ] T114 [US3] `TEST/UI/HomeViewModelTests.swift`: las seis reglas anteriores, una aserción cada
      una, incluida la de que pasar a una sección sin subsecciones **retira** la segunda fila.
- [ ] T115 [US3] **FR-038** `APP/UI/Home/`: con sección elegida, el listado **no se limita a una
      fecha** y el rótulo de la cabecera pasa a «Última publicación: …». Es lo que evita que una
      fecha de 2021 se lea como un fallo.
- [ ] T116 [US3] **FR-056, FR-086** `UITEST/Home/HomeFiltersUITests.swift`: las dos filas, con
      `home_subsection_chips` **que no existe** cuando no procede; que ambas se desplazan
      horizontalmente; y que **el resto de la pantalla no se desplaza** con ellas.
- [ ] T117 [US3] **SC-007** `TEST/Integration/SyncFlowIntegrationTests.swift`: elegir 8.1 da estado
      vacío **con mensaje propio y ningún error**; elegir 4.3 da sus publicaciones antiguas con su
      advertencia registrada y **ninguna descartada**.
- [ ] T118 [US3] `APP/UI/Home/HomeView.swift`: la selección llega de `MainView` como `let` y se
      aplica con `.task(id: selection)`, que cancela la consulta anterior al cambiar. **Nada de
      `@Environment`** para esto (**D-321**).

**Checkpoint**: cualquier sección o subsección se alcanza en tres toques, y la selección sobrevive a
la muerte del proceso.

---

## Phase 6: User Story 4 — Moverse sin toparse con callejones (Priority: P3)

**Goal**: el armazón de tres destinos y que ninguna acción visible deje sin respuesta.

**Independent Test**: recorrer los tres destinos y las dos acciones de la barra superior. Paso 12
del quickstart.

- [ ] T119 [US4] **FR-069, FR-070, FR-072, D-321** `APP/UI/Main/MainView.swift` y `BocTabBar.swift`:
      `ZStack { TabView ; velo ; panel }` con **un `NavigationStack` por pestaña**. Envolver el
      `TabView` con un `NavigationStack` es el error habitual: rompe la barra y deja una sola pila
      para tres destinos. El panel va **por encima** del `TabView`, y como la portada es hermana de
      `MainView`, **no la alcanza**.
- [ ] T120 [US4] **D-321** `APP/UI/Main/BocTabBar.swift`: fondo de la barra declarado
      explícitamente, porque por defecto se pinta un material translúcido y el apartado 10.1 del
      documento de diseño pide blanco con borde superior. Activo marcado por **forma o peso, además
      del color** (**FR-070**).
- [ ] T121 [US4] **D-318, D-321** `APP/UI/Navigation/Route.swift`: `MainTab` restaurado **por
      nombre**, con su alternativa explícita. Misma cautela que la selección: una pestaña guardada
      que ya no exista tumbaría la aplicación al volver de la muerte del proceso.
- [ ] T122 [US4] [P] **FR-071** `APP/UI/Search/SearchView.swift` y `APP/UI/Saved/SavedView.swift`
      sobre `APP/Core/UI/Component/ComingSoonMessage.swift`: destinos reales con el aspecto de la
      aplicación.
- [ ] T123 [US4] **FR-073, FR-074** `APP/UI/Home/Component/HomeTopBar.swift`: la lupa avisa de que
      la búsqueda llegará próximamente; la información está y **no hace nada todavía**.
- [ ] T124 [US4] **FR-075** `APP/Core/UI/Component/PublicationCard.swift`: compartir abre la hoja
      del sistema **con el enlace del documento oficial**.
- [ ] T125 [US4] **FR-076, FR-077** `APP/Core/UI/Component/PublicationCard.swift`: guardar avisa; y
      **tocar el cuerpo de la tarjeta no navega a ningún sitio**, que es lo que la feature siguiente
      va a cambiar.
- [ ] T126 [US4] **FR-078** `APP/UI/Navigation/RootView.swift`: conmutar a `MainView` en lugar de a
      `HomeView`, conservando que la portada **no entra en la pila** y que volver desde Inicio no la
      hace reaparecer.
- [ ] T127 [US4] **FR-086, SC-009** `UITEST/Main/TabNavigationUITests.swift`: los tres destinos, el
      marcador
      en dos de ellos, y que la barra refleja cuál está activo.
- [ ] T128 [US4] `TEST/Integration/AppContainerTests.swift`: que el contenedor resuelve las fábricas
      nuevas y **no dispara efectos de arranque** al construirse.

**Checkpoint**: ninguna acción visible deja sin respuesta, y la estructura de navegación queda
fijada para las features siguientes.

---

## Phase 7: Cierre y puertas de calidad

**Purpose**: dejar los documentos coherentes, atravesar la frontera real y anotar las cifras.

- [ ] T129 **SC-010** Revisar la pantalla con el tamaño de letra del sistema al **200 %**: las
      tarjetas crecen y no se recorta el organismo, el título ni la fecha, y la posición de lectura
      no se pierde (**FR-044**). **Se mira la pantalla, no el código**: así se descubrió que el
      botón principal era invisible sobre la portada.
- [ ] T130 Comprobar las tres trampas que en Android solo aparecieron en el dispositivo: que el
      organismo **no salga dos veces** en la tarjeta, que no haya un hueco de área segura sobre el
      escudo, y que el panel no tenga un tinte que no es suyo. Ninguna prueba de esta casa las ve.
- [ ] T131 **FR-081** `docs/diseno/especificaciones-diseno.md`: anotar las desviaciones propias de
      iOS con su fecha y su motivo —tres destinos mientras no existan los avisos, y la tarjeta de
      alertas del panel en suspenso—, y **corregir los apartados 32 y 36**, que siguen
      transcribiendo el microcopy y el checklist que las enmiendas de 14.4 y 16 dejaron sin efecto.
- [ ] T132 `CLAUDE.md`: retirar la **013** del orden de portado explicando por qué se absorbe, y
      añadir las trampas nuevas: el aislamiento por defecto que ya no salta al pool, el delegado
      débil del analizador, el texto que llega troceado, el booleano de `parse()`, el panel siempre
      montado en el árbol de accesibilidad, y la cadena SQL que el motor de reglas no ve.
- [ ] T133 `README.md`: la tabla de estado se quedó en la 001 —dice «Esqueleto de arquitectura» y
      «58 sin interfaz · 6 de interfaz»—. Ponerla al día con las cifras de esta feature.
- [ ] T134 **FR-088, SC-013 · Paso 13 del quickstart**: contraste contra el servicio real. Anotar
      **con cifras**: fuentes que respondieron, publicaciones recibidas, aceptadas, rechazadas con
      su motivo, sin identificador en el enlace, con clasificación que no corresponde, **con orden
      anómalo** —en Android fueron ocho, todas del feed 4.3— e identificadores repetidos. Es lo
      único que mira al otro lado de la frontera.
- [ ] T135 **SC-001, SC-002** Medir y **anotar las dos cifras de rendimiento**: con contenido
      guardado, cuánto tarda Inicio en mostrar publicaciones desde que la pantalla aparece —objetivo,
      menos de 1 s, con y sin conexión—; y en instalación limpia con conexión, cuánto tarda el
      boletín del día desde el toque —objetivo, menos de 15 s—. La constitución pide cifras, no
      recorridos: recorrerlo en el quickstart no basta.
- [ ] T136 **D-329** Volver a medir el arranque con `XCTApplicationLaunchMetric`, cinco tomas, y
      anotar la cifra junto a los **815 ms** anteriores. Esta feature mete abrir un fichero y
      migrarlo en ese camino. «Sigue bien» no es una cifra.

### Las cuatro puertas

**SC-014.** No hay CI, por la constitución 1.1.0: se ejecutan aquí y **el resultado se anota con
cifras**.

- [ ] T137 Puerta 1 · Construcción: `xcodebuild ... -quiet build` → **anotar el tiempo**
- [ ] T138 Puerta 2 · Pruebas sin interfaz: `-only-testing:BOCantabria-iosTests` → **anotar número
      de pruebas, de suites, tiempo y el delta** respecto a las 116 de partida
- [ ] T139 Puerta 3 · Pruebas de interfaz: `-testPlan UITests` → **anotar número y tiempo**, y el
      delta respecto a las 16 de partida. Con `-testPlan`, **nunca** con `-only-testing` sobre el
      target de interfaz
- [ ] T140 Puerta 4 · Sin avisos nuevos: `grep -c "warning:"` → **anotar la cifra**. El único
      admisible es el preexistente de `appintentsmetadataprocessor`, que es de Apple

---

## Dependencies & Execution Order

### Entre fases

- **Setup (1)**: sin dependencias. T006 depende de T005; T007 de T001.
- **Foundational (2)**: depende de Setup. **Bloquea las cuatro historias.** Dentro de ella, el
  bloque T040…T047 es **indivisible**: entre medias el árbol no compila.
- **US1 (3)**: depende de Foundational. Es el MVP.
- **US2 (4)**: depende de US1 y comparte con ella `HomeViewModel`, `HomeContentView` y
  `PublicationRepositoryImpl`, así que **no se paraleliza** con ella.
- **US3 (5)**: depende de US1 —necesita contenido que explorar— y toca `HomeViewModel` otra vez.
- **US4 (6)**: depende de que exista `MainView`, que es donde vive el panel de US3.
- **Cierre (7)**: depende de todo lo anterior.

Al contrario que en una aplicación con historias verdaderamente aisladas, aquí las cuatro comparten
**una sola pantalla**. Por eso van en orden y no en paralelo, y por eso cada checkpoint es una
demostración y no un hito administrativo.

### Dentro de cada historia

- La prueba de una pieza va **con** la pieza, no al final.
- Dominio antes que datos; datos antes que presentación; presentación antes que interfaz.
- Ninguna tarea se cierra con su prueba en rojo, y **prohibido** `.disabled`.

### Paralelismo real

```bash
# Phase 1, tras T001:
T002 (cadenas) · T003 (plural y meses) · T004 (Strings) · T005 (colores)

# Phase 2, los modelos de dominio y sus pruebas:
T008+T009 (BocDate) · T010 (facetas) · T011+T012 (Publication) · T013+T014 (BocSection)
T015+T016 (HomeSelection) · T017 (cabecera) · T018+T019 (resumen)

# Phase 2, las costuras, tras los modelos:
T029 (aleatoriedad) · T030+T031 (formato) · T032+T033 (motor de reglas)

# Phase 3, las vistas sin estado, tras el estado de pantalla:
T078 (tarjeta) · T079 (esqueleto) · T080 (cabecera) · T081 (barra superior)
```

---

## Implementation Strategy

### MVP primero

1. Phase 1 y Phase 2 completas. **No pasar de T047 con el árbol roto.**
2. Phase 3 (US1): la aplicación lee el BOC de verdad y lo pinta.
3. **Parar y validar**: pasos 6 y 11 del quickstart, y una primera pasada del 13.

### Entrega incremental

1. Base lista → US1 → **MVP demostrable**.
2. + US2 → la aplicación sirve sin cobertura, que es lo que justifica guardar.
3. + US3 → el corpus del BOC es navegable.
4. + US4 → la estructura de navegación queda fijada.
5. Cierre, contraste real y las cuatro puertas.

### Riesgos anotados

- **La pieza con más incógnita es el panel** (T106…T111): no hay componente del sistema y hay que
  reponer a mano lo que una hoja nativa daría gratis.
- **El punto de corte natural** de la feature está entre US2 y US3. Si hubiera que partir la
  entrega, US1 + US2 ya son una aplicación que sirve.
- **El bloque T040…T047 es el más delicado**: veinticinco ficheros y el árbol roto en medio. Se hace
  de una sentada.

### Integración

Cuando las cuatro puertas estén en verde, la feature está **terminada**, no integrada. El merge
`--no-ff` sobre `main` lo pide el propietario, y la rama **se conserva**.

---

## Notes

- `[P]` = ficheros distintos y sin dependencias entre sí.
- `HomeViewModel` y `HomeContentView` se tocan desde tres historias. Están sin `[P]` a propósito.
- Las cifras de las puertas se escriben en T137…T140. **Un «pasa» no vale**: es lo único que después
  permite saber si se ejecutaron.
- Las diez muestras XML **ya están** en `TEST/Fixtures/` desde la 001, y los cincuenta y dos iconos
  también. No se dibuja ninguno nuevo ni se descarga ninguna muestra. Y viajan **solo en el bundle de
  pruebas**: el sembrador de escenarios no puede leerlas, por eso sintetiza en código (**D-322**).
- El bloque T040…T047 **no se apoya en ningún requisito funcional**: su justificación está en las
  suposiciones de la especificación —«la rodaja vertical de relleno de la feature 001 se retira»—. Se
  anota para que nadie lo lea como un grupo de tareas huérfanas.
