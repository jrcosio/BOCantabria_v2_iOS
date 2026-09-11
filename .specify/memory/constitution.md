<!--
Sync Impact Report
==================

--- Ratificación inicial 1.0.0 (2026-09-11) ---
Version change: (ninguna) → 1.0.0
Motivo del bump: ratificación inicial de la constitución del proyecto iOS.

Origen: este documento es la traducción a iOS de la constitución 1.1.0 del proyecto
Android `BOCantabria_v2`, conservada íntegra en
`docs/referencia-android/constitucion-android.md`. Los seis principios se mantienen
uno a uno; lo que cambia son las tecnologías que los materializan, porque los
mecanismos que la norma de Android nombraba no existen en esta plataforma.

Principios definidos (nuevos, equivalentes a los de Android):
- I.   Desarrollo Dirigido por Especificación (SDD) — NO NEGOCIABLE
- II.  Arquitectura Limpia por Capas
- III. MVVM en la Capa de Presentación
- IV.  Inyección de Dependencias por Composition Root
- V.   Testing Exigente — NO NEGOCIABLE
- VI.  Observabilidad Desacoplada (Firebase)

Secciones añadidas:
- Restricciones Tecnológicas (SECTION_2)
- Flujo de Trabajo y Puertas de Calidad (SECTION_3)
- Governance

Divergencias respecto a la norma de Android, todas deliberadas y aprobadas por el
propietario antes de redactar este documento:

1. **Principio IV: Koin → composition root manual.** Koin no existe en iOS y ningún
   contenedor de Swift reproduce su `verify()` sin resolver en tiempo de ejecución.
   Un contenedor escrito a mano con dependencias por inicializador da una garantía
   MÁS FUERTE que la que la norma de Android pedía: un cableado incompleto no
   compila, en vez de fallar en el móvil. El requisito de «grafo verificable por un
   test» se conserva y se refuerza.
2. **UI: Jetpack Compose + Material 3 → SwiftUI.** La prohibición equivalente a «ni
   XML de layouts ni Fragments» es «ni UIKit ni Storyboards», con la excepción
   acotada y nombrada de PDFKit, que no tiene equivalente en SwiftUI.
3. **Persistencia: Room → GRDB.swift.** Decidido por el propietario. GRDB da SQL
   crudo, migraciones versionadas y `ValueObservation`, que es el equivalente exacto
   de los `Flow` de Room. SwiftData se descartó: sin SQL crudo, los invariantes que
   la aplicación Android protege con pruebas de regresión —el `upsert` que devuelve
   las claves insertadas, la deduplicación por índice único, la lista blanca de
   columnas de un `UPDATE`, el `LIKE ... ESCAPE`— habría que reimplementarlos en
   Swift, perdiendo la garantía a nivel de base de datos que es justamente lo que
   los hace fiables.
4. **Red: OkHttp → URLSession.** `async/await` sobre `URLSession` es cancelable de
   verdad, así que la lección de la feature 014 de Android (`Call.await`) llega
   resuelta por construcción. El motivo se conserva escrito porque el fallo que
   corrige sigue siendo posible con cualquier llamada bloqueante.
5. **Plataforma: `minSdk 28` → iOS 18.0, solo iPhone y solo vertical.** El criterio
   es el mismo que llevó a `minSdk 28`: la cobertura más amplia que no obliga a
   escribir caminos de compatibilidad.
6. **Dependencias: `gradle/libs.versions.toml` → Swift Package Manager.** La regla
   de fondo —una sola declaración, versión fijada, nunca una coordenada suelta— se
   mantiene; el sitio es ahora la sección de paquetes del proyecto Xcode.
7. **Reglas de arquitectura: Konsist → prueba propia que analiza los ficheros
   fuente.** Swift no tiene Konsist. La prueba equivalente lee el árbol de fuentes y
   comprueba los `import` y los nombres, y falla la build igual que allí. Es texto
   en vez de AST y se dice en voz alta: cubre lo mismo con una herramienta más
   pobre, y por eso la lista de reglas se mantiene corta y explícita.

Notas: la plantilla base define 5 principios; este proyecto adopta 6, igual que el
de Android, según lo acordado con el propietario del repositorio.

Follow-up TODOs: ninguno. No quedan tokens sin sustituir.
-->

# Constitución de BOCantabria iOS

## Core Principles

### I. Desarrollo Dirigido por Especificación (SDD) — NO NEGOCIABLE

Toda feature DEBE recorrer el ciclo completo de GitHub Spec Kit antes de que se escriba una
sola línea de código de producto:

`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`

- PROHIBIDO escribir código de producto sin un `tasks.md` aprobado en `specs/<NNN>-<slug>/`.
- Si se solicita una feature directamente, la respuesta correcta es arrancar por
  `/speckit-specify`, nunca implementar.
- `/speckit-specify` crea además la rama `NNN-slug` mediante la extensión git de Spec Kit.
  Todo el trabajo de la feature vive en esa rama.
- RECOMENDADOS pero opcionales: `/speckit-clarify` antes de planificar y `/speckit-analyze`
  antes de implementar.
- EXENTOS del ciclo: configuración del proyecto Xcode, subidas de versión, erratas y
  documentación. La exención cubre configuración; NO cubre código de producto que se cuele
  bajo esa etiqueta.
- **Portar no exime.** Que una funcionalidad exista y esté probada en el proyecto Android no
  sustituye a su especificación aquí. Los requisitos funcionales se REUTILIZAN —son de
  producto y no de plataforma—, pero el `plan.md`, el `research.md` y el `tasks.md` se
  escriben para iOS, porque las decisiones técnicas no se heredan.

*Rationale*: la especificación es la fuente de verdad del proyecto. Sin ella, la intención
queda solo en la conversación y se pierde; con ella, cada decisión queda auditable y el
trabajo es reproducible por cualquiera.

### II. Arquitectura Limpia por Capas

El código se organiza en tres capas y las dependencias apuntan SIEMPRE hacia dentro:

`UI` → `Domain` ← `Data`

- `Domain` DEBE ser Swift puro: sin `import SwiftUI`, sin `UIKit`, sin `GRDB`, sin `Firebase`,
  sin `PDFKit`, sin referencias a `Data` ni a `UI`. Puede importar `Foundation`. Contiene
  modelos, protocolos de repositorio y casos de uso.
- `Data` implementa los protocolos declarados en `Domain`. Aquí viven las fuentes de datos
  (`Source/Local`, `Source/Remote`) y los SDK de terceros. Los modelos de `Data` (DTOs,
  registros de base de datos) NO cruzan hacia `UI`: se mapean a modelos de `Domain`.
- `UI` DEBE hablar exclusivamente con casos de uso de `Domain`. PROHIBIDO que un modelo de
  pantalla o una `View` dependa de un tipo de `Data`.
- `Core` aloja lo transversal (contenedor de dependencias, tema y componentes compartidos,
  utilidades) y NO DEBE contener lógica de negocio.

*Rationale*: aislar el dominio de los detalles técnicos es lo que permite cambiar de fuente
de datos, de SDK o de framework de interfaz sin reescribir las reglas de negocio, y lo que
hace que el dominio sea testeable sin simulador.

### III. MVVM en la Capa de Presentación

- Una pantalla = una `View` + un `ViewModel` + un `UiState` inmutable.
- El `ViewModel` DEBE ser `@MainActor @Observable` y exponer su estado como
  `private(set) var state: XxxUiState`. PROHIBIDO exponer estado mutable hacia fuera.
- `UiState` DEBE ser una `struct` o un `enum` inmutable. Los eventos de usuario se modelan
  como métodos públicos del `ViewModel`.
- Las `View` DEBEN ser tontas: renderizan estado y emiten eventos. PROHIBIDA la lógica de
  negocio dentro del `body` de una vista.
- Las vistas reutilizables DEBEN ser sin estado y recibirlo por parámetro, para poder
  previsualizarse y probarse aisladas.

*Rationale*: un estado único e inmutable elimina las inconsistencias de interfaz y hace que
cada pantalla sea verificable con una prueba que solo observa un valor.

### IV. Inyección de Dependencias por Composition Root

- Todo el grafo de dependencias DEBE declararse en un único `AppContainer` bajo `Core/DI`.
- Las dependencias se reciben por INICIALIZADOR y siempre detrás de un protocolo declarado
  en `Domain`. PROHIBIDO instanciar dependencias dentro de la clase que las usa, usar
  variables globales mutables, *singletons* propios o localizadores de servicios.
- PROHIBIDO `@Environment` o `@EnvironmentObject` como vía de inyección de casos de uso o
  repositorios: el grafo se arma en el composition root, no se descubre en el árbol de
  vistas.
- El grafo DEBE ser verificable: existe una prueba que construye el `AppContainer` completo y
  resuelve todos los modelos de pantalla. Como el cableado es por inicializador, una
  dependencia que falte NO COMPILA; la prueba cubre lo que el compilador no ve —que el
  contenedor real se construye sin efectos de arranque y que los ámbitos son los previstos—.

*Rationale*: si el grafo se declara en un único sitio y su construcción está cubierta, los
fallos de cableado se detectan al compilar o en CI, y no en tiempo de ejecución en el móvil
de la persona que usa la aplicación.

### V. Testing Exigente — NO NEGOCIABLE

Ningún elemento de `tasks.md` se considera terminado sin su prueba correspondiente en verde.

Pirámide obligatoria:

1. **Unitarias** (`BOCantabria-iosTests`) — casos de uso, repositorios y modelos de pantalla,
   con Swift Testing. Deben correr sin simulador de interfaz y sin red.
2. **Integración** (`BOCantabria-iosTests`) — construcción del `AppContainer` completo y
   flujos que atraviesan varias capas (`ViewModel → UseCase → Repository → Source`) usando el
   grafo real y dobles únicamente en la frontera externa.
3. **Interfaz** (`BOCantabria-iosUITests`) — cada pantalla tiene al menos una prueba que
   valida render y navegación, arrancando la aplicación con el contenedor de pruebas.

Reglas adicionales:

- Todo *bug* corregido DEBE incorporar una prueba de regresión que falle antes del arreglo.
- PROHIBIDO desactivar (`.disabled`), ignorar o comentar una prueba para hacer pasar la
  build. Si una prueba estorba, se arregla el código o se cambia la especificación.
- Las pruebas DEBEN ser deterministas: sin red real, sin reloj del sistema y sin depender del
  orden de ejecución. El reloj, la aleatoriedad y los ejecutores se inyectan.

*Rationale*: la única garantía real de que una arquitectura limpia sigue siendo limpia es que
esté cubierta por pruebas que se ejecuten en cada cambio.

### VI. Observabilidad Desacoplada (Firebase)

- La aplicación DEBE reportar analítica (Firebase Analytics) y errores (Firebase Crashlytics).
- Los SDK de Firebase SOLO pueden invocarse desde implementaciones en `Data`. PROHIBIDO
  llamar a `Analytics`, `Crashlytics` o `RemoteConfig` desde un modelo de pantalla, una vista,
  un caso de uso o cualquier tipo de `Domain`.
- El acceso se hace a través de abstracciones propias (`AnalyticsTracker`, `CrashReporter`)
  declaradas fuera de `Data` e inyectadas por el contenedor, de modo que en pruebas se
  sustituyan por dobles sin necesidad de Firebase.
- PROHIBIDO registrar datos personales identificables en eventos de analítica o en trazas de
  Crashlytics.

*Rationale*: envolver el SDK mantiene el dominio testeable y deja la puerta abierta a cambiar
de proveedor de telemetría sin tocar la lógica de la aplicación.

## Restricciones Tecnológicas

Estas decisiones son vinculantes; cambiarlas requiere una enmienda de esta constitución.

- **Plataforma**: iOS nativo, Swift 6 con concurrencia estricta. `IPHONEOS_DEPLOYMENT_TARGET`
  18.0, solo iPhone (`TARGETED_DEVICE_FAMILY = 1`) y solo orientación vertical, que es la
  misma decisión de producto que en Android.
- **UI**: SwiftUI. PROHIBIDO introducir Storyboards, XIB o pantallas escritas en UIKit. La
  ÚNICA excepción es la interoperabilidad acotada con **PDFKit** para el visor del documento
  oficial, que DEBE quedar encerrada tras una vista propia y no puede filtrar tipos de PDFKit
  al resto de la aplicación.
- **DI**: composition root propio. PROHIBIDOS Swinject, Factory, `swift-dependencies` y
  cualquier otro contenedor de terceros.
- **Asincronía**: `async/await`, `AsyncSequence` y actores. PROHIBIDOS Combine en código
  nuevo, `DispatchQueue` suelta y las llamadas con *callback* en API internas.
- **Persistencia**: **GRDB.swift**. La base de datos es la única fuente de verdad de lo que la
  pantalla muestra, con migraciones versionadas y observación por `ValueObservation`.
  PROHIBIDOS SwiftData y Core Data.
- **Red**: **URLSession** con `async/await`. PROHIBIDO Alamofire y cualquier otro cliente
  HTTP de terceros.
- **Dependencias**: TODAS se declaran en la sección de paquetes del proyecto Xcode, con
  versión fijada y `Package.resolved` versionado. PROHIBIDO añadir una dependencia sin
  justificarla en el `plan.md` de la feature que la necesita. Las dependencias de terceros
  admitidas hoy son exactamente dos familias: GRDB y Firebase.
- **Tema**: la aplicación tiene un ÚNICO tema, el claro, y NO responde al ajuste claro/oscuro
  del sistema. Es la misma decisión de producto que en Android.
- **Idioma**: el código, los nombres y los comentarios se escriben en inglés; las
  especificaciones, la documentación y la comunicación con el propietario, en español. Los
  textos de la interfaz son los mismos que en Android, en español.

## Flujo de Trabajo y Puertas de Calidad

- **Ramas**: `main` es la rama estable. Cada feature vive en su rama `NNN-slug` creada por
  Spec Kit. PROHIBIDO implementar una feature directamente sobre `main`.
- **Commits**: mensaje en español, imperativo, con prefijo tipo Conventional Commits
  (`feat:`, `fix:`, `test:`, `refactor:`, `chore:`, `docs:`).
- **Puertas de calidad** — antes de dar una feature por terminada DEBEN pasar, en este orden:
  1. `xcodebuild build` sobre el esquema de la aplicación
  2. `xcodebuild test` con el plan de pruebas unitarias y de integración
  3. `xcodebuild test` con el plan de pruebas de interfaz
  4. Análisis estático: compilación sin avisos nuevos
- **CI**: GitHub Actions ejecuta build, pruebas unitarias y análisis estático en cada push y
  cada pull request. Una feature con CI en rojo NO se integra en `main`.
- **Revisión**: toda integración en `main` DEBE verificar el cumplimiento de esta
  constitución. Cualquier desviación se documenta y se justifica de forma explícita en el
  `plan.md` de la feature, en su sección de complejidad.

## Governance

Esta constitución PREVALECE sobre cualquier otra práctica, convención heredada o preferencia
puntual. En caso de conflicto entre `CLAUDE.md` y este documento, manda este documento. La
constitución del proyecto Android es **material de referencia, no norma aquí**: cuando las dos
discrepen, manda esta.

- **Enmiendas**: modificar esta constitución requiere (a) la aprobación explícita del
  propietario del repositorio, (b) actualizar `CLAUDE.md` en el mismo cambio para que la guía
  operativa no contradiga a la norma, y (c) registrar el cambio en el Sync Impact Report de la
  cabecera de este fichero.
- **Versionado semántico** de la constitución:
  - **MAJOR**: se elimina o se redefine un principio de forma incompatible con lo anterior.
  - **MINOR**: se añade un principio o una sección, o se amplía materialmente la guía.
  - **PATCH**: aclaraciones, redacción y correcciones sin cambio de significado.
- **Cumplimiento**: cada `/speckit-plan` DEBE incluir una comprobación de alineamiento con
  estos principios, y `/speckit-analyze` DEBE señalar cualquier incoherencia entre spec, plan
  y tasks respecto a esta constitución.
- **Complejidad**: toda desviación (una capa extra, una dependencia nueva, un patrón no
  contemplado) DEBE justificarse por escrito. Ante la duda, gana la opción más simple.
- **Guía operativa**: `CLAUDE.md` en la raíz del repositorio traduce estos principios a
  comandos y convenciones del día a día.

**Version**: 1.0.0 | **Ratified**: 2026-09-11 | **Last Amended**: 2026-09-11
