# Tasks: Pantalla de arranque y comprobación previa

**Input**: Documentos de diseño en `specs/002-pantalla-arranque/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: **OBLIGATORIOS.** El principio V de la constitución los declara no negociables y la
especificación los exige en FR-027 … FR-030. Dentro de cada historia, la prueba de una pieza se
escribe **con** la pieza y ninguna tarea se da por terminada sin su prueba en verde.

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

**Purpose**: las carpetas, los textos y los recursos que todo lo demás necesita ya escritos.

- [X] T001 Crear las carpetas nuevas: `APP/UI/Splash/`, `TEST/Integration` ya existe, y
      `UITEST/Splash/`. Los grupos sincronizados las recogen solas: **no se toca
      `project.pbxproj`** para fuentes.
- [X] T002 [P] **FR-023**: añadir las trece cadenas `splash_*` a `APP/Localizable.xcstrings`, con
      los textos literales de `docs/referencia-android/res/strings.xml` (`splash_acronym`,
      `splash_title_line_one`, `splash_title_line_two`, `splash_authorship_label`,
      `splash_authorship_name`, `splash_loading_description`, `splash_error_title`,
      `splash_error_network`, `splash_error_unknown`, `splash_continue_offline`,
      `splash_update_required_title`, `splash_update_required_message`,
      `splash_maintenance_title`), cada una con su `comment`.
- [X] T003 [P] `APP/Core/UI/Strings.swift`: añadir `enum Splash` con las trece claves, siguiendo el
      patrón de `enum Home`.
- [X] T004 **D-214** `APP/Core/UI/Theme/BocTypography.swift`: convertir `tracking` de constante
      calculada a propiedad almacenada con cero por defecto, y añadir el grupo
      `BocTypography.splash` con `subtitle` (20/26, medium, tracking amplio), `authorshipLabel`
      (13/18, regular) y `authorshipName` (15/20, semibold). Los catorce estilos del §6.2 siguen a
      cero.
- [X] T005 `TEST/Core/BocThemeTests.swift`: **ojo, esta prueba se pone roja con T004**. Hoy afirma
      que ningún estilo lleva tracking; pasa a afirmar que **los catorce del §6.2** siguen a cero
      **y** que el subtítulo de la portada lleva el suyo. Añadir los tres estilos nuevos a las
      comprobaciones de valores.
- [X] T006 [P] **D-203** Generar `APP/Assets.xcassets/Icons/ic_launch_emblem.imageset/` desde el
      mismo vector que los demás iconos: escudo a 104 pt de alto, lienzo con relleno transparente
      inferior para que al centrarlo el sistema quede por encima del centro óptico.
      `template-rendering-intent: original` y `preserves-vector-representation`, como
      `ic_escudo_cantabria`. **No se dibuja a mano.**

**Checkpoint**: el proyecto compila, las cadenas están y el tema tiene los tres estilos nuevos.

---

## Phase 2: Foundational (bloqueante)

**Purpose**: el dominio, los datos y los dobles de prueba. **⚠️ Ninguna historia puede empezar
hasta cerrar esta fase.**

### Dominio

- [X] T007 [P] `APP/Domain/Model/AppVersion.swift`: terna `major`/`minor`/`patch`, `Comparable`,
      `Sendable`, `init?(_ text: String)` que acepta «1», «1.0» y «1.0.0» y **devuelve `nil`** ante
      cualquier otra cosa, y `static let zero`.
- [X] T008 [P] `TEST/Domain/AppVersionTests.swift` **(FR-015)**: parseo de las tres formas válidas;
      `nil` para vacío, texto, negativos, cuatro componentes y componentes no numéricos; y el orden
      —incluido que `1.10.0 > 1.9.0`, que es donde falla una comparación de cadenas—.
- [X] T009 [P] `APP/Domain/Model/AppConfig.swift`: `minSupportedVersion` y `maintenanceMessage`
      opcional, con **normalización a nulo** de la cadena vacía o en blanco, más
      `static let default` (`zero` y `nil`) — **D-208**, la única declaración de «todo permitido»
      del proyecto.
- [X] T010 [P] `TEST/Domain/AppConfigTests.swift` **(FR-013, FR-014)**: que el mensaje vacío, el de
      solo espacios y el nulo dan los tres `nil`; que un mensaje real se conserva tal cual; y que
      el valor por defecto **no bloquea**.
- [X] T011 [P] `APP/Domain/Model/StartupStatus.swift`: `ready`, `updateRequired` y
      `maintenance(String)`.
- [X] T012 `TEST/Architecture/ArchitectureRulesTests.swift`: añadir `StartupStatus` a
      `domainTypesWithoutBehaviour`, con el comentario que dice por qué (no tiene comportamiento;
      su semántica se prueba en `PrepareStartupUseCaseTests`). Es la entrada que el `plan.md`
      declara en *Complexity Tracking*.
- [X] T013 [P] `APP/Domain/Repository/AppConfigRepository.swift` y
      `APP/Domain/Repository/ConnectivityRepository.swift`, con las firmas del contrato §1 y la
      nota de que la conectividad **no promete internet**.

### Datos

- [X] T014 [P] `APP/Data/Source/Remote/RemoteConfigDataSource.swift`: el protocolo (que **sí puede
      lanzar**) y `RemoteConfigValues` con las claves `min_supported_version_ios` y
      `maintenance_message`.
- [X] T015 [P] `APP/Data/Source/Remote/UnavailableRemoteConfigDataSource.swift`: devuelve valores
      vacíos y **no lanza** — **D-209**.
- [X] T016 `APP/Data/Source/Remote/FirebaseRemoteConfigDataSource.swift`: **ÚNICO** fichero que
      toca el SDK de configuración remota. `actor`, `async/await`, sin interceptores de registro.
- [X] T017 [P] `APP/Data/Source/Local/ConnectivityDataSource.swift`: el protocolo y el `actor`
      sobre `NWPathMonitor` — **D-205**.
- [X] T018 `APP/Data/Repository/AppConfigRepositoryImpl.swift`: traduce `RemoteConfigValues` a
      `AppConfig`, **captura todo** y aplica la tabla de errores del contrato §2, eligiendo entre
      `.network` y `.unknown` según la conectividad. Repropaga `CancellationError`. Todo camino de
      fallo escribe por `CrashReporter.log` **(FR-018)**.
- [X] T019 `TEST/Data/AppConfigRepositoryImplTests.swift`: las ocho filas de la tabla del contrato
      §2, una por una. Incluida «versión ilegible → `.zero`» y «ninguna excepción escapa de `Data`».
- [X] T020 [P] `APP/Data/Repository/ConnectivityRepositoryImpl.swift` y
      `TEST/Data/ConnectivityRepositoryImplTests.swift`.

### Transversal y dobles

- [X] T021 [P] `APP/Core/Util/AppInfo.swift`: lee `CFBundleShortVersionString` y lo convierte en
      `AppVersion`. **D-206**: quien lee el paquete es `Core`, no `Domain`.
- [X] T022 [P] `TEST/Core/AppInfoTests.swift`: que la versión del paquete se parsea, y que un
      valor ausente o ilegible da **nulo, no `.zero`**. Cero es *menor* que cualquier mínimo
      publicado, así que un respaldo a cero haría que la aplicación se bloqueara a sí misma justo
      cuando no sabe su propia versión; nulo significa «no se puede comparar».
- [X] T023 [P] `APP/Core/Util/StartupScenario.swift`: el enumerado con `ready`, `offline`,
      `updateRequired`, `maintenance` y `slow` — **D-212**.
- [X] T024 `APP/Core/Util/LaunchConfiguration.swift`: segundo argumento
      `-boc-startup-scenario=`, con respaldo silencioso a `.ready`. **Actualizar la cabecera del
      fichero**, que hoy dice «se sustituye, no se amplía», para que explique qué se amplió y por
      qué, remitiendo a *Complexity Tracking*.
- [X] T025 **D-211** `TEST/Fakes/Fakes.swift`: `ManualClock`, que suspende cada `sleep` hasta que la
      prueba avanza el tiempo y registra lo que se le pidió esperar. **Es lo que hace cierto
      FR-030**: con `ImmediateClock` la carrera del límite de espera la ganaría siempre el límite y
      las pruebas afirmarían lo contrario de lo que creen.
- [X] T026 [P] `TEST/Fakes/Fakes.swift`: `FakeAppConfigRepository`, `FakeConnectivityRepository` y
      `FakeRemoteConfigDataSource`, todos `Sendable` por construcción (`actor` o estado en `Mutex`),
      con la variante que **falla la primera vez y responde después**, que es la que necesita el
      reintento.

### Cableado

- [X] T027 `APP/Data/Telemetry/TelemetryBundle.swift`: pasa a resolver **también** la fuente de
      configuración remota, en la misma comprobación de presencia del fichero del proveedor.
      `FirebaseApp.configure()` sigue llamándose **una sola vez** — **D-209**.
- [X] T028 `APP/Core/DI/AppContainer.swift`: cablear los dos repositorios, el caso de uso y
      `makeSplashViewModel()`. Los parámetros nuevos (`startupScenario`, `installedVersion`) llevan
      **valor por defecto**, para no romper las tres llamadas existentes de `AppContainerTests`.
      El contenedor sigue **sin importar ningún SDK**.
- [X] T029 `TEST/Integration/AppContainerTests.swift`: añadir que el contenedor resuelve
      `makeSplashViewModel()`, que construirlo **no dispara ninguna preparación** y que el estado
      inicial es `preparing`.

**Checkpoint**: el dominio y los datos están completos y probados. Ninguna pantalla los usa todavía.

---

## Phase 3: User Story 1 — Abrir la aplicación y entrar sin fricción (P1) 🎯 MVP

**Goal**: la portada aparece sin destello, se prepara sola, pasa al contenido principal y no se
vuelve a ella.

**Independent Test**: instalar en un simulador limpio y abrir. Debe verse la portada y, sin tocar
nada, el contenido principal; el gesto de retroceso no devuelve a la portada.

- [X] T030 [US1] `APP/Domain/UseCase/PrepareStartupUseCase.swift` **(FR-003, FR-016, D-204)**: las
      tres comprobaciones y **la tabla de precedencia** de `data-model.md`. Nunca lanza. No impone
      el tiempo mínimo en pantalla.
- [X] T031 [US1] `TEST/Domain/PrepareStartupUseCaseTests.swift`: una prueba por fila de la tabla,
      más el caso límite «versión obsoleta y sin conexión a la vez», donde **manda la falta de
      conexión**, y el de «obsoleta y en mantenimiento a la vez», donde manda la obsoleta.
- [X] T032 [P] [US1] `APP/UI/Splash/SplashUiState.swift` **(FR-009)**: los cuatro casos y
      `BlockReason`. `blocked` es un caso propio, **no** una bandera dentro de `error`.
- [X] T033 [US1] `APP/UI/Splash/SplashViewModel.swift` **(FR-005, FR-011, FR-017)**: `@MainActor`
      `@Observable`, estado inicial `preparing`, preparación **una sola vez** por instancia, mínimo
      de 1.200 ms **en paralelo** con el trabajo y evento de pantalla vista en el inicializador.
      `onAppear()` es `async` y **no retorna hasta publicar el estado final**: es lo que sostiene
      todo el patrón de prueba de esta casa.
- [X] T034 [US1] `TEST/UI/SplashViewModelTests.swift` (parte de US1): estado inicial; camino feliz
      hasta `ready`; que **con el trabajo terminado en 50 ms el estado no es `ready` hasta avanzar
      el reloj 1.200 ms**; que el mínimo **no se suma** al trabajo (con trabajo de 2 s, listo a los
      2 s y no a los 3,2 s); y que volver a aparecer no vuelve a preparar.
- [X] T035 [P] [US1] `APP/UI/Splash/SplashContentView.swift`: vista tonta con `state` y tres
      closures. En esta historia, solo la rama `preparing`: escudo, siglas, denominación, línea e
      indicador, con los identificadores `splash_root`, `splash_emblem` y `splash_loading`.
- [X] T036 [US1] `APP/UI/Splash/SplashView.swift`: recibe el modelo por inicializador y lo envuelve
      en `@State`, arranca con `.task { await viewModel.onAppear() }` y oculta la barra de estado.
- [X] T037 [US1] **D-201** `APP/UI/Navigation/RootView.swift`: conmuta entre la portada y el
      `NavigationStack` según el estado. **`Route` no cambia** y la portada **no entra en la pila**,
      que es como se cumple FR-007. El modelo del arranque lo posee la raíz, y por eso el estado
      sobrevive al ciclo de segundo plano (FR-008).
- [X] T038 [US1] **FR-002, D-202** `Config/Info.plist`: diccionario `UILaunchScreen` con
      `UIColorName = AccentColor` y `UIImageName = ic_launch_emblem`, más `UIStatusBarHidden`
      (**D-213**).
- [X] T039 [US1] `BOCantabria-ios.xcodeproj/project.pbxproj`: poner
      `INFOPLIST_KEY_UILaunchScreen_Generation = NO` en las dos configuraciones del target de la
      aplicación. Es el único cambio al proyecto que pide esta feature.
- [X] T040 [US1] `TEST/Core/LaunchScreenContractTests.swift`: lee el `Info.plist` compilado y
      comprueba las tres claves del contrato §7. **Verificar además a mano** que el lanzamiento
      acepta el recurso vectorial; si no lo hiciera, rehacer T006 como PNG a tres escalas y anotarlo
      en `research.md` D-203.
- [X] T041 [US1] `TEST/Integration/StartupFlowIntegrationTests.swift`: grafo real desde
      `SplashViewModel` hasta las fuentes, con dobles **solo en la frontera externa**. Camino feliz
      completo.
- [X] T042 [US1] `UITEST/Splash/SplashNavigationUITests.swift` **(FR-004, FR-007)**: con el
      escenario `ready`, la portada da paso al contenido principal sin tocar nada, y el gesto de
      retroceso desde el contenido principal **no** devuelve a la portada.

**Checkpoint**: la aplicación arranca por la portada y entra sola. Es el MVP demostrable.

---

## Phase 4: User Story 2 — Enterarse de que algo va mal, y poder seguir (P1)

**Goal**: ante un fallo recuperable, un mensaje comprensible y dos salidas. Nunca una espera
indefinida.

**Independent Test**: apagar la wifi del Mac y abrir la aplicación. Debe aparecer el mensaje con sus
dos acciones, y «continuar sin conexión» debe llevar al contenido principal.

- [X] T043 [US2] `APP/UI/Splash/SplashViewModel.swift` **(FR-006, FR-010, FR-011)**: rama de error,
      límite de espera de 8 s contra el reloj inyectado, `onRetry()` que **se ignora** si hay una
      preparación en curso, y `onContinueOffline()` que solo tiene efecto desde `error`.
- [X] T044 [US2] `TEST/UI/SplashViewModelTests.swift` (parte de US2): que el fallo publica `error`
      con el error correcto; que **avanzar el reloj 8 s con el trabajo colgado publica `error`**;
      que dos `onRetry()` seguidos **no lanzan dos preparaciones** (se cuenta en el doble); que
      reintentar tras recuperar la conexión llega a `ready`; y que `onContinueOffline()` desde
      `error` publica `ready`.
- [X] T045 [US2] `APP/UI/Splash/SplashContentView.swift`: rama `error`, con el título, el mensaje
      según el error —conexión o inesperado— y los **dos** botones, con los identificadores
      `splash_error`, `splash_retry` y `splash_continue_offline`. Los botones llevan identificador
      propio: **no se buscan por su texto** (contrato §5).
- [X] T046 [US2] `APP/Core/DI/AppContainer.swift`: sustituir las dependencias del arranque para los
      escenarios `offline` y `slow`, en **un** punto.
- [X] T047 [US2] `UITEST/Splash/SplashStatesUITests.swift` (parte de US2): escenario `slow`, que
      muestra el indicador; escenario `offline`, que muestra el mensaje y sus dos botones; y que
      «continuar sin conexión» lleva al contenido principal **en dos toques como máximo** (SC-003).

**Checkpoint**: ningún fallo deja a nadie atrapado en la portada.

---

## Phase 5: User Story 3 — Una puerta que de verdad cierra (P2)

**Goal**: versión obsoleta y mantenimiento informan y **no** dejan pasar.

**Independent Test**: lanzar con los escenarios `updateRequired` y `maintenance`. En los dos casos
debe informarse y no debe existir forma de llegar al contenido principal.

- [X] T048 [US3] `APP/UI/Splash/SplashViewModel.swift` **(FR-012, FR-013)**: rama `blocked`, con
      `BlockReason` a partir del `StartupStatus`, y `onContinueOffline()` **ignorado** desde
      `blocked`.
- [X] T049 [US3] `TEST/UI/SplashViewModelTests.swift` (parte de US3): que `updateRequired` y
      `maintenance` publican `blocked` con su motivo; que **`onContinueOffline()` desde `blocked` no
      cambia el estado**, que es la prueba que impide colarse; y que `onRetry()` sí vuelve a
      preparar.
- [X] T050 [US3] `APP/UI/Splash/SplashContentView.swift`: rama `blocked`, con el título y el mensaje
      de cada motivo —el de mantenimiento es **el que publica el servicio**, no una cadena nuestra—
      y **solo** el botón de reintentar. Identificador `splash_blocked`.
- [X] T051 [US3] `APP/Core/DI/AppContainer.swift`: los escenarios `updateRequired` y `maintenance`.
- [X] T052 [US3] `TEST/Integration/StartupFlowIntegrationTests.swift`: añadir el recorrido completo
      con una versión mínima publicada por encima de la instalada, y otro con mensaje de
      mantenimiento, **desde la fuente de datos** y no desde un doble del repositorio.
- [X] T053 [US3] `UITEST/Splash/SplashStatesUITests.swift` (parte de US3): los dos escenarios
      muestran su mensaje, **no existe ningún botón que lleve al contenido principal**, y mandar la
      aplicación a segundo plano y recuperarla tampoco cuela (SC-005).

**Checkpoint**: la puerta cierra, y hay una prueba que lo demuestra por las tres vías.

---

## Phase 6: User Story 4 — Una portada que se ve institucional y se lee siempre (P3)

**Goal**: la portada es indistinguible de la referencia, no cambia con el tema del sistema y se lee
entera al 200 %.

**Independent Test**: capturar con tema claro y con oscuro y comparar entre sí y con la imagen de
referencia; repetir al 200 % de tamaño de texto.

- [X] T054 [US4] `APP/UI/Splash/SplashContentView.swift` **(FR-019, FR-020, FR-021)**: composición
      completa del contrato §6 —escudo a 104 pt por encima del centro óptico, 24 pt hasta `BOC`,
      denominación en dos líneas, línea de 120 × 2 pt, autoría en dos colores y el bloque
      autoría + indicador anclado abajo respetando el área segura—. **Todo desde `BocTheme`**: ni
      un color, ni un tamaño, ni un espaciado literal (FR-024).
- [X] T055 [US4] `APP/UI/Splash/SplashContentView.swift`: los cuatro `#Preview`, uno por estado,
      siguiendo lo que hace `HomeContentView`.
- [X] T056 [US4] **SC-009** Verificar a mano contra `docs/diseno/pantalla-arranque-referencia.png`
      (paso 8a del quickstart). El texto de autoría es **el de la especificación**, no el de la
      imagen, que está desactualizada.
- [X] T057 [US4] **SC-009** Verificar que las capturas con tema claro y oscuro del sistema son
      **idénticas** byte a byte (paso 8b del quickstart).
- [X] T058 [US4] **SC-008** Verificar al 200 % de tamaño de texto que la jerarquía se conserva y
      **ningún texto queda recortado**, en los cuatro estados; los de error y bloqueo son los que
      más texto llevan.
- [X] T059 [US4] **FR-026** Verificar que la interfaz permanece vertical al girar el dispositivo.

**Checkpoint**: la portada es la del documento de diseño, y se lee en cualquier ajuste.

---

## Phase 7: Cierre y puertas de calidad

- [X] T060 **Paso 2 del quickstart**: provocar a mano las tres violaciones y comprobar que las
      reglas **se ponen en rojo**: (a) que `Domain/Model/AppConfig.swift` nombre
      `RemoteConfigValues`; (b) un `Color(` literal en `UI/Splash/SplashContentView.swift`;
      (c) borrar `TEST/Domain/AppVersionTests.swift`. Después `git checkout -- .` y las tres deben
      volver a pasar. **Una regla que no puede fallar no protege nada.**
- [X] T061 **SC-010** Paso 3 del quickstart: retirar `GoogleService-Info.plist` del puesto y
      comprobar que la construcción, las pruebas y el arranque **hasta el contenido principal**
      siguen en verde.
- [X] T062 **FR-002** Paso 4 del quickstart: grabar el arranque y revisar los primeros fotogramas.
      Ningún fotograma blanco, el escudo **no se mueve ni cambia de tamaño**, y no hay barra de
      estado en la portada.
- [X] T063 **SC-001, SC-002** Paso 6 del quickstart: medir el tiempo hasta el contenido principal y
      los fotogramas de portada. **Anotar las dos cifras aquí abajo**, no un «cumple».
- [X] T064 **FR-018** Paso 9 del quickstart: comprobar en el registro del dispositivo que cada
      escenario de fallo deja **una** línea con su motivo, y que no aparece ninguna credencial ni
      ningún mensaje del servicio.
- [X] T065 Actualizar `CLAUDE.md` si esta feature deja una trampa nueva que merezca la pena
      recordar —la del reloj inmediato contra el límite de espera (D-211) es candidata firme—.

### Las cuatro puertas

No hay CI, por la constitución 1.1.0: se ejecutan aquí y **el resultado se anota con cifras**.

- [X] T066 Puerta 1 · Construcción: `xcodebuild ... -quiet build` → **en verde, 7,07 s**
      (incremental sobre datos derivados calientes; la limpia recompila Firebase entero)
- [X] T067 Puerta 2 · Pruebas sin interfaz: `-only-testing:BOCantabria-iosTests` →
      **116 pruebas en 19 suites, 0,177 s**, todas en verde (eran 58 al empezar la feature)
- [X] T068 Puerta 3 · Pruebas de interfaz: `-testPlan UITests` →
      **16 pruebas en 78,8 s**, todas en verde (eran 6 al empezar la feature)
- [X] T069 Puerta 4 · Sin avisos nuevos: `grep -c "warning:"` → **0 avisos del compilador**.
      El único que aparece es de `appintentsmetadataprocessor` de Apple («No AppIntents.framework
      dependency found»), preexistente y ajeno al código

---

## Dependencies & Execution Order

### Entre fases

- **Setup (1)**: sin dependencias. T005 depende de T004.
- **Foundational (2)**: depende de Setup. **Bloquea todas las historias.**
- **US1 (3)**: depende de Foundational. Es el MVP.
- **US2 (4)** y **US3 (5)**: dependen de Foundational y comparten tres ficheros con US1
  —`SplashViewModel`, `SplashContentView` y `AppContainer`—, así que **no se paralelizan entre
  sí**: se hacen en orden. Cada una es demostrable por separado en cuanto termina.
- **US4 (6)**: depende de que existan los cuatro estados, porque los verifica todos.
- **Cierre (7)**: depende de todo lo anterior.

### Dentro de cada historia

- La prueba de una pieza va **con** la pieza, no al final.
- Dominio antes que datos; datos antes que presentación; presentación antes que interfaz.
- Ninguna tarea se cierra con su prueba en rojo, y **prohibido** `.disabled`.

### Paralelismo real

```bash
# Phase 1, tras T001:
T002 (cadenas) · T003 (Strings) · T006 (recurso del lanzamiento)

# Phase 2, los modelos de dominio y sus pruebas:
T007+T008 (AppVersion) · T009+T010 (AppConfig) · T011 (StartupStatus) · T013 (protocolos)

# Phase 2, la capa de datos, tras los protocolos:
T014 · T015 · T017 · T020 · T021+T022 · T023
```

---

## Implementation Strategy

### MVP primero

1. Phase 1 y Phase 2 completas.
2. Phase 3 (US1): la aplicación arranca por la portada y entra sola.
3. **Parar y validar**: pasos 4, 5 (`ready`) y 6 del quickstart.

### Entrega incremental

1. Base lista → US1 → **MVP demostrable**.
2. + US2 → ningún fallo atrapa a nadie.
3. + US3 → la puerta cierra.
4. + US4 → la portada es la del documento de diseño.
5. Cierre y las cuatro puertas.

### Integración

Cuando las cuatro puertas estén en verde, la feature está **terminada**, no integrada. El merge
`--no-ff` sobre `main` lo pide el propietario, y la rama **se conserva**.

---

## Notes

- `[P]` = ficheros distintos y sin dependencias entre sí.
- Tres ficheros se tocan desde tres historias (`SplashViewModel`, `SplashContentView`,
  `AppContainer`). Están marcados sin `[P]` a propósito.
- Las cifras de las puertas se escriben en T066…T069. Un «pasa» no vale: es lo único que después
  permite saber si se ejecutaron.
