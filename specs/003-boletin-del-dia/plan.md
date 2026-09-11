# Implementation Plan: Boletín del día — lectura del BOC y pantalla de Inicio

**Branch**: `003-boletin-del-dia` | **Date**: 11 de septiembre de 2026 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-boletin-del-dia/spec.md`

## Summary

Dos mitades acopladas. Leer el Boletín Oficial de Cantabria de sus diecinueve fuentes oficiales,
normalizarlo y guardarlo; y dibujar lo guardado en Inicio, con su cabecera editorial, sus dos filas
de filtros, su panel lateral de secciones y el armazón de tres destinos.

El enfoque técnico es **una sola dirección de flujo y un solo escritor**. La sincronización escribe
en la base y **no devuelve publicaciones**: devuelve un resumen. La pantalla no la llama para
obtener datos, observa lo guardado. Así, «el almacenamiento local es la única procedencia de lo que
se muestra» deja de ser una convención que hay que recordar y pasa a ser la única forma en que las
piezas encajan: no hay ningún camino por el que un dato de red llegue a una vista.

Dentro de la sincronización, el mismo principio otra vez: diecinueve descargas concurrentes con un
tope de cuatro, pero **escribe el padre**. Los hijos descargan, analizan y normalizan —trabajo puro,
sin estado compartido— y devuelven valores; quien toca la base es siempre la misma tarea. Un solo
escritor hace que las diecinueve transacciones salgan ordenadas, que la observación emita hasta
diecinueve veces en lugar de solaparse, y que el invariante que la constitución protege —que **nunca
se borra una publicación**— tenga un solo sitio donde comprobarse.

La feature hereda la 001 y la 002 completas y **retira la rodaja de relleno** que la 001 dejó puesta
a propósito: `ContentItem` y toda su cadena, el origen de ejemplo y la costura que lo elegía. No se
añade al lado: la sustituye, en veinticinco ficheros.

## Technical Context

**Language/Version**: Swift 6.0 (modo de lenguaje 6, concurrencia estricta, aislamiento por defecto
`nonisolated`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`), Xcode 26.6

**Primary Dependencies**: SwiftUI · **GRDB 7.11.1**, que está enlazada desde el arranque del
proyecto y **se usa aquí por primera vez** · FirebaseAnalytics y FirebaseCrashlytics 12.19.1, ya en
uso. Del sistema se usan `Foundation` (`URLSession`, `XMLParser`, `UserDefaults`), `CryptoKit`
(SHA-256) y `OSLog`, que no son dependencias externas. **Esta feature no añade ninguna dependencia
nueva.**

**Storage**: GRDB sobre SQLite. Una base, `boc.db`, en `Application Support`, con dos tablas
—`publications` y `feed_sync_state`—, migrador versionado y WAL. Es la única procedencia de lo que
la pantalla muestra, observada con `ValueObservation` (D-301, D-302).

**Testing**: Swift Testing para unitarias e integración; XCUITest para interfaz. Los dos planes de
prueba existentes sirven sin cambios. Las diez muestras XML del servicio **ya están** en
`BOCantabria-iosTests/Fixtures/` desde la 001.

**Target Platform**: iOS 18.0 o superior, solo iPhone, solo vertical, apariencia clara fijada.

**Project Type**: aplicación móvil. Un único target, separación por carpetas.

**Performance Goals**: publicaciones a la vista en menos de 1 s con contenido guardado (SC-001);
boletín del día en menos de 15 s en instalación limpia (SC-002); el arranque sigue por debajo de 2 s
**y se vuelve a medir**, porque esta feature mete abrir un fichero y migrar en ese camino (D-305,
D-329).

**Constraints**: `Domain` sin dependencias de plataforma; pruebas deterministas sin red real, sin
reloj del sistema y **sin depender del idioma del dispositivo** (FR-087, D-316); ningún color,
tamaño ni espaciado literal fuera del tema; **ninguna sentencia borra una publicación guardada**, y
eso se demuestra ejecutando, no leyendo (D-324).

**Scale/Scope**: 19 fuentes, 9 secciones, 14 subsecciones, ~1.900 publicaciones en la primera
sincronización. 3 pantallas nuevas —dos de ellas marcadores—, 1 reescrita, 1 panel y 1 armazón.
Estimación: ~52 ficheros de producción nuevos, ~12 modificados, ~8 retirados y ~25 de prueba nuevos.

## Constitution Check

*GATE: comprobado antes de la investigación y vuelto a comprobar tras el diseño.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| **I. SDD obligatorio** | ✅ | La feature recorre el ciclo completo en su rama. Los requisitos se reutilizan de la 003 y la 013 de Android; sus diecisiete decisiones técnicas se revisaron una a una y **seis se descartaron por ser mecanismo de plataforma** —Room, OkHttp, el DOM de `javax.xml`, el desazucarado de `java.time`, Koin y el argumento de ruta— (research.md, cabecera) |
| **II. Arquitectura limpia** | ✅ | `Publication`, `BocSection`, `BocDate`, `HomeSelection`, `SyncSummary` y los cuatro enumerados son Swift puro. Los registros de GRDB **se mapean dentro del cierre de lectura** y no existen fuera de su fichero (D-304). Ningún tipo de GRDB aparece en un protocolo de `Domain`: la observación cruza como `AsyncStream<AppResult<[Publication]>>` (D-302). Lo comprueban las reglas 1 a 3 y la regla 10, nueva, que caza lo que las importaciones no ven |
| **III. MVVM** | ✅ | `HomeView` + `HomeViewModel` + `HomeUiState`, y `MainView` + `MainViewModel` + `MainUiState`, con vistas de contenido tontas y previsualizables. Los estados son enumerados inmutables y las banderas de refresco y de falta de conexión son **ejes independientes** del contenido, no casos del enumerado (D-331). El abierto/cerrado del panel es `@State` de la vista: es efímero y no sobrevive a nada (D-319) |
| **IV. Composition root** | ✅ | La base, el coordinador, los tres repositorios, el almacén de la selección, el reloj y la fuente de aleatoriedad se cablean en `AppContainer`, por inicializador y detrás de protocolos de `Domain`. Sin `@Environment` para nada de esto. La selección viaja de `MainView` a `HomeView` como `let`, que es estado de interfaz y no una dependencia (D-321) |
| **V. Testing exigente** | ✅ | Las tres capas. El tope de concurrencia, los reintentos y la caducidad de treinta minutos se verifican con **reloj y aleatoriedad controlables**, sin esperas reales (D-310, D-317). El invariante de «nunca se borra» se demuestra **recogiendo las sentencias que se ejecutan**, no leyendo el código (D-324). Cuatro tipos nuevos entran en la lista de exentos de la regla 9, declarados abajo |
| **VI. Observabilidad desacoplada** | ✅ | Ningún SDK sale de `Data`. A analítica van recuentos y el código de sección, que es un enumerado de veintitrés valores de un catálogo público; **nunca un título, un organismo ni una consulta** (D-327). El registro `OSLog` dice fase, número de fuentes, bytes y motivo del fallo, y nada más |
| **Restricciones tecnológicas** | ✅ | GRDB y URLSession, que son exactamente las dos que la constitución nombra, usadas aquí por primera vez y sin añadir ninguna. Sin Combine: `observation.values(in:)` ya es `AsyncSequence`. Sin `DispatchQueue` suelta: `actor`, `TaskGroup` y `@concurrent`. Sin Storyboards ni UIKit. Tema único claro, y las reglas 7 y 8 quedan intactas |

**Seis desviaciones, las seis declaradas** en *Complexity Tracking*. Ninguna toca un principio y
ninguna añade una dependencia.

## Project Structure

### Documentation (this feature)

```text
specs/003-boletin-del-dia/
├── plan.md              # Este fichero
├── research.md          # Decisiones D-300 … D-332
├── data-model.md        # Dominio, esquema, consultas y transiciones
├── quickstart.md        # Quince pasos de verificación
├── contracts/
│   └── internal-contracts.md
├── checklists/
│   └── requirements.md
├── spec.md
└── tasks.md             # Lo genera /speckit-tasks
```

### Source Code (repository root)

```text
BOCantabria-ios/
├── Core/
│   ├── DI/AppContainer.swift                          MODIFICADO  base, coordinador, tres repositorios
│   ├── UI/Strings.swift                               MODIFICADO  enum Home, Sections, Nav, Card
│   ├── UI/Theme/BocColors.swift                       MODIFICADO  cinco colores de sección + velo
│   ├── UI/Component/PublicationCard.swift             NUEVO       compartida: Inicio, Guardados, Buscar
│   ├── UI/Component/PublicationCardSkeleton.swift     NUEVO
│   ├── UI/Component/OfflineBanner.swift               NUEVO
│   ├── UI/Component/ComingSoonMessage.swift           NUEVO
│   ├── Util/AppClock.swift                            MODIFICADO  gana now(); arrastra los dos dobles
│   ├── Util/AppRandom.swift                           NUEVO       el jitter, inyectado
│   ├── Util/BocDateFormatting.swift                   NUEVO       formato largo sin Locale.current
│   └── Util/LaunchConfiguration.swift                 MODIFICADO  -boc-data-scenario= sustituye al viejo
├── Domain/
│   ├── Model/BocDate.swift                            NUEVO       Swift no tiene LocalDate
│   ├── Model/Publication.swift                        NUEVO
│   ├── Model/PublicationFacets.swift                  NUEVO       EditionType · IdSource · ParserWarning
│   ├── Model/BocSection.swift                         NUEVO       + SectionColorGroup
│   ├── Model/HomeSelection.swift                      NUEVO
│   ├── Model/BulletinHeader.swift                     NUEVO
│   ├── Model/SyncSummary.swift                        NUEVO
│   ├── Model/DomainError.swift                        MODIFICADO  dos casos nuevos: storage y cancelled
│   ├── Repository/PublicationRepository.swift         NUEVO
│   ├── Repository/BocSectionRepository.swift          NUEVO
│   ├── Repository/HomeSelectionStore.swift            NUEVO
│   ├── UseCase/ObservePublicationsUseCase.swift       NUEVO
│   ├── UseCase/ObserveBulletinHeaderUseCase.swift     NUEVO
│   ├── UseCase/RefreshPublicationsUseCase.swift       NUEVO
│   ├── UseCase/GetBocSectionsUseCase.swift            NUEVO
│   └── UseCase/PrepareStartupUseCase.swift            MODIFICADO  abre y migra la base (D-305)
├── Data/
│   ├── Source/Remote/BocFeedCatalog.swift             NUEVO       19 direcciones literales
│   ├── Source/Remote/RssDTO.swift                     NUEVO       todo anulable a propósito
│   ├── Source/Remote/BocRssParser.swift               NUEVO       XMLParser, SAX, @concurrent
│   ├── Source/Remote/PublicationNormalizer.swift      NUEVO       las once reglas, función pura
│   ├── Source/Remote/FeedDownloader.swift             NUEVO       protocolo + FeedFetchResult
│   ├── Source/Remote/HttpFeedDownloader.swift         NUEVO       URLSession.bytes, tope real de 5 MB
│   ├── Source/Local/BocDatabase.swift                 NUEVO       ÚNICO sitio que abre la base
│   ├── Source/Local/BocMigrations.swift               NUEVO       v1, esquema versionado
│   ├── Source/Local/PublicationRecord.swift           NUEVO
│   ├── Source/Local/FeedSyncStateRecord.swift         NUEVO
│   ├── Source/Local/PublicationQueries.swift          NUEVO       ni un DELETE, y se demuestra
│   ├── Source/Local/UserDefaultsSelectionStore.swift  NUEVO
│   ├── Sync/FeedSyncCoordinator.swift                 NUEVO       actor: tope de 4, una sola a la vez
│   ├── Sync/ScenarioDatabaseSeeder.swift              NUEVO       la costura de las pruebas de interfaz
│   ├── Repository/PublicationRepositoryImpl.swift     NUEVO
│   ├── Repository/BocSectionRepositoryImpl.swift      NUEVO
│   ├── Repository/ContentRepositoryImpl.swift         RETIRADO
│   ├── Source/Local/ContentItemRecord.swift           RETIRADO
│   ├── Source/Local/ContentLocalDataSource.swift      RETIRADO
│   ├── Source/Remote/ContentItemDTO.swift             RETIRADO
│   └── Source/Remote/ContentRemoteDataSource.swift    RETIRADO
├── UI/
│   ├── Main/MainView.swift                            NUEVO       ZStack: TabView + velo + panel
│   ├── Main/MainViewModel.swift                       NUEVO
│   ├── Main/MainUiState.swift                         NUEVO
│   ├── Main/BocTabBar.swift                           NUEVO
│   ├── Main/SectionsDrawer.swift                      NUEVO       cabecera, nueve filas, desplegables
│   ├── Main/SectionsDrawerRow.swift                   NUEVO
│   ├── Home/HomeView.swift                            REESCRITA
│   ├── Home/HomeViewModel.swift                       REESCRITA
│   ├── Home/HomeUiState.swift                         REESCRITA
│   ├── Home/HomeContentView.swift                     REESCRITA
│   ├── Home/Component/HomeTopBar.swift                NUEVO
│   ├── Home/Component/BulletinHeaderView.swift        NUEVO       rótulo + fecha + recuento
│   ├── Home/Component/SectionChipRow.swift            NUEVO       sirve a las dos filas
│   ├── Search/SearchView.swift                        NUEVO       marcador «Próximamente»
│   ├── Saved/SavedView.swift                          NUEVO       marcador «Próximamente»
│   ├── Navigation/RootView.swift                      MODIFICADO  conmuta a MainView, no a HomeView
│   └── Navigation/Route.swift                         MODIFICADO  MainTab, restaurada por nombre
├── Domain/Model/ContentItem.swift                     RETIRADO
├── Domain/Repository/ContentRepository.swift          RETIRADO
├── Domain/UseCase/GetContentItemsUseCase.swift        RETIRADO
└── Localizable.xcstrings                              MODIFICADO  ~26 cadenas + el primer plural

BOCantabria-iosTests/
├── Architecture/SourceTree.swift                      MODIFICADO  gana rawCode (D-323)
├── Architecture/SourceTreeTests.swift                 MODIFICADO  su prueba, que la regla exige
├── Architecture/ArchitectureRulesTests.swift          MODIFICADO  regla 6 ampliada + reglas 10, 11 y 12
├── Domain/BocDateTests.swift                          NUEVO       la trampa de Int("+1"), otra vez
├── Domain/BocSectionTests.swift                       NUEVO       catálogo, padres e hijas, color
├── Domain/PublicationTests.swift                      NUEVO
├── Domain/HomeSelectionTests.swift                    NUEVO
├── Domain/SyncSummaryTests.swift                      NUEVO
├── Domain/RefreshPublicationsUseCaseTests.swift       NUEVO
├── Domain/ObservePublicationsUseCaseTests.swift       NUEVO
├── Core/BocDateFormattingTests.swift                  NUEVO       las doce cadenas exactas
├── Core/BocThemeTests.swift                           MODIFICADO  los cinco colores y el mapeo 9→5
├── Data/BocRssParserTests.swift                       NUEVO       las diez muestras + las tres trampas
├── Data/PublicationNormalizerTests.swift              NUEVO       la matriz de categorías
├── Data/HttpFeedDownloaderTests.swift                 NUEVO       URLProtocol: tope, redirección, tipo
├── Data/BocDatabaseTests.swift                        NUEVO       migración, upsert, orden estable
├── Data/PublicationQueriesTests.swift                 NUEVO
├── Data/FeedSyncCoordinatorTests.swift                NUEVO       tope de 4, una sola a la vez, jitter
├── Data/UserDefaultsSelectionStoreTests.swift         NUEVO
├── Data/ContentRepositoryImplTests.swift              RETIRADO
├── Domain/GetContentItemsUseCaseTests.swift           RETIRADO
├── UI/HomeViewModelTests.swift                        REESCRITA
├── UI/MainViewModelTests.swift                        NUEVO
├── Integration/SyncFlowIntegrationTests.swift         NUEVO       el grafo real sobre base en memoria
├── Integration/NoDeleteRegressionTests.swift          NUEVO       recoge las sentencias ejecutadas
├── Integration/ContentFlowIntegrationTests.swift      RETIRADO
├── Integration/AppContainerTests.swift                MODIFICADO
└── Fakes/Fakes.swift                                  MODIFICADO  ManualClock reescrito, FixedRandom

BOCantabria-iosUITests/
├── Home/HomeStatesUITests.swift                       REESCRITA   mismos identificadores, origen nuevo
├── Home/HomeBackgroundUITests.swift                   MODIFICADO
├── Main/SectionsDrawerUITests.swift                   NUEVO
├── Main/TabNavigationUITests.swift                    NUEVO
└── Home/HomeFiltersUITests.swift                      NUEVO       las dos filas de chips
```

**Structure Decision**: casi todo cae en carpetas que ya existen o que `CLAUDE.md` ya tenía
previstas —`UI/Main/` es literalmente «armazón: pestañas inferiores y panel de secciones», y
`Core/UI/Component/` dice «incluida PublicationCard»—. Tres ubicaciones merecen explicación:

- **El panel vive en `UI/Main/`, no en una carpeta propia.** Es parte del armazón: envuelve a los
  tres destinos y no pertenece a ninguno. Ponerlo en `UI/Home/` lo ataría a la pantalla que resulta
  que hoy es la única que lo abre.
- **`Data/Sync/` es carpeta nueva** y es la única desviación de estructura. Va declarada abajo.
- **`UI/Home/Component/` sigue el patrón que la guía ya reconoce** para `Alerts/Form`: piezas de una
  sola pantalla, junto a su pantalla. Lo que sirve a tres pantallas —la tarjeta— sube a
  `Core/UI/Component/`, que es la diferencia entre las dos carpetas.

## Complexity Tracking

Seis desviaciones. Ninguna añade una capa, un patrón nuevo ni una dependencia.

| Desviación | Por qué hace falta | Alternativa más simple, y por qué se rechaza |
|---|---|---|
| **Carpeta nueva `Data/Sync/`**, que no está en el mapa de `CLAUDE.md` | El coordinador no es un origen de datos ni un repositorio: orquesta diecinueve descargas con un tope, decide qué se reintenta y escribe. Meterlo en `Source/Remote/` diría que es una fuente, y la sembradora de escenarios convive con él porque comparte exactamente el mismo camino de escritura | Dentro de `PublicationRepositoryImpl`: el repositorio pasaría de traducir a orquestar, y la prueba del tope de cuatro tendría que atravesar el repositorio entero para observar algo que no es suyo. En `Source/Remote/`: es mentira, porque también escribe en local |
| **La apertura y la migración de la base entran en `PrepareStartupUseCase`**, que hasta hoy solo comprobaba conexión, configuración y versión | Un fallo de migración tiene que poder contarse, y **hoy el único sitio de la aplicación con indicador de progreso, límite de espera y estado de error con reintento es la portada**. Decidido con el propietario. Si la base se abriera perezosamente, ese fallo aparecería con Inicio ya en pantalla y no habría dónde ponerlo | Abrirla al construir el contenedor: mete E/S de disco en el camino crítico del arranque sin indicador ninguno, y un fallo ahí no tiene más salida que cerrarse. Perezosa en el primer uso: el arranque no paga nada, pero hay que inventar un sitio donde contar el fallo, y ese sitio es justo el que ya existe en la portada |
| **`ManualClock` deja de ser `actor` y pasa a `final class … @unchecked Sendable` con `Mutex`**, cuando la guía prefiere el `actor` | `AppClock` gana `now()`, y `now()` tiene que ser síncrono: comparar dos fechas no puede contagiar `await` a media aplicación. Un `actor` no puede ofrecer un método síncrono que lea su estado. El `Mutex` envuelto en una clase es un patrón que el proyecto ya usa en `RecordingAnalyticsTracker`, con su trampa anotada | Partir el protocolo en dos —`AppClock` y un proveedor de fecha—: dos costuras que siempre se inyectan juntas y que nadie recordará mantener sincronizadas. Dejar `now()` asíncrono: contagia `await` a cada comparación de fechas, incluida la del modelo de pantalla |
| **`SourceTree` gana `rawCode`**, con las cadenas literales dentro, cuando el motor las retira a propósito | Las cadenas se retiran para que un comentario o un literal no disparen la regla que documentan. Pero la sentencia SQL de una consulta **es** una cadena, así que una regla que busque un borrado sobre `code` no ve nada y **pasa siempre**. Es exactamente el fallo que el proyecto ya cometió al traducir la regla de capas de Konsist, y por el que añadió la comprobación por referencias | No hacer la regla textual: deja el invariante solo en manos de la prueba de ejecución, que es la buena pero llega más tarde en el ciclo. `rawCode` **no sustituye** a `code`: se añade, y cada regla elige. Los comentarios se siguen retirando en las dos |
| **Cuatro reglas de arquitectura donde había nueve** —la 6 ampliada a GRDB, y las 10, 11 y 12 nuevas—, cuando la lista debe mantenerse corta | Cada una cierra un agujero que esta feature abre y que ninguna existente ve. La 10 porque **dentro de un módulo Swift no hace falta importar para nombrar**, que es la trampa número uno de este port aplicada otra vez. La 11 porque la constitución exige pruebas «sin reloj del sistema» y **hoy no lo comprueba nada**. La 12 porque `Task.detached` es lo que se escribe cuando lo correcto es `@concurrent`, y pierde la cancelación estructurada | Confiar en la revisión: es lo que la suite de reglas existe para no tener que hacer. Una sola regla que lo agrupe todo: al fallar no diría cuál de los cuatro invariantes se rompió, que es la mitad del valor de una regla |
| **Cuatro tipos nuevos entran en `domainTypesWithoutBehaviour`**, que pasa de tres entradas a siete | `EditionType`, `IdSource`, `ParserWarning` y `SectionColorGroup` son enumerados sin comportamiento; lo único que podría afirmar un fichero propio es que el compilador funciona. Su semántica se prueba donde vive: en `PublicationNormalizerTests` y en `BocSectionTests` | Escribirles ficheros de prueba triviales: satisface la regla sin comprobar nada, que es peor que la exención porque la exención al menos se ve en la lista. **`Publication`, `BocDate`, `BocSection`, `HomeSelection` y `SyncSummary` NO se eximen**, y eso se decide aquí y en frío, no cuando la build esté roja |

**Lo que NO se desvía, y conviene dejar escrito.** La costura de las pruebas de interfaz **no
crece**: `-boc-content-scenario=` se sustituye por `-boc-data-scenario=` y siguen siendo dos
argumentos, los mismos que hoy (D-322). La cabecera de `LaunchConfiguration` dice «se sustituye, no
se amplía», y esta feature es justo la que tenía que cumplir esa promesa. Y las reglas 7 y 8 —el
color y el tema del sistema— quedan intactas: los cinco colores de sección y el velo del panel
entran **en `BocColors`**, que es donde la regla 7 permite construir un color, y no hay ni una
variante oscura.
