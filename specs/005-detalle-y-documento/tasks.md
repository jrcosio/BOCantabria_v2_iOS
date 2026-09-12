# Tasks: Del titular al documento oficial

**Input**: Documentos de diseño en `specs/005-detalle-y-documento/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: **OBLIGATORIOS.** El principio V de la constitución los declara no negociables y la
especificación los exige en FR-053 … FR-058. La prueba de una pieza se escribe **con** la pieza y
ninguna tarea se da por terminada sin su prueba en verde. **Prohibido** `.disabled`, comentar o borrar
una prueba para que pase la build.

**Organization**: cuatro historias. Las dos P1 son inseparables en el código y separables en la
entrega: la 1 es «se puede leer el boletín» y la 2 es «y si falla, se nota». Ver *Implementation
Strategy*.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizable (ficheros distintos, sin dependencias entre sí)
- **[Story]**: a qué historia pertenece
- Las rutas son exactas y relativas a la raíz del repositorio

**Abreviaturas**: `APP/` = `BOCantabria-ios/` · `TEST/` = `BOCantabria-iosTests/` ·
`UITEST/` = `BOCantabria-iosUITests/` · `DOC/` = `docs/diseno/especificaciones-diseno.md`

---

## Phase 1: Setup

**Purpose**: dejar constancia del punto de partida y preparar lo que no depende de nada. **Las dos
cosas que esta feature tiene que demostrar al final son diferencias** —el árbol de accesibilidad y las
cifras—, y una diferencia sin el antes no significa nada.

- [X] T001 Medir y anotar aquí mismo las **cifras de las cuatro puertas ANTES del cambio**, sobre la
      rama `005-detalle-y-documento` sin tocar, con datos derivados en `/tmp/boc-dd005`:

      | Puerta | Antes | Al cerrar la 004 |
      |---|---|---|
      | 1 · Construcción | **30,8 s**, 0 errores | 26 s, 0 errores |
      | 2 · Pruebas sin interfaz | **285 pruebas en 41 suites, 0,515 s** | 285 en 41, 0,494 s |
      | 3 · Pruebas de interfaz | **42 pruebas en 317,3 s**, 0 fallos | 42 pruebas, 322 s |
      | 4 · Avisos | **1**, el ajeno de `appintentsmetadataprocessor` | 1, el mismo |

      Las tres cifras de pruebas y la de avisos **coinciden con el cierre de la 004** dentro del
      ruido de una ejecución a otra, que es lo que había que comprobar: se parte de donde se dijo
      que se partía. La construcción sale 4,8 s más lenta
      porque los datos derivados eran nuevos y recompiló Firebase entero; las 26 s de la 004 eran
      incrementales, así que **las dos cifras no son comparables** y la que vale como referencia es
      la de T076, medida del mismo modo.

      **Dos notas de método, las dos aprendidas aquí**: el recuento de avisos se mide **sin
      `-quiet`**, porque con él no se imprimen; y la duración de las pruebas también, porque `-quiet`
      oculta la línea «Test run with N tests in M suites passed after X seconds» y deja solo el
      reloj de pared, que incluye el arranque del simulador y no es la misma medida.
- [X] T002 Volcar el **árbol de accesibilidad de Inicio antes del cambio** a
      `/tmp/boc-005-tree-antes.txt`: `print(app.debugDescription)` temporal en
      `UITEST/Home/HomeStatesUITests.swift`, ejecutar esa sola prueba con `-boc-data-scenario=today`,
      y retirar el `print`. Es **contra esto** contra lo que se compara en T075, y es el riesgo número
      uno de la feature (**D-519**, quickstart paso 3)
- [X] T003 [P] Añadir las **32 claves** de `contracts/internal-contracts.md` §6 a
      `APP/Localizable.xcstrings`, con los valores literales de
      `docs/referencia-android/res/strings.xml`, y sus enums `Detail`, `PdfViewer`, `Share` y `Ask` en
      `APP/Core/UI/Strings.swift` (FR-047)
- [X] T004 [P] Añadir las muestras de documento a `TEST/Fixtures/`: `documento_valido.pdf`,
      `documento_dos_paginas.pdf`, `documento_protegido.pdf` (contraseña **de usuario**, no de
      propietario), `documento_truncado.pdf`, `pagina_error.html` y `declarado_pdf_no_lo_es.bin`; y
      un `enum PdfFixture` hermano en `TEST/Fixtures/FixtureLoader.swift`. **No se toca el enum de
      XML existente.** Para el tope de tamaño **no hay muestra**: los bytes los genera el doble
- [X] T005 [P] Comprobar que **no falta ningún icono**: los seis que la feature de origen añadió
      —`arrow_back`, `account_balance`, `verified_user`, `auto_awesome`, `chat_bubble`,
      `description`— están ya como `ic_arrow_back`, `ic_organization`, `ic_official`, `ic_ai`,
      `ic_ask` e `ic_document`. Si alguno faltara, se regenera con `Tools/vector-drawable-to-svg.py`.
      **Nada de SF Symbols** (FR-047)

**Checkpoint**: las cifras y el árbol de partida anotados; textos, muestras e iconos disponibles.

---

## Phase 2: Foundational

**Purpose**: lo que bloquea a las cuatro historias. Al acabar esta fase **nada se ve todavía**, pero
el dominio existe, el contenedor lo resuelve y las dos reglas nuevas ya pueden ponerse rojas.

**⚠️ Ninguna historia puede empezar hasta que esta fase esté completa.**

- [X] T006 [P] Crear `APP/Domain/Model/OfficialDocument.swift` con `unknownChecksum` e
      `isValidChecksum(_:)`, y su prueba `TEST/Domain/OfficialDocumentTests.swift`. **La prueba de
      `isValidChecksum` es la que protege FR-024**: 64 hex válido; vacío, 63, 65, mayúsculas, con
      espacios y con un carácter no hexadecimal, todos inválidos (data-model.md §2)
- [X] T007 [P] Crear `APP/Domain/Model/DocumentStatus.swift` con `isTerminal`, y
      `TEST/Domain/DocumentStatusTests.swift`: **`downloading` es el único no terminal**
- [X] T008 [P] Crear `APP/Domain/Model/ShareTarget.swift` (con `LinkReason`) y
      `APP/Domain/Model/SharedDocument.swift`, con sus pruebas. `LinkReason` tiene **un solo caso** a
      propósito (FR-040)
- [X] T009 [P] Crear `APP/Domain/Model/DetailTab.swift` con `restored(from:)` **por nombre y con
      respaldo**, y `TEST/Domain/DetailTabTests.swift`, que incluye el valor retirado `"ask"` → debe
      devolver `.document`, no tumbar nada (FR-017)
- [X] T010 Crear `APP/Domain/Repository/DocumentRepository.swift` y ampliar
      `APP/Domain/Repository/PublicationRepository.swift` con `observePublication(externalKey:)`
      (FR-002, FR-003, FR-004, D-512)
- [X] T011 [P] Crear los cuatro casos de uso en `APP/Domain/UseCase/` con su único `callAsFunction`, y
      sus cuatro pruebas en `TEST/Domain/` (depende de T010)
- [X] T012 Añadir `publication(externalKey:in:)` a `APP/Data/Source/Local/PublicationQueries.swift` y
      su observación a `APP/Data/Source/Local/PublicationLocalDataSource.swift`; ampliar
      `TEST/Data/PublicationQueriesTests.swift`. **Es una consulta de LECTURA**: si la tarea acaba
      escribiendo, algo se ha desviado (FR-002)
- [X] T013 Implementar `observePublication` en `APP/Data/Repository/PublicationRepositoryImpl.swift`,
      con su prueba: la fila ausente emite `.success(nil)`, **no** un fallo (depende de T012)
- [X] T014 Añadir `case pdfViewer(externalKey:)` y `case ask(externalKey:)` a
      `APP/UI/Navigation/Route.swift`. Las tres viajan **por clave** (contracts §4.4)
- [X] T015 [P] Crear `APP/Core/UI/Theme/BocUIColors.swift` con los pocos colores de UIKit que la
      interoperabilidad necesita, y ampliar `TEST/Core/BocThemeTests.swift` afirmando que coinciden
      con sus tokens. **Va en el tema porque la regla 7 falla la build en cualquier otro sitio**
      (D-522)
- [X] T016 [P] Añadir `document_opened` y `document_share` a
      `APP/Core/Telemetry/AnalyticsEvent.swift` y ampliar `TEST/Core/AnalyticsEventTests.swift`.
      **Solo banderas y enumerados**: ni título, ni dirección, ni clave, ni nombre de fichero (FR-047,
      principio VI)
- [X] T017 [P] Añadir el hito `timeToDocument` a `APP/Core/Util/AppSignposts.swift`. Es lo que mide
      SC-002 y SC-003; **XCUITest no sabe medir por debajo del segundo** (D-525)
- [X] T018 **Escribir la regla 14** en `TEST/Architecture/ArchitectureRulesTests.swift` —importaciones
      **y** referencias por nombre, como la 10— y su prueba en
      `TEST/Architecture/SourceTreeTests.swift`. Subir «Nueve reglas» de la cabecera a **catorce**.
      **Provocar la violación a mano por las dos mitades y verla roja** antes de seguir (FR-052, SC-014,
      D-521, quickstart paso 2)
- [X] T019 **Arreglar FR-051**: en `APP/UI/Main/MainView.swift`, el modelo de pantalla de Inicio pasa
      a construirse en el inicializador y a vivir en `@State`, como el del propio armazón. Ampliar
      `TEST/UI/MainViewModelTests.swift` con la **prueba de regresión**: un espía de analítica cuenta
      **exactamente una** visita de `home` tras varios redibujados. La prueba debe fallar **antes**
      del arreglo (D-523)
- [ ] T020 Registrar en `APP/Core/DI/AppContainer.swift` el descargador, la caché, el almacén, el
      repositorio de documentos, los cuatro casos de uso y los dos modelos de pantalla nuevos; y
      ampliar `TEST/Integration/AppContainerTests.swift`. **El almacén y la caché son compartidos de
      proceso; los modelos de pantalla, nuevos en cada llamada.** Construir el contenedor **no** puede
      tocar el sistema de ficheros (depende de T010, T011)

      > **Corrección de orden, anotada al implementar.** Esta tarea está escrita en la fase
      > *Foundational* y **no puede ejecutarse ahí**: registra el descargador, la caché, el almacén,
      > el repositorio y los dos modelos de pantalla, y esas seis piezas no existen hasta T022, T024,
      > T026, T027, T030 y T034. Su «depende de T010, T011» era incompleto, y el análisis de
      > coherencia no lo cazó porque solo comprobaba las dependencias **declaradas**.
      >
      > Se ejecuta **después de T034**. No se mueve de sitio en el documento: la fase 2 existe para
      > decir qué desbloquea a las historias, y el contenedor lo hace — lo que estaba mal era suponer
      > que se podía cablear antes de que hubiera algo que cablear.

**Checkpoint**: el dominio existe y está probado, el grafo lo resuelve, la regla 14 se pone roja
cuando debe y el defecto de la visita espuria está corregido con su regresión.

---

## Phase 3: User Story 1 — Abrir una publicación y leer el documento oficial (Priority: P1)

**Goal**: del titular al documento, dentro de la aplicación.

**Independent Test**: abrir el boletín con `-boc-data-scenario=documentReady`, tocar una tarjeta,
comprobar la cabecera y sus datos, abrir el documento y retroceder al mismo sitio.

### La máquina del documento

- [ ] T021 [P] [US1] Escribir `TEST/Data/HttpDocumentDownloaderTests.swift` con el **camino feliz**,
      sustituyendo el protocolo de red: respuesta correcta → `downloaded` con el recuento y la huella
      exactos de `documento_valido.pdf`. Los rechazos llegan en T041 (FR-053)
- [ ] T022 [US1] Crear `APP/Data/Source/Remote/DocumentDownloader.swift` (protocolo, resultado y
      motivos de rechazo) y `APP/Data/Source/Remote/HttpDocumentDownloader.swift` hasta hacer pasar
      T021. **En trozos de 64 KiB a `FileHandle`, con la huella al vuelo**: nunca más de 64 KiB en
      memoria. **Un solo intento.** Host `boc.cantabria.es`, que **no es** el de los feeds (D-502,
      D-503, D-504)
- [ ] T023 [P] [US1] Escribir `TEST/Data/FileDocumentCacheTests.swift` sobre un directorio temporal:
      guardar y recuperar; el `.part` no es visible; **lateral ausente, vacío, truncado y en
      mayúsculas → `unknownChecksum` y el documento se sirve**; retirada por antigüedad con **reloj
      inyectado**; retirada por tope; y que **la clave en uso no se retira** (FR-054)
- [ ] T024 [US1] Crear `APP/Data/Source/Local/DocumentCache.swift` y
      `APP/Data/Source/Local/FileDocumentCache.swift` hasta hacer pasar T023. **Guarda la huella** (FR-022) y es **caché, no biblioteca** (FR-030). **El orden de `commit`
      es el requisito**: lateral `.part` → renombrar lateral → renombrar documento → si falla, borrar
      el lateral. El nombre sale de una **huella de la clave**, nunca de la clave (FR-021, FR-023,
      D-505, D-506)
- [ ] T025 [P] [US1] Escribir `TEST/Data/DocumentStoreTests.swift` con lo que US1 necesita: pedir dos
      veces reutiliza la copia sin descargar otra vez, y **un observador que llega tarde ve
      `available` de inmediato** — ésta es la que protege el cuelgue silencioso de **D-510**. La
      coalescencia y los caminos de error llegan en T042 y T043 (FR-025)
- [ ] T026 [US1] Crear `APP/Data/Repository/DocumentStore.swift` hasta hacer pasar T025. **El trabajo
      en vuelo se tipa `Task<AppResult<OfficialDocument>, Never>`**, y va anotado en el fichero por
      qué: con `Error` vuelve entero el defecto de STAB-002 (**D-507**). La difusión es un diccionario
      de continuaciones con **reproducción del valor vigente** y política «el más nuevo, uno» (D-510,
      D-511)
- [ ] T027 [US1] Crear `APP/Data/Repository/DocumentRepositoryImpl.swift` sobre el almacén, con su
      prueba, y emitir `document_opened` con la bandera de caché (depende de T022, T024, T026)

### El visor

- [ ] T028 [P] [US1] Escribir `TEST/UI/PdfViewerViewModelTests.swift`: cargando → listo con el número
      de páginas de `documento_dos_paginas.pdf`; y los dos errores, con `documento_protegido.pdf` y
      `documento_truncado.pdf`, que **no** son el mismo caso (FR-035, FR-036, FR-056)
- [ ] T029 [US1] Crear `APP/UI/PDF/PdfDocumentProbe.swift` marcado **`@concurrent`**, con los cuatro
      desenlaces de la tabla de **D-514**. Un documento **cifrado pero no bloqueado se abre**:
      rechazarlo mutilaría documentos oficiales legítimos
- [ ] T030 [US1] Crear `APP/UI/PDF/PdfViewerUiState.swift` y `APP/UI/PDF/PdfViewerViewModel.swift`
      hasta hacer pasar T028. **Ni `PDFDocument` ni `PDFPage` en el estado**: no son `Sendable` y no
      compilarían (depende de T029)
- [ ] T031 [US1] Crear `APP/UI/PDF/PdfDocumentView.swift`, el envoltorio sobre la vista de PDFKit, con
      el fondo `readerSurface`, sin sombras de página, desplazamiento continuo vertical y ajuste
      automático: se lee **dentro de la aplicación** y se amplía y recorre con los gestos habituales
      (FR-031, FR-032). **El factor mínimo se fija DESPUÉS de asignar el documento**: antes vale cero y el
      pellizco deja reducirlo a nada (D-515)
- [ ] T032 [US1] Crear `APP/UI/PDF/PdfViewerContentView.swift` y `APP/UI/PDF/PdfViewerView.swift` con
      la barra del apartado 24.1 —**tres** controles: atrás, título abreviado y compartir— y la página
      visible en almacenamiento de escena. El título abreviado es `titleWithoutIssuer` (FR-033, FR-034)

### El detalle

- [ ] T033 [P] [US1] Escribir `TEST/UI/PublicationDetailViewModelTests.swift` para US1: la publicación
      observada se publica en el estado; un cambio posterior se refleja **sin volver a entrar**
      (FR-003); `nil` pone `isMissing` (FR-004); y **el documento se pide en `onDocumentTabShown()`,
      no en `onAppear()`** (FR-016, FR-056)
- [ ] T034 [US1] Crear `APP/UI/Detail/PublicationDetailUiState.swift` y
      `APP/UI/Detail/PublicationDetailViewModel.swift` hasta hacer pasar T033. `document` y `share`
      van **fuera** de un enumerado único: son ejes ortogonales (data-model.md §6.1)
- [ ] T035 [P] [US1] Crear `APP/UI/Detail/Component/DetailHeader.swift` con los cinco elementos **en
      el orden de FR-007**: sección, **título**, organismo, fecha, distintivo. El título en
      `headlineSmall`, **completo y sin recortar**, y con el organismo incluido si lo trae (FR-008).
      El organismo y la fecha, **cada uno con su icono** (FR-009). Sin hueco cuando no hay organismo (FR-010)
- [ ] T036 [P] [US1] Crear `APP/UI/Detail/Component/DetailTabBar.swift` según el apartado 11.7: alto
      56, indicador inferior de 3, activa en `primary`. El icono de IA en la segunda (FR-014)
- [ ] T037 [P] [US1] Crear `APP/UI/Detail/Component/MetadataCard.swift` con los **seis bloques** del
      apartado 19.2 en su orden, etiquetas en `labelMedium` y valores en `bodyLarge` (FR-015)
- [ ] T038 [US1] Crear `APP/UI/PDF/PdfPageRenderer.swift` marcado **`@concurrent`**, con la escala **por
      parámetro** y tope de píxeles, y `APP/UI/PDF/DocumentFirstPagePreview.swift`, que es lo que el
      detalle embebe —**no una imagen**, para que ningún tipo de PDFKit salga de la carpeta—. Y
      `TEST/UI/PdfPageRendererTests.swift` con **la prueba que afirma desde el actor principal que la
      rasterización NO ocurre en él**: sin ella, `@concurrent` es una convención (D-516)
- [ ] T039 [US1] Crear `APP/UI/Detail/PublicationDetailContentView.swift` y
      `APP/UI/Detail/PublicationDetailView.swift`, con la barra superior del apartado 18.1
      —retroceso, escudo, título, guardar y compartir (FR-013)— y **la
      cabecera dentro del desplazamiento y las pestañas como encabezado fijado** (FR-011). Fondo
      opaco y divisor bajo las pestañas (FR-012), **orden de dibujado explícito** para que el
      contenido perezoso no se pinte encima, y **una sola sección** con el contenido conmutado dentro
      (D-520). Los identificadores, los de `contracts` §4.3 (depende de T034 … T038)
- [ ] T040 [US1] Hacer que **la tarjeta abra el detalle**: `APP/Core/UI/Component/PublicationCard.swift`
      gana `onOpen` con **forma de contacto, gesto de toque, rasgo de botón y acción de
      accesibilidad** —**no** un enlace de navegación (**D-519**)—;
      `APP/UI/Home/HomeContentView.swift` y `APP/UI/Home/HomeView.swift` lo propagan; y
      `APP/UI/Main/MainView.swift` monta la pila con los tres destinos y
      `.toolbar(.hidden, for: .tabBar)` (FR-001, FR-005, FR-006) (depende de T014, T019, T039)

**Checkpoint**: se llega al documento y se lee. **Parar y mirarlo** —quickstart pasos 4 y 9— antes de
seguir.

---

## Phase 4: User Story 2 — Que el documento sea de fiar, y que fallar se note (Priority: P1)

**Goal**: nada se presenta como oficial sin comprobarlo, y ningún fallo deja la pantalla cargando.

**Independent Test**: los tres escenarios de rechazo más el disco en solo lectura; en los cuatro, un
mensaje comprensible con reintento y **nunca** un estado de carga perpetuo.

- [ ] T041 [US2] Ampliar `TEST/Data/HttpDocumentDownloaderTests.swift` con **los nueve rechazos** de
      `contracts` §3.1, en su orden: esquema, host, **host del destino final tras una redirección**,
      estado HTTP, tipo declarado, longitud declarada, bytes mágicos con `pagina_error.html` y
      `declarado_pdf_no_lo_es.bin`, tope contando mientras llega, y fallo de escritura. **Cada uno
      comprueba además que no queda ningún fichero** (FR-018, FR-019, FR-020, FR-021, FR-053, SC-004, SC-005)
- [ ] T042 [US2] Ampliar `TEST/Data/DocumentStoreTests.swift` con la **coalescencia**: dos peticiones
      simultáneas de la misma clave producen **una** descarga, con un doble contador que la prueba
      libera (FR-026) —**nada de esperas por tiempo**, que convierten la prueba en una carrera—; y **quien
      espera no hereda la cancelación del que inició**, que es FR-028 (D-507, D-508)
- [ ] T043 [US2] Ampliar `TEST/Data/DocumentStoreTests.swift` con **el estado terminal para cada
      camino**, parametrizada con un `struct` de caso —**no con tuplas de cuatro**, que hacen explotar
      al comprobador de tipos—: rechazo por tipo, por bytes, por tope, HTTP 500, fallo de escritura,
      fallo al guardar y cancelación. Aserción única: el último estado es terminal. **Y que cancelar
      publica `absent`, nunca `failed`** (FR-027, FR-029, SC-006)
- [ ] T044 [US2] Cerrar `APP/Data/Repository/DocumentStore.swift` contra T042 y T043: recuento de espectadores, guardián de
      identidad al publicar `absent`, y **`settle()` síncrona y aislada al actor**, con el comentario
      que prohíbe meter un `await` dentro (D-508, D-509)
- [ ] T045 [P] [US2] Ampliar `TEST/UI/PublicationDetailViewModelTests.swift` y
      `TEST/UI/PdfViewerViewModelTests.swift` con los estados de error y el reintento (FR-025)
- [ ] T046 [P] [US2] Crear `APP/UI/Detail/Component/MissingPublication.swift` —título, explicación y
      «Volver al boletín»— y conectar el estado de error del detalle y del visor **al componente de
      error común**: el error del visor **no** puede tener estilo propio (FR-004, FR-025, apartado 34)
- [ ] T047 [US2] Comprobar que **todo `catch` de la feature informa por `CrashReporter.log`**, con la
      fase y el tipo de fallo y **nunca** el título, la dirección, la clave ni el nombre de fichero.
      Ampliar `TEST/Data/DocumentRepositoryImplTests.swift` con un espía que lo afirme (FR-024,
      principio VI)
- [ ] T048 [US2] Escribir `TEST/Integration/DocumentFlowIntegrationTests.swift` con el grafo real y
      dobles **solo en la frontera de red**: camino feliz completo; rechazo que no deja restos; **copia
      con lateral vacío que se sirve igual**; y la retirada de la caché que devuelve el estado a
      `absent` (FR-054, FR-055, SC-007)
- [ ] T049 [US2] Añadir los cuatro casos a `DataScenario` en
      `APP/Data/Sync/ScenarioDatabaseSeeder.swift` —`documentReady`, `documentRejected`,
      `documentTooLarge`, `documentUnavailable`—, crear
      `APP/Data/Source/Remote/ScenarioDocumentDownloader.swift` con **el documento sintetizado en
      código** —el bundle de pruebas no lo ve el proceso de la aplicación— y sustituirlo en
      `AppContainer` en el mismo sitio y con la misma forma que el descargador de feeds. **Sin tercer
      argumento de lanzamiento** (D-524)
- [ ] T050 [P] [US2] Escribir `UITEST/Detail/DetailStatesUITests.swift`: los tres escenarios de
      rechazo y, en los tres, **mensaje con reintento y nunca un estado de carga perpetuo** (FR-057,
      SC-006) (depende de T049)

**Checkpoint**: la desconfianza está probada y ningún camino deja la pantalla colgada.

---

## Phase 5: User Story 3 — Compartir el documento, no el enlace (Priority: P2)

**Goal**: sale el documento; y cuando no puede, sale el enlace con su explicación.

**Independent Test**: compartir desde las tres pantallas con el documento en caché, sin él con
conexión, y sin él en modo avión.

- [ ] T051 [P] [US3] Escribir `TEST/Domain/ShareOfficialDocumentUseCaseTests.swift`: en caché →
      documento; sin caché con conexión → documento; sin caché sin conexión → enlace con
      `noConnection`; y **un fallo que no sea la falta de conexión NO devuelve enlace**. **Nunca deja sin nada** (FR-037,
      FR-040, SC-009)
- [ ] T052 [US3] Crear `APP/Domain/UseCase/ShareOfficialDocumentUseCase.swift` hasta hacer pasar T051.
      Es **el único sitio** donde vive la regla de degradación (FR-041)
- [ ] T053 [US3] Crear `APP/UI/Share/SharedDocumentTransfer.swift`: el tipo transferible con
      exportación de fichero de **cierre asíncrono** —es lo que da el «preparando» sin escribir una
      pantalla de UIKit—, `allowAccessingOriginalFile` en **falso** —la caché puede vaciarse con la
      hoja abierta— y **nombre de fichero sugerido legible**, nunca la huella (FR-039, FR-042, D-517)
- [ ] T054 [US3] Conectar compartir en `APP/UI/Detail/PublicationDetailViewModel.swift`,
      `APP/UI/Detail/PublicationDetailContentView.swift` y `APP/UI/PDF/PdfViewerContentView.swift`,
      con `ShareState` como **evento de un solo uso**, y emitir `document_share` con el destino (FR-037, FR-038) (depende de T052, T053)
- [ ] T055 [US3] **Sustituir** el compartir por enlace de `APP/Core/UI/Component/PublicationCard.swift`
      por el destino que llega como parámetro, derivado en `APP/UI/Home/HomeContentView.swift` de
      `state.isOffline`. La tarjeta **sigue sin estado**. Anotar en el fichero la contrapartida
      aceptada: sin conexión pero con el documento en caché, la tarjeta ofrece el enlace (D-518)
- [ ] T056 [P] [US3] Ampliar `TEST/UI/PublicationDetailViewModelTests.swift` con `ShareState`:
      `idle` → `preparing` → `ready`, y que **se consume y vuelve a `idle`**

**Checkpoint**: las tres historias entregables funcionan por separado.

---

## Phase 6: User Story 4 — Saber qué llegará y no toparse con callejones (Priority: P3)

**Goal**: lo que no existe todavía lo dice, y conserva su sitio.

**Independent Test**: recorrer las dos pestañas y las tres acciones aplazadas sin quedarse sin
respuesta.

- [ ] T057 [P] [US4] Conectar la segunda pestaña de
      `APP/UI/Detail/PublicationDetailContentView.swift` a `ComingSoonMessage` conservando **el icono y la
      etiqueta de IA**, con `aiAccent` y `aiContainer`, que ya existen sin usar (FR-043, FR-048)
- [ ] T058 [P] [US4] Crear `APP/UI/Ask/AskView.swift`: barra del apartado 21.1 y el aviso de
      próximamente. **Pantalla propia con su sitio en la pila**, no un diálogo (FR-044)
- [ ] T059 [US4] Crear `APP/UI/Detail/Component/DetailActionBar.swift` según el apartado 18.5: fondo
      `surface` con borde superior, «Abrir PDF oficial» **principal** y «Preguntar» secundario,
      **apilados si no caben**, y el margen inferior **dentro de su propia superficie** (FR-046,
      FR-049, FR-050)
- [ ] T060 [P] [US4] Conectar guardar a «Próximamente» en la barra superior de
      `APP/UI/Detail/PublicationDetailView.swift`, igual que la tarjeta ya hace (FR-045)
- [ ] T061 [P] [US4] Escribir `UITEST/Detail/DetailContentUITests.swift`: las dos pestañas con su
      contenido, la barra de acciones, y que ninguna acción aplazada deja sin respuesta (FR-057,
      SC-012)

**Checkpoint**: ninguna acción visible se queda callada.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T062 [P] Escribir `UITEST/Detail/DetailNavigationUITests.swift`: tarjeta → detalle → visor →
      dos retrocesos → **el boletín en la misma posición y sección**; y tarjeta → detalle →
      preguntar → retroceso (FR-001, FR-005, FR-057, SC-001)
- [ ] T063 [P] Escribir `UITEST/PDF/PdfViewerUITests.swift`: cargando, documento listo, y los **dos**
      errores distintos con su salida (FR-035, FR-036, FR-057)
- [ ] T064 [P] Ampliar `UITEST/Home/AccessibilityUITests.swift`: la tarjeta **abre** y sus dos
      controles siguen funcionando por separado; el alto de la tarjeta sigue creciendo al 200 %
      (FR-050)
- [ ] T065 [P] Ampliar `UITEST/PerformanceUITests.swift` con `timeToDocument` y anotar **SC-002 y
      SC-003 medidos**, no estimados. **Y la tercera fila**: cuánto tarda un documento de 25 MB —es lo
      que decide si D-502 se queda con la iteración byte a byte o pasa a descarga nativa a disco
      (D-525, quickstart paso 10)
- [ ] T066 Ejecutar en el **iPhone SE (3.ª generación)**, que hay que dar de alta con
      `xcrun simctl create`: la barra de acciones no tapa contenido ni queda bajo el área reservada, y
      sigue habiendo contenido desplazable con un título de ciento treinta caracteres (SC-011,
      quickstart paso 9)
- [ ] T067 Comprobar a mano el **tamaño de letra al 200 %**: el título completo sin recortar y los dos
      botones **apilados** (SC-010, quickstart paso 8)
- [ ] T068 Comprobar a mano **la copia dañada**: lateral vacío, truncado y ausente. En los tres, el
      documento se abre y **la aplicación no se cierra** (SC-007, quickstart paso 6)
- [ ] T069 Comprobar a mano **un documento de cincuenta páginas**: recorrerlo entero de arriba abajo
      con el monitor de memoria de Xcode delante. Ni la memoria del proceso se dispara ni la interfaz
      se bloquea al desplazar. **Es el único criterio de la especificación que ninguna prueba
      automática puede afirmar** (SC-008)
- [ ] T070 **Atravesar la frontera de verdad una vez**: abrir una publicación real con el registro
      delante y comprobar que las líneas dicen la fase, el tamaño y el motivo, **y que no dicen ni el
      título, ni la dirección, ni la clave** (quickstart paso 11)
- [ ] T071 [P] Enmendar `DOC/` **apartado 18.2**: sustituir la nota del 12 de septiembre que dice «se
      decide en la 005» por la decisión y su motivo —la cabecera se desplaza; en Inicio dice dónde
      estás y aquí dice qué es esto— (FR-011)
- [ ] T072 [P] Enmendar `DOC/` **apartado 18.3**: lo mismo con el orden de los datos, y por qué
      diverge del de la tarjeta (FR-007)
- [ ] T073 [P] Enmendar `DOC/` **apartado 36**: la lista de comprobación del detalle todavía dice
      «tres pestañas»
- [ ] T074 [P] Actualizar `CLAUDE.md`: «trece» reglas pasa a **catorce**; añadir a las trampas
      conocidas lo que esta feature ha aprendido —el tipo `Never` del trabajo en vuelo, la
      reproducción del estado al suscribirse, y el factor mínimo del visor fijado antes de tiempo—; y
      la tabla de orden de portado, si hace falta
- [ ] T075 **Volcar el árbol de accesibilidad DESPUÉS** y compararlo con `/tmp/boc-005-tree-antes.txt`.
      Lo único que puede haber cambiado es el rasgo de botón sobre la tarjeta. Si hay más, el
      mecanismo no es el de D-519 (quickstart paso 3)
- [ ] T076 Ejecutar las **cuatro puertas** y anotar sus cifras aquí, junto a las de T001. **Un «pasa»
      no vale** (SC-015). Comprobar de paso que **cada tipo de dominio y cada modelo de pantalla
      nuevos tienen su fichero de prueba**: lo exige SC-013, y **la regla 9 lo pone rojo sola** si
      alguno falta

      | Puerta | Antes (T001) | Después |
      |---|---|---|
      | 1 · Construcción | | |
      | 2 · Pruebas sin interfaz | | |
      | 3 · Pruebas de interfaz | | |
      | 4 · Avisos | | |

---

## Dependencies

```text
Phase 1 (Setup)  ──▶  Phase 2 (Foundational)  ──▶  US1  ──▶  US2  ──▶  US3
                                                     │                   │
                                                     └──────▶  US4  ◀────┘
                                                                   │
                                                                   ▼
                                                            Phase 7 (Polish)
```

- **US2 depende de US1** en el código —amplía el descargador y el almacén que US1 crea—, no en el
  valor: US1 ya es entregable.
- **US3 depende de US1** (necesita la copia local) y **no** de US2.
- **US4 no depende de nada** salvo de que exista la pantalla (T039). Podría adelantarse.

### Paralelizables

```text
T003 · T004 · T005                     (setup)
T006 · T007 · T008 · T009              (modelos de dominio)
T015 · T016 · T017                     (tema, telemetría, hitos)
T021 · T023 · T025                     (las tres pruebas de la máquina, ficheros distintos)
T035 · T036 · T037                     (componentes de la cabecera y las pestañas)
T045 · T046 · T050                     (errores)
T051 · T056                            (compartir)
T057 · T058 · T060 · T061              (aplazadas)
T062 · T063 · T064 · T065              (interfaz)
T071 · T072 · T073 · T074              (documentación — ¡OJO! T071-T073 son el MISMO fichero: NO se paralelizan entre sí)
```

**Corrección deliberada**: T071, T072 y T073 tocan `DOC/`, que es un solo fichero. Llevan `[P]`
respecto al resto de la fase, **no entre ellas**.

---

## Implementation Strategy

### MVP primero

1. **Fases 1 y 2 completas.** No se toca una pantalla antes de tener las cifras, el árbol de antes y
   la regla 14 poniéndose roja.
2. **US1 entera** → se puede leer el boletín. Es el MVP y **es demostrable solo**.
3. **US2** → y si falla, se nota. Es la que convierte la aplicación en fiable.
4. **US3** → compartir el documento.
5. **US4** → lo aplazado, dicho.

### Por qué las dos P1 no se funden

Se escriben seguidas y comparten ficheros, así que la tentación es tratarlas como una. Se mantienen
separadas por una razón práctica: **US1 termina en un checkpoint donde hay que parar y mirar la
pantalla**. La cabecera que se va, el encabezado que se queda, el factor mínimo del visor y el árbol
de accesibilidad son cuatro cosas que ninguna prueba ve y que, si están mal, están mal en todo lo que
venga después.

**Honestidad sobre el corte**: el descargador de T022 nace **con** su validación; no se escribe uno sin
comprobaciones para añadírselas luego. Lo que US2 aporta son **las pruebas que lo demuestran** —los
nueve rechazos, los siete caminos terminales— y **la presentación del fallo**. El código de US1 sin las
pruebas de US2 sería validación no verificada, que es exactamente lo que esta feature no puede
permitirse.

### Riesgos anotados

- **El más grave es T040**: la tarjeta. Ocho aserciones penden de su árbol y dos miden su alto y el
  marco de su acción de compartir. Por eso existen T002 y T075.
- **El más silencioso es T026**: si alguien tipa el trabajo en vuelo con `Error` en vez de `Never`,
  compila, pasa casi todas las pruebas y trae de vuelta un defecto que costó una feature entera
  encontrar allí. T042 es la que lo caza.
- **El que se salta la gente es T038**: la prueba de que la rasterización no ocurre en el actor
  principal. Sin ella, `@concurrent` es un adorno y el síntoma se diagnostica como «el visor es lento».
- **El que no tiene prueba es T031**: el factor mínimo fijado antes de asignar el documento. Se ve
  mirando la pantalla, no leyendo el código.
- **T049 abre un segundo eje** en el enumerado de escenarios. Con cuatro casos es aceptable; está
  anotado en D-524 para reconocerlo si aparece un tercero.

### Integración

Cuando las cuatro puertas estén en verde, la feature está **terminada, no integrada**. El merge
`--no-ff` sobre `main` lo pide el propietario, y la rama **se conserva**.

---

## Notes

- `[P]` = ficheros distintos y sin dependencias entre sí.
- **Ninguna prueba se silencia.** T019 y T018 ponen dos cosas en rojo a propósito, y se arreglan
  arreglando el código, no la prueba.
- **No se añade ninguna dependencia**, ninguna migración y ningún color, tamaño o espaciado fuera del
  tema. Si una tarea acaba necesitando uno, se para y se revisa el plan.
- `BocMigrations.swift`, `DomainError.swift` y `HomeUiState.swift` **no se tocan**.
