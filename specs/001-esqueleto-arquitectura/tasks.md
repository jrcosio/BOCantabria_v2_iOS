# Tasks: Esqueleto de arquitectura de la aplicación

**Input**: Documentos de diseño en `specs/001-esqueleto-arquitectura/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: **OBLIGATORIOS.** El principio V de la constitución los declara no negociables y la
especificación los exige en FR-022 … FR-028. Dentro de cada historia, las pruebas se escriben
**antes** que la implementación y deben fallar antes de hacerlas pasar.

**Organization**: por historia de usuario, de forma que cada una pueda implementarse, probarse y
demostrarse por separado.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizable (ficheros distintos, sin dependencias entre sí)
- **[Story]**: a qué historia pertenece (US1, US2, US3)
- Las rutas son exactas y relativas a la raíz del repositorio

**Abreviaturas**: `APP/` = `BOCantabria-ios/` · `TEST/` = `BOCantabria-iosTests/` ·
`UITEST/` = `BOCantabria-iosUITests/`

---

## Phase 1: Setup

**Purpose**: dejar el proyecto vacío de plantilla y con el árbol de carpetas en su sitio.

- [x] T001 Crear el árbol de carpetas de producción en `APP/`: `Core/DI`, `Core/Telemetry`,
      `Core/UI/Theme`, `Core/UI/Component`, `Core/Util`, `Domain/Model`, `Domain/Repository`,
      `Domain/UseCase`, `Data/Repository`, `Data/Source/Local`, `Data/Source/Remote`,
      `Data/Telemetry`, `UI/Home`, `UI/Navigation`. Los grupos sincronizados los recogen solos:
      **no se toca `project.pbxproj`**.
- [x] T002 Crear el árbol de pruebas: `TEST/Architecture`, `TEST/Core`, `TEST/Domain`,
      `TEST/Data`, `TEST/UI`, `TEST/Integration`, `TEST/Fakes` y `UITEST/Home`.
- [x] T003 **FR-028**: eliminar las plantillas del generador —`TEST/BOCantabria_iosTests.swift`,
      `UITEST/BOCantabria_iosUITests.swift`, `UITEST/BOCantabria_iosUITestsLaunchTests.swift`— y
      el andamiaje provisional `APP/ContentView.swift`.
- [x] T004 [P] Crear el catálogo de cadenas `APP/Localizable.xcstrings` con los textos de la
      pantalla inicial, en español.

**Checkpoint**: el proyecto compila sin plantillas y con las carpetas creadas.

---

## Phase 2: Foundational (bloqueante)

**Purpose**: lo que toda historia necesita. **⚠️ Ninguna historia puede empezar hasta cerrar esta
fase.**

### El aspecto

- [x] T005 [P] `APP/Core/UI/Theme/BocColors.swift`: los 26 tokens de `data-model.md` §4.1.
- [x] T006 [P] `APP/Core/UI/Theme/BocTypography.swift`: los 14 estilos de §4.2, con **espaciado
      entre letras a cero** y el interlineado convertido a espaciado aditivo.
- [x] T007 [P] `APP/Core/UI/Theme/BocSpacing.swift`: los 9 tokens + `screenMargin`.
- [x] T008 [P] `APP/Core/UI/Theme/BocShape.swift`: 5 radios + 3 formas con nombre + cápsula.
- [x] T009 [P] `APP/Core/UI/Theme/BocElevation.swift`: los 5 niveles.
- [x] T010 `APP/Core/UI/Theme/BocTheme.swift`: el espacio de nombres que agrupa los cinco.
      Depende de T005–T009.
- [x] T011 `TEST/Core/BocThemeTests.swift`: que los valores son los del documento de diseño.
      Comprueba al menos los 26 colores y que **ningún estilo tipográfico lleva tracking**.

### Tipos nucleares

- [x] T012 [P] `APP/Domain/Model/AppResult.swift` y `APP/Domain/Model/DomainError.swift`.
- [x] T013 [P] `APP/Core/Util/AppClock.swift`: el protocolo del reloj y su implementación real
      (D-108).
- [x] T014 [P] `APP/Core/Telemetry/AnalyticsEvent.swift` con el patrón del nombre y
      `sanitizedParameters()`.
- [x] T015 [P] `TEST/Core/AnalyticsEventTests.swift`: el patrón del nombre, que las 15 claves
      sensibles se descartan, que la coincidencia es exacta y en minúsculas, y que **una clave no
      sensible sí viaja**.
- [x] T016 [P] `APP/Core/Telemetry/AnalyticsTracker.swift` y
      `APP/Core/Telemetry/CrashReporter.swift`, con sus implementaciones de no operación.
- [x] T017 [P] `APP/Core/UI/Component/`: `LoadingIndicator`, `ErrorMessage` (con acción de
      reintento) y `EmptyMessage`. Sin estado, consumiendo solo tokens del tema.
- [x] T018 [P] `APP/UI/Navigation/Route.swift`: el enumerado de destinos.

### Las reglas de arquitectura

- [x] T019 `TEST/Architecture/SourceTree.swift`: localiza el árbol con `#filePath` y devuelve, por
      fichero, su ruta relativa, sus `import` y los tipos declarados al nivel superior.
- [x] T020 `TEST/Architecture/ArchitectureRulesTests.swift`: las **nueve** reglas de `research.md` D-102. Depende de T019.
- [x] T021 `TEST/Architecture/SourceTreeTests.swift`: que el propio lector funciona —que encuentra
      ficheros, que extrae los `import` y que distingue un tipo de nivel superior de uno anidado—.
      **Una regla que no puede fallar es una regla que no protege nada.**

**Checkpoint**: el tema existe, las reglas muerden y las historias pueden empezar.

---

## Phase 3: User Story 1 — La aplicación arranca y muestra contenido (P1) 🎯 MVP

**Goal**: una pantalla que recorre todas las capas y representa los cuatro estados con su
reintento.

**Independent Test**: instalar en un simulador limpio, abrir, y recorrer los cuatro estados
forzando el origen.

### Pruebas primero ⚠️

> Se escriben antes y **deben fallar** antes de implementarlas.

- [x] T022 [P] [US1] `TEST/Domain/GetContentItemsUseCaseTests.swift`: propaga el éxito sin
      alterarlo, propaga el éxito vacío **como éxito y no como fallo**, y propaga el fallo.
- [x] T023 [P] [US1] `TEST/Data/ContentRepositoryImplTests.swift`: los **cuatro casos** de la
      tabla de `contracts/` §2, más que ningún error escapa del repositorio.
- [x] T024 [P] [US1] `TEST/UI/HomeViewModelTests.swift`: arranca en carga y llega a contenido · un
      resultado vacío es «sin contenido» y no error · un fallo llega a error con su error de
      dominio · reintentar desde error llega a contenido · **reintentar durante una carga no lanza
      una segunda** · registra la pantalla vista **exactamente una vez por instancia**.
- [x] T025 [P] [US1] `TEST/Integration/ContentFlowIntegrationTests.swift`: el contenido viaja del
      origen remoto hasta el estado de la pantalla con el cableado real, y un fallo en la frontera
      aflora como estado de error.
- [x] T026 [P] [US1] `UITEST/Home/HomeStatesUITests.swift`: los cuatro estados y que pulsar
      reintentar recupera. Usa los identificadores de `contracts/` §6.
- [x] T027 [P] [US1] `UITEST/Home/HomeBackgroundUITests.swift` (**FR-005**): con contenido en
      pantalla, segundo plano y vuelta; el contenido sigue y **no** reaparece el indicador.

### Implementación

- [x] T028 [P] [US1] `APP/Domain/Model/ContentItem.swift`.
- [x] T029 [P] [US1] `APP/Data/Source/Remote/ContentItemDTO.swift` (campo **`label`**) y
      `APP/Data/Source/Local/ContentItemRecord.swift` (campo `title`).
- [x] T030 [US1] `APP/Domain/Repository/ContentRepository.swift`.
- [x] T031 [P] [US1] `APP/Data/Source/Remote/ContentRemoteDataSource.swift` +
      `StubContentRemoteDataSource`, con latencia pedida al reloj inyectado.
- [x] T032 [P] [US1] `APP/Data/Source/Local/ContentLocalDataSource.swift` +
      `InMemoryContentLocalDataSource` (un `actor`).
- [x] T033 [US1] `APP/Data/Repository/ContentRepositoryImpl.swift`: la política de cuatro casos.
      Depende de T030–T032.
- [x] T034 [US1] `APP/Domain/UseCase/GetContentItemsUseCase.swift`.
- [x] T035 [P] [US1] `APP/UI/Home/HomeUiState.swift`.
- [x] T036 [US1] `APP/UI/Home/HomeViewModel.swift`. Depende de T034 y T035.
- [x] T037 [P] [US1] `APP/UI/Home/HomeContentView.swift`: **sin estado**, los cuatro estados y el
      reintento, con sus identificadores de accesibilidad.
- [x] T038 [US1] `APP/UI/Home/HomeView.swift` y `APP/UI/Navigation/RootView.swift`.
- [x] T039 [US1] `APP/Core/DI/AppContainer.swift` y `APP/Data/Telemetry/TelemetryBundle.swift`
      con no operación por ahora. **El cableado va al final de la historia**, cuando ya existen
      las clases que registra.
- [x] T040 [US1] `APP/BOCantabriaApp.swift`: construye el contenedor y monta la raíz.
- [x] T041 [P] [US1] `TEST/Fakes/`: los dobles compartidos —origen remoto falseable, reloj fijo y
      espía de analítica—, `Sendable` como exige la concurrencia estricta.

**Checkpoint**: hay aplicación. Instálala y recorre los cuatro estados antes de seguir.

---

## Phase 4: User Story 2 — Un patrón reproducible que no se degrada (P2)

**Goal**: que romper la arquitectura o el aspecto ponga la comprobación en rojo.

**Independent Test**: provocar una violación a mano y verla fallar; revertir y verla pasar.

**Depende de US1**: sus pruebas necesitan código real que inspeccionar.

- [x] T042 [US2] `TEST/Integration/AppContainerTests.swift` (**FR-023**): construye el contenedor
      entero, obtiene todas las pantallas, y afirma que **no toca servicios externos al
      construirse**.
- [x] T043 [US2] Verificación a mano de que las reglas muerden: los tres recorridos de
      `quickstart.md` §2 —capas, aspecto y fichero de prueba ausente—. Anotar el resultado.
- [x] T044 [US2] Revisar que la lista de exenciones de la regla del fichero de prueba está vacía o
      justificada al lado, con el recordatorio de que **cada entrada es un agujero en SC-002**.

**Checkpoint**: la arquitectura está protegida por algo que se ha visto fallar.

---

## Phase 5: User Story 3 — Visibilidad de uso y de fallos (P3)

**Goal**: que la telemetría llegue, sin que el dominio ni la presentación sepan quién hay detrás.

**Independent Test**: abrir la pantalla y ver el evento en el panel del proveedor; provocar un
cierre inesperado y ver su traza.

**Puede hacerse en paralelo con US2**: solo sustituye implementaciones detrás de contratos que ya
existen.

- [x] T045 [P] [US3] `TEST/Data/FirebaseAnalyticsTrackerTests.swift`: envía el nombre y sus
      parámetros · una pantalla vista lleva su nombre · **nunca envía parámetros personales** · un
      fallo del cliente **no llega a quien llama**.
- [x] T046 [P] [US3] `TEST/Data/FirebaseCrashReporterTests.swift`: delega no fatales y mensajes ·
      un fallo del cliente no llega a quien llama · de un no fatal escribe **el tipo del error y
      no su mensaje**.
- [x] T047 [P] [US3] `TEST/Data/TelemetryBundleTests.swift` (**FR-021**): sin fichero de
      configuración, la resolución devuelve las implementaciones de no operación.
- [x] T048 [US3] `APP/Data/Telemetry/FirebaseAnalyticsTracker.swift`.
- [x] T049 [US3] `APP/Data/Telemetry/FirebaseCrashReporter.swift`, con eco al registro **solo en
      depuración**.
- [x] T050 [US3] Completar `TelemetryBundle.resolved()`: decide entre Firebase y no operación
      según exista el fichero. **Único sitio que toma esa decisión**, y fuera del contenedor para
      que el contenedor no importe Firebase.
- [x] T051 [US3] Registrar la pantalla vista de Inicio desde `HomeViewModel`.

**Checkpoint**: las tres historias funcionan de forma independiente.

---

## Phase 6: Polish & Cross-Cutting

- [x] T052 **SC-008**: apartar `GoogleService-Info.plist` y `Config/Secrets.xcconfig`, y
      comprobar que construye, arranca y pasa las pruebas. `quickstart.md` §3.
- [x] T053 **SC-001**: medir el arranque hasta la pantalla inicial. Objetivo: menos de 2 s. **Se
      mide, no se estima**; anotar la cifra.
- [x] T054 Recorrido manual de `quickstart.md` §4: los cuatro estados, el reintento y la vuelta de
      segundo plano.
- [x] T055 [P] Actualizar `CLAUDE.md` y `README.md` con lo que esta feature deja en pie.
- [x] T056 Las cuatro puertas de calidad en verde, en orden.

---

## Dependencies & Execution Order

### Entre fases

- **Setup (1)**: sin dependencias.
- **Foundational (2)**: depende de Setup y **bloquea las tres historias**.
- **US1 (3)**: depende de Foundational.
- **US2 (4)**: depende de **US1 completa** — sus pruebas necesitan código real que inspeccionar.
- **US3 (5)**: depende de Foundational; puede ir **en paralelo con US2**.
- **Polish (6)**: depende de las tres historias.

### Dentro de cada historia

Las pruebas se escriben **antes** y deben fallar antes de implementarlas. Modelos antes que
orígenes; orígenes antes que repositorios; repositorios antes que casos de uso; casos de uso antes
que modelos de pantalla; modelos de pantalla antes que vistas. **El cableado del contenedor va al
final de cada historia**, cuando ya existen las piezas que registra.

### Paralelismo

- Fase 2: T005–T009, T012–T018 son independientes entre sí.
- US1: las seis pruebas T022–T027 en paralelo; y T028, T029, T031, T032, T035, T037, T041 tocan
  ficheros distintos.
- US2 y US3 en paralelo una vez cerrada US1.

---

## Implementation Strategy

**MVP primero**: Setup → Foundational → US1 → **PARAR Y VALIDAR** instalando en el simulador y
recorriendo los cuatro estados. En ese punto ya hay algo demostrable.

**Entrega incremental**: base → US1 (MVP) → US2 (validar que una violación deliberada falla) →
US3 (validar en la consola del proveedor) → Polish. Cada historia aporta valor sin romper las
anteriores.

---

## Notes

- `[P]` = ficheros distintos, sin dependencias.
- Verificar que las pruebas fallan antes de implementar.
- Commit por tarea o por grupo lógico.
- **56 tareas.**

---

## Resultado

Cerrada el 11 de septiembre de 2026. Cincuenta y seis tareas.

| Puerta | Resultado |
|---|---|
| Construcción | Verde |
| Pruebas sin interfaz | **58 en 10 suites, 0,10 s** (objetivo SC-003: menos de 2 min) |
| Pruebas de interfaz | **6 en 28,8 s** |
| Avisos propios | **0** sobre construcción limpia |

**Las reglas muerden, comprobado a mano** (T043). Las tres violaciones deliberadas cayeron en la
regla correcta y el árbol volvió a verde al revertirlas:

| Violación provocada | Regla que la cazó |
|---|---|
| `Domain` nombra `ContentItemRecord` | 2 · Domain no nombra ningún tipo de Data ni de UI |
| Una vista construye `Color(red:green:blue:)` | 7 · Solo el tema construye colores |
| Un tipo de dominio sin fichero de prueba | 9 · Todo tipo de dominio tiene fichero de prueba |

**Sin ningún secreto en el puesto** (T052, SC-008): apartados el `GoogleService-Info.plist` y el
`Secrets.xcconfig`, la aplicación **construye, pasa las 58 pruebas y arranca**.

**Arranque** (T053, SC-001): **815 ms** de media en cinco tomas con `XCTApplicationLaunchMetric`,
desviación relativa del 0,5 %. El objetivo era menos de 2 s. Se mide, no se estima.
