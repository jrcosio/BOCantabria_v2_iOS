# CLAUDE.md

Guía operativa para Claude Code en este repositorio.

> Este fichero es la **guía operativa**; la **constitución** (`.specify/memory/constitution.md`)
> es la norma. Si enmiendas una, actualiza la otra en el mismo cambio.

---

## Qué es este repositorio

Puerto a **iOS nativo (Swift 6 + SwiftUI)** de la aplicación del **Boletín Oficial de
Cantabria**, cuya versión Android está terminada en `../BOCantabria` y se conserva aquí como
material de referencia bajo `docs/referencia-android/`.

**El Android es la fuente de los requisitos, no del diseño técnico.** Sus quince features están
íntegras en `docs/referencia-android/specs/` y sus requisitos funcionales se reutilizan porque
son de producto; el `plan.md`, el `research.md` y el `tasks.md` se escriben para iOS. Está
escrito así en el principio I de la constitución, y es la trampa más probable de este proyecto:
copiar una decisión de Kotlin porque «ya estaba resuelta».

---

## Regla número uno: SDD obligatorio

Este proyecto usa **Spec-Driven Development** con **GitHub Spec Kit**. Toda feature recorre el
ciclo completo antes de tocar código de producto:

```
/speckit-specify  →  /speckit-plan  →  /speckit-tasks  →  /speckit-implement
```

- **No escribas código de producto sin un `tasks.md` aprobado** en `specs/<NNN>-<slug>/`.
  Si te piden una feature directamente, arranca por `/speckit-specify`.
- `/speckit-specify` crea también la rama `NNN-slug` (extensión git de Spec Kit).
- Opcionales pero recomendados: `/speckit-clarify` antes de planificar, `/speckit-analyze`
  antes de implementar.
- **Exentos del ciclo**: configuración del proyecto Xcode, subidas de versión, erratas y
  documentación.

Las normas del proyecto viven en `.specify/memory/constitution.md`.

### Comandos Spec Kit disponibles

| Comando | Cuándo |
|---|---|
| `/speckit-specify` | Arranque de toda feature. Crea rama + `specs/NNN-slug/spec.md` |
| `/speckit-clarify` | Opcional, **antes** de `/speckit-plan`. Resuelve ambigüedades |
| `/speckit-plan` | Diseño técnico → `plan.md` |
| `/speckit-tasks` | Descomposición ejecutable → `tasks.md` |
| `/speckit-checklist` | Opcional, tras `/speckit-plan`. Calidad de requisitos |
| `/speckit-analyze` | Opcional, **antes** de `/speckit-implement`. Coherencia spec/plan/tasks |
| `/speckit-implement` | Ejecuta `tasks.md`. Único punto donde se escribe código de producto |
| `/speckit-constitution` | Enmendar las normas del proyecto |

### Orden de portado previsto

El mismo que en Android, y por la misma razón: cada feature se apoya en la anterior.

| iOS | Android de origen | Contenido |
|---|---|---|
| 001 | `001-esqueleto-arquitectura` | Capas, contenedor, tema, telemetría, reglas de arquitectura |
| 002 | `002-pantalla-arranque` | Portada, versión mínima y mantenimiento (Remote Config) |
| 003 | `003-boletin-del-dia` | Las diecinueve fuentes, analizador RSS, GRDB, Inicio |
| 004 | `004-detalle-publicacion` | Detalle, descarga validada del PDF y visor |
| 005 | `005-publicaciones-guardadas` | Guardados |
| 006 | `006-buscar` | Buscar global con filtros y orden |
| 007 + 009 + 010 | `007`, `009-resumen-gemini`, `010-gemini-sdk-oficial` | Resumen IA sobre el documento subido |
| 008 | `008-acerca-de` | Acerca de |
| 011 | `011-preguntar-al-boc` | Preguntar sobre el documento |
| 012 | `012-avisos` | Avisos: reglas, coincidencias y notificaciones |
| 013 | `013-inicio-secciones-y-panel` | Secciones, subsecciones y panel |
| 014 | `014-estabilidad-auditoria` | Las correcciones de estabilidad que sigan aplicando |
| 015 | `015-buscar-solo-filtros` | Filtros que bastan para buscar |

Las features 009 y 010 de Android son la historia de dos cambios de proveedor de IA. Aquí se
llega directamente al estado final, pero **el porqué se conserva**: está resumido abajo, en
«Servicio de IA», y completo en `docs/referencia-android/specs/`.

---

## Comandos

El esquema es `BOCantabria-ios` y el simulador de referencia, un iPhone 17 Pro.

| Tarea | Comando |
|---|---|
| Compilar | `xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` |
| Pruebas unitarias + integración | `xcodebuild ... -only-testing:BOCantabria-iosTests test` |
| Pruebas de interfaz | `xcodebuild ... -only-testing:BOCantabria-iosUITests test` |
| Una sola prueba | `xcodebuild ... -only-testing:BOCantabria-iosTests/HomeViewModelTests/loadsPublications test` |
| Limpiar | `xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios clean` |
| Resolver paquetes | `xcodebuild -resolvePackageDependencies -project BOCantabria-ios.xcodeproj` |

- Añade `-quiet` siempre: la salida completa de `xcodebuild` son decenas de miles de líneas y
  el error real se pierde. Para diagnosticar, `grep -E "error:|warning:"` sobre el log.
- Usa `-derivedDataPath` fuera del repositorio para no ensuciarlo.
- Las pruebas necesitan el simulador arrancado; la primera tanda tras un `clean` recompila
  Firebase entero y tarda varios minutos.

---

## Arquitectura

Arquitectura limpia + MVVM, un solo target de aplicación, separación por carpetas bajo
`BOCantabria-ios/`:

```
Core/
  DI/           AppContainer: el grafo entero, declarado en un sitio y armado por
                inicializador. Único punto de entrada
  Telemetry/    Protocolos AnalyticsTracker y CrashReporter + AnalyticsEvent
  UI/Theme/     Sistema de diseño: Color, Typography, Spacing, Shape, Elevation, BocTheme
  UI/Component/ Vistas compartidas sin estado, incluida PublicationCard
  Util/         Reloj, aleatoriedad, ejecutores, SearchText, RelativeTime y demás
                utilidades transversales
Data/
  Repository/     Implementaciones de los protocolos de Domain
  Source/Local/   GRDB: BocDatabase, registros, consultas y migraciones
  Source/Remote/  URLSession, el catálogo de las diecinueve fuentes, el analizador, el
                  normalizador y el cliente del servicio de IA
  Telemetry/      Implementaciones de Firebase. ÚNICO sitio que toca el SDK
  Notification/   UNUserNotificationCenter. ÚNICO sitio que lo toca
  Background/     BGTaskScheduler. ÚNICO sitio que lo toca
Domain/
  Model/          Modelos de dominio, Swift puro (AppResult, DomainError, Publication,
                  BocSection, HomeSelection, SyncSummary…)
  Repository/     Protocolos de repositorio (contratos)
  UseCase/        Casos de uso, una operación por tipo
UI/
  Splash/         Arranque
  Main/           Armazón: pestañas inferiores y panel de secciones
  Home/           Inicio
  Detail/         Detalle de la publicación
  PDF/            Visor del documento. ÚNICO sitio que toca PDFKit
  Ask/            Preguntar sobre el documento
  Search/         Buscar
  Saved/          Guardados
  Alerts/         Avisos, con Alerts/Form para crear, editar y duplicar
  Info/           Acerca de
  Share/          Compartir el PDF, común a las tres pantallas
  Navigation/     Rutas tipadas y destinos
BOCantabriaApp.swift   Punto de entrada: construye el AppContainer
```

**Regla de dependencias**: `UI → Domain ← Data`. Siempre hacia dentro.

- `Domain` es Swift puro: **cero** `SwiftUI`, `UIKit`, `GRDB`, `Firebase` o `PDFKit`. Puede
  importar `Foundation`.
- `Data` implementa lo que `Domain` declara. Sus DTOs y registros **no** cruzan a `UI`: se
  mapean a modelos de `Domain`.
- `UI` solo habla con casos de uso. Un `ViewModel` **nunca** importa nada de `Data`.
- `Core` es transversal y no contiene lógica de negocio.

### Flujo de una operación

```
View → ViewModel → UseCase → Repository (protocolo en Domain)
                                   ↓
                     RepositoryImpl (Data) → DataSource
```

---

## Convenciones

### Presentación (MVVM)

- Una pantalla = `XxxView.swift` + `XxxViewModel.swift` + `XxxUiState.swift`.
- `@MainActor @Observable final class XxxViewModel`, con `private(set) var state: XxxUiState`.
- `UiState` inmutable (`struct` o `enum`). Eventos = métodos públicos del `ViewModel`.
- Vistas tontas: renderizan estado y emiten eventos. Cero lógica de negocio en un `body`.
- Componentes reutilizables **sin estado**, con el estado izado al llamante.
- **El `ViewModel` no se construye dentro de la vista.** Lo entrega el contenedor y la vista lo
  recibe por inicializador, dentro de un `@State`.

### Inyección de dependencias

- Todo el grafo en `Core/DI/AppContainer`. Nunca instanciar dependencias a mano dentro de quien
  las usa.
- Nada de `@Environment` ni `@EnvironmentObject` para casos de uso o repositorios.
- Al añadir una dependencia, actualiza el contenedor **y** la prueba que lo construye entero.

### Concurrencia

- **Swift 6 con concurrencia estricta**, `SWIFT_VERSION = 6.0` y
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- **El aislamiento por defecto es `nonisolated`, y se cambió a conciencia.** La plantilla de Xcode
  lo deja en `MainActor` y la feature 001 lo dio por bueno al planificar; al implementar se vio que
  es al revés de lo que esta arquitectura necesita. Con `MainActor` por defecto, los tipos de
  `Domain` y `Core/Telemetry` nacen aislados al actor principal y **dejan de compilar en cuanto un
  `actor` de `Data` o un doble de pruebas los toca** —lo destapó el primer espía de analítica, con
  tres errores seguidos—, así que habría que sembrar `nonisolated` por las dos capas que nunca
  deben estar en el actor principal. Puesto en `nonisolated`, la anotación cae donde tiene
  sentido: el modelo de pantalla se marca `@MainActor` —cosa que la regla de arquitectura 5 ya
  exige— y las vistas lo son por su propio protocolo. **La regla general**: el ajuste por defecto
  de una plantilla describe la aplicación que la plantilla imagina, que es una sin capa de datos.
- El trabajo de `Data` va en tipos `actor` o funciones `nonisolated`; nunca bloquees el actor
  principal con E/S.
- **El reloj, la aleatoriedad y el planificador se inyectan**, nunca se referencian
  estáticamente. Es lo que hace deterministas las pruebas.
- **`Task` sin dueño está prohibido.** Toda tarea de un `ViewModel` vive en `.task` de la vista
  o en una propiedad cancelada en su sitio; una tarea suelta sobrevive a la pantalla y escribe
  en un estado que ya no se ve.

### Sistema de diseño

- **La aplicación tiene un único tema, el claro.** No responde al ajuste claro/oscuro del
  sistema. El proyecto fija `INFOPLIST_KEY_UIUserInterfaceStyle = Light`, que es la traducción
  literal de la decisión de Android, y **ese ajuste es el mecanismo, no un valor por defecto**:
  no añadas `@Environment(\.colorScheme)` ni variantes oscuras a los recursos de color.
- **Nunca escribas un color, un tamaño o un espaciado literal.** Todo sale de `BocTheme`:
  `BocTheme.colors`, `BocTheme.spacing`, `BocTheme.typography`, `BocTheme.shape`.
- Hay una regla de arquitectura que **falla la build** si un fichero fuera de `Core/UI/Theme`
  construye un `Color(` literal o usa `.red`, `.blue` y compañía.
- El azul institucional no cambia entre pantallas ni entre dispositivos.
- `AccentColor` del catálogo vale `#063B5C`, el mismo `BocPrimary`, y **debe mantenerse
  sincronizado** con el token del tema: lo consume el sistema antes de que exista `BocTheme`.
- Los pesos 650 del documento de diseño se implementan como `.semibold`, el peso real más
  cercano, igual que en Android.
- **Fidelidad acordada con el propietario: híbrida.** Navegación y gestos nativos de iOS
  —`NavigationStack`, `TabView`, hojas, deslizar para volver—; sistema de diseño portado a la
  letra —tokens de color, escala tipográfica, espaciados, formas— y los iconos de Material
  convertidos, no SF Symbols. Si dudas entre las dos, manda el documento de diseño para lo que
  se ve y manda la HIG para cómo se comporta.

### Iconos y recursos

- Los **cincuenta y un iconos** del catálogo se generaron desde los VectorDrawable de Android
  con `Tools/vector-drawable-to-svg.py`. Si cambia un icono allí, se regenera aquí; no se
  editan a mano.
- Los de un solo color van con `template-rendering-intent: template` y se tiñen en el punto de
  uso, exactamente como Compose teñía el `android:fillColor` marcador de posición. El escudo
  (`ic_escudo_cantabria`, `ic_splash_emblem`) va como `original`: es multicolor.
- **No los sustituyas por SF Symbols.** El documento de diseño los especifica uno a uno en su
  apartado 9.2.
- El icono de la aplicación se compuso desde `ic_launcher-playstore.png` a 1024×1024 **sin
  canal alfa**: iOS rechaza un icono con canal alfa aunque sea completamente opaco, y el de
  Android lo tenía.

### Resultados y errores

- Las operaciones de dominio devuelven `AppResult<T>` (`success` / `failure`), **no**
  `Swift.Result` a secas ni `throws`: el error viaja como `DomainError` enumerado, así el
  `switch` de la pantalla es exhaustivo y el compilador avisa al añadir un caso.
- Una lista vacía es `success([])`, no un fallo. «Vacío» y «error» se distinguen en la capa de
  presentación.
- Los errores **no** salen de `Data`: se capturan y se traducen ahí. La cancelación
  (`CancellationError`) se repropaga siempre.
- **Un `catch` que no escribe nada convierte un fallo en un misterio.** Heredado de Android:
  tres sitios que abrían un PDF se tragaban la excepción y un fichero ilegible y un proceso
  muerto se veían igual —nada en pantalla y nada en el registro—. Todo `catch` informa por
  `CrashReporter.log`; nunca el contenido del documento ni la credencial.

### Capa de datos

- **Persistencia: GRDB.** La base de datos es la única fuente de verdad de lo que la pantalla
  muestra. La pantalla observa con `ValueObservation`; la sincronización solo escribe.
- **Red: URLSession con `async/await`.** Diecinueve GET de XML crudo, con un tope de
  concurrencia. `async/await` **sí cancela de verdad** la llamada, que es justo lo que costó
  una feature entera en Android (la 014 sustituyó `Call.execute()` por `Call.await` porque
  cambiar de hilo no hace cancelable una E/S bloqueante). Aquí llega resuelto por
  construcción; se anota porque la lección sigue valiendo para cualquier llamada bloqueante
  que alguien meta a mano.
- **El XML se analiza con `XMLParser`**, el SAX de Foundation. `XMLDocument` **no existe en
  iOS**: es solo de macOS, así que no lo busques. Va endurecido en dos capas: una guarda de
  texto contra `<!DOCTYPE` y `<!ENTITY` —portátil— y `shouldResolveExternalEntities = false`.
- **Nunca se borra una publicación.** Ninguna consulta sobre `publications` declara un borrado,
  y es deliberado: una fuente solo publica sus últimos cien anuncios. Si aparece un `DELETE`
  sobre esa tabla en una revisión, hay que rechazarlo. **Desmarcar tampoco borra**: es un
  `UPDATE ... SET saved_at = NULL`.
- **La única sentencia `DELETE` del proyecto es la de las reglas de aviso**: es un dato de la
  persona, se borra a petición suya y detrás de un diálogo, y la clave ajena con `CASCADE` se
  lleva sus coincidencias. Debe existir la prueba de regresión que demuestra que borrar una
  regla deja `publications` con las mismas filas.
- **La marca de guardado es una columna `saved_at` nullable de `publications`**, y una
  sincronización **no puede pisarla**. No porque nadie la llame: porque el `UPDATE` de la
  sincronización es una **lista blanca de columnas** y `saved_at` no está en ella, igual que
  `first_seen_at` y `pending_alert_evaluation`. Si alguien las añade, la prueba de regresión se
  pone roja, que es exactamente para lo que está.
- **El texto de la búsqueda se normaliza al escribir, no al consultar.** `LIKE` de SQLite solo
  pliega mayúsculas para ASCII y **nunca** pliega tildes. Cada publicación guarda una columna
  `search_text` —título, organismo, jerarquía, referencia y nombre de sección y subsección, en
  minúsculas y sin tildes— y la consulta se normaliza igual antes de compararse.
  `Core/Util/SearchText` es el único sitio que decide qué significa normalizar: si cambia, lo
  ya escrito deja de concordar y hay que reconstruir la columna entera.
  **Caveat propio de iOS**: GRDB permite registrar funciones SQL y colaciones propias, y eso
  abre la tentación de normalizar en la consulta. **No lo hagas**: una colación propia obliga a
  reconstruir los índices y deja la base ilegible para cualquier herramienta externa. La
  decisión de normalizar al escribir se mantiene, y aquí por una razón más.
- **`%` y `_` hay que escaparlos con `ESCAPE '\'`**: sin ello, buscar `100%` devuelve el
  archivo entero, y no falla — miente.
- **Una columna nueva deja sin rellenar las filas anteriores, y eso no se ve en una instalación
  limpia.** Tras migrar, todo lo almacenado queda con la columna vacía, y una sincronización
  solo refresca los últimos cien anuncios de cada fuente. El relleno por lotes usa el valor
  vacío como marcador, de modo que el estado vive en la propia columna y no hay bandera que
  guardar. **El tamaño de lote se inyecta**, para que la prueba demuestre que el bucle da otra
  vuelta sin sembrar un archivo entero.
- **La deduplicación de los avisos la hace la base de datos, no un `if`.** `alert_matches` lleva
  `UNIQUE(rule_id, external_key)` y la inserción es `INSERT OR IGNORE`: una pareja ya
  registrada no vuelve a entregarse. Una publicación que coincide con dos reglas es dos filas y
  **una** notificación; el contador de la campana cuenta `COUNT(DISTINCT external_key)`.
- **La primera sincronización correcta de una instalación es línea base y no avisa de nada.** Se
  decide **una vez, antes** de lanzar los diecinueve feeds —con varios en paralelo, el segundo
  en terminar ya vería el éxito del primero—, y las filas de la línea base se insertan **con la
  marca de pendiente a cero**, no marcadas y limpiadas después.
- **Los avisos se evalúan contra una marca almacenada, no contra una lista en memoria.** La
  auditoría de Android demostró que si el registro de coincidencias fallaba o el proceso moría
  entre guardar el boletín y registrar la coincidencia, el aviso se perdía para siempre. La
  marca **solo se retira cuando las coincidencias han quedado registradas**, y el índice único
  hace que recuperar lo pendiente no duplique nada.
- **La sección la manda la fuente**, no el campo `categorias`, que se guarda en crudo y solo
  sirve para enriquecer y verificar. Razón: el feed 4.3 trae entradas con los componentes
  permutados, y la muestra está en `BOCantabria-iosTests/Fixtures/feed_4_3_anomalo.xml`.
- Nada que venga de la red se da por bueno sin validar: HTTPS, host del boletín, tipo de
  contenido, bytes mágicos `%PDF-`, tope de tamaño y SHA-256. Una página de error con HTTP 200
  no puede acabar guardada como documento oficial.
- **El lateral `.sha256` se valida al leer y se escribe atómicamente ANTES que el PDF.**
  Heredado de la auditoría de Android (STAB-001, severidad alta): un lateral vacío o truncado
  hacía que la caché construyera un documento con checksum inválido y la aplicación se cerraba
  al abrir esa publicación. Un lateral inválido es «huella perdida», igual que uno ausente, y
  la descarga lo repara. El orden importa porque **el checksum tiene consumidor**: decide si un
  resumen guardado está obsoleto, y regenerarlo cuesta cuota.
- **Todo camino de error de la copia local publica un estado terminal.** Heredado de STAB-002:
  devolver un fallo sin publicar el estado dejaba al detalle y al visor en «cargando» para
  siempre, porque las pantallas solo observan el estado.
- El PDF se guarda en el directorio de **cachés**, no en documentos, y la purga corre al
  terminar una sincronización. En iOS eso además es lo correcto de cara al sistema: el
  directorio de cachés es el que el sistema puede vaciar bajo presión de almacenamiento, y el
  que no se sube a la copia de seguridad.

### Servicio de IA

- **Resumen IA no se genera solo.** Solo al pulsar el botón: la cuota del servicio es gratuita,
  compartida por toda la organización y diaria, y resumir lo que nadie ha pedido la vaciaría en
  una tarde.
- La advertencia «Comprueba siempre el texto oficial» va **dentro** del texto al copiar o
  compartir, porque fuera de la aplicación el resumen pierde la tarjeta y la pantalla que lo
  enmarcaba.
- **No se envía el texto del documento: se envía el documento**, subido a la Files API del
  proveedor con el protocolo de subida reanudable. Consecuencia: un PDF escaneado se resume, y
  el juicio sobre si el documento sirve lo hace el servicio, así que un documento ilegible
  cuesta una petición.
- **El documento subido tiene dueño y tiene final**: como mucho uno vivo en todo el proceso, se
  reutiliza mientras se esté en esa publicación —regenerar no vuelve a subir— y se borra al
  salir del detalle. Preguntar y el visor se apilan **encima** del detalle, así que su sesión
  sigue viva mientras se usan.
- **Se cuentan las páginas antes de subir**, y ese invariante vive en UN solo sitio —el
  preparador del documento—, que es lo que mantiene un PDF protegido con contraseña dentro del
  dispositivo. Duplicar esas líneas duplica el invariante, y un invariante duplicado se cumple
  hasta que alguien arregla una de las dos copias.
- **En el esquema de la respuesta del chat, `scope` va PRIMERO y el resumen largo va el
  ÚLTIMO.** El orden de las propiedades es el orden de generación, y lo declarado después del
  campo largo se vacía si la generación se corta. En el resumen eso vaciaba una tarjeta; en el
  chat dejaría el ámbito en blanco, que es la defensa caída sin hacer ruido. **Un `scope`
  desconocido o ausente se trata como fuera de ámbito**: ante la duda, texto nuestro.
- **Cuando la respuesta se declara fuera de ámbito, lo que se pinta es texto nuestro y ni un
  carácter del suyo**, y esa sustitución va en el repositorio y no en la pantalla, para que
  ninguna pantalla futura pueda saltársela por descuido.
- **Cuando un prompt enumera qué rellenar, lo que no está en la lista es lo que se pierde.** Una
  versión del prompt decía que un análisis parcial no exime de rellenar «los campos
  estructurados»; el modelo obedeció al pie de la letra y dejó **el resumen** en blanco. El
  campo de prosa se declara obligatorio siempre.
- **Cancelar no devuelve la cuota** —se cuenta al pedir—, así que salir a mitad costaría lo
  mismo que terminar y encima perdería la respuesta. La petición de la conversación no corre en
  el ámbito de la pantalla; lo único que la cancela de verdad es salir de la publicación.
- **Una sola petición a la vez en toda la aplicación.** Pedir un resumen mientras hay una
  pregunta en el aire pone a la segunda a esperar. La cuota es del plan, no de la
  funcionalidad; se anota porque en el chat la espera se nota más y se diagnostica mal como
  cuelgue.
- **El identificador del modelo vive en una constante de dominio y el acceso va detrás de una
  fuente de datos.** Cambiar de proveedor en Android costó `Data/Source/Remote/` más tres
  constantes. Esas tres —modelo, versión de prompt, versión de esquema— se guardan con cada
  resumen; si alguna deja de coincidir, lo guardado queda **obsoleto, no borrado**. **No montes
  una cadena de reserva entre modelos**: el identificador guardado dejaría de ser determinista,
  y es la columna que decide qué está obsoleto.
- **Los ficheros que describen al proveedor llevan su nombre; los que describen nuestro formato,
  no.** Es lo que hizo barato el cambio de proveedor.
- **La credencial se lee de `Config/Secrets.xcconfig`**, que no se versiona, viaja al
  `Info.plist` generado y la lee un proveedor propio. **Si la clave falta, la build sigue en
  verde** y el valor es cadena vacía, que la pantalla traduce en «no configurado»; es lo que
  permite compilar y pasar las pruebas sin secretos. Es el equivalente exacto del
  `local.properties` + `BuildConfig` de Android. Nunca en el registro, ni en Crashlytics, ni en
  analítica: ni la clave ni el contenido del documento. **Nunca un interceptor de registro a
  nivel de cuerpo en el cliente de IA.**
- **Las claves de Gemini tienen dos formatos y hay que buscar los dos** al comprobar que el
  repositorio está limpio: el clásico empieza por `AIza` y el que se emite hoy, por `AQ.`
  —cincuenta y tres caracteres—. Buscar un solo prefijo, o el viejo, es exactamente cómo se da
  por limpio un repositorio que no lo está.
- **`GoogleService-Info.plist` NO se versiona, y la diferencia con Android es real.** Lleva un
  `API_KEY` que empieza por `AIza`. En Android el `google-services.json` sí está versionado a
  propósito porque allí la clave se restringe en la consola por **paquete y huella de firma**:
  sin el certificado de firma, otro no la puede usar. En iOS la restricción equivalente es solo
  el **identificador de paquete**, que no va acompañado de ninguna prueba criptográfica en la
  petición, así que el mismo razonamiento **no se traslada**. Se intentó trasladarlo en el
  commit de arranque y el escáner de secretos de GitHub lo cazó; el fichero se retiró del
  repositorio y de la historia.
  **Consecuencias que hay que tener presentes:**
  - El fichero va en `.gitignore`. Cada puesto lo descarga de la consola de Firebase
    (proyecto `bocantabria-6e90f`, app iOS `com.jrblanco.BOCantabria`) y lo coloca en
    `BOCantabria-ios/`. En CI entra como secreto del repositorio, nunca como fichero.
  - **La aplicación tiene que arrancar sin él.** `FirebaseApp.configure()` lanza si el fichero
    no está, así que la configuración va condicionada a su presencia y, cuando falta, los
    `AnalyticsTracker` y `CrashReporter` registrados en el contenedor son los de no operación.
    Es la misma promesa que con la credencial de IA: sin secretos, la build y las pruebas
    siguen en verde. Se implementa en la feature 001.
  - **Sacarlo del repositorio no convierte la clave en secreta**: viaja dentro del bundle de
    cualquier build distribuida y se extrae de un IPA. La mitigación de verdad es
    **restringirla en Google Cloud** —a la app iOS y a las APIs que se usan— y rotarla si se
    sospecha abuso. El escáner solo protege del acceso casual a un repositorio público.

### Firebase

- Los SDK solo se tocan desde `Data`. Nunca desde `UI`, `Domain` ni un `ViewModel`.
- Se usan a través de abstracciones propias (`AnalyticsTracker`, `CrashReporter`) inyectadas
  por el contenedor, para poder sustituirlas por dobles en pruebas.
- Nunca registres datos personales identificables en eventos ni en trazas. **Las palabras, el
  nombre y el organismo de una regla de aviso son intereses personales**: nunca a analítica, a
  Crashlytics ni al registro. Solo recuentos y enumerados. Los nombres de las reglas **sí** van
  en la notificación, porque esa es su función.
- El proyecto de Firebase es `bocantabria-6e90f`, el mismo que Android, y la aplicación iOS
  está registrada con el identificador `com.jrblanco.BOCantabria`. **No lo renombres** sin dar
  de alta antes una app nueva en la consola.

### Nombres e idioma

- Código, nombres y comentarios en **inglés**.
- Specs, documentación, mensajes de commit y comunicación con el propietario, en **español**.
- Protocolo `XxxRepository` en `Domain`, implementación `XxxRepositoryImpl` en `Data`.
- Casos de uso en imperativo: `GetBulletinsUseCase`, con un único `callAsFunction`.
- Los textos de la interfaz son los mismos que en Android. El original está en
  `docs/referencia-android/res/strings.xml`; aquí viven en un catálogo de cadenas.

---

## Testing

Ninguna tarea se da por terminada sin su prueba en verde. **Prohibido** `.disabled`, comentar o
borrar una prueba para que pase la build.

| Tipo | Ubicación | Herramientas |
|---|---|---|
| Unitario | `BOCantabria-iosTests` | Swift Testing (`import Testing`, `#expect`) |
| Integración | `BOCantabria-iosTests` | Grafo real con dobles solo en la frontera externa |
| Interfaz | `BOCantabria-iosUITests` | XCUITest |

- Modelos de pantalla: se observa el `state` tras ejecutar el evento, con reloj y planificador
  inyectados.
- Todo bug corregido lleva una prueba de regresión que falla **antes** del arreglo.
- Pruebas deterministas: sin red real, sin reloj del sistema, sin depender del orden.
- Las muestras reales del servicio están en `BOCantabria-iosTests/Fixtures/`, tomadas del
  proyecto Android e incluyendo las anomalías que importan: el feed 4.3 con las categorías
  permutadas, el 8.1 vacío, el que trae `<!DOCTYPE`, el de la entidad externa y el de la fecha
  inválida. Si el servicio cambia de forma, se actualizan las muestras y las pruebas lo dicen.

**Reglas de arquitectura** (`BOCantabria-iosTests/Architecture/`): **nueve**, en una prueba propia
que recorre el árbol de fuentes. Localiza el árbol con `#filePath` —el proceso de pruebas del
simulador lee el sistema de ficheros del anfitrión— y por cada fichero saca su ruta, sus `import` y
los tipos que declara al nivel superior.

**En Swift las importaciones no bastan para la regla de capas, y esto es la trampa número uno del
port.** En Kotlin, cruzar de paquete exige un `import`, así que Konsist podía comprobarla mirando
la lista de importaciones. Dentro de un módulo Swift **no hace falta importar nada**: un fichero de
`Domain` puede nombrar un tipo de `Data` sin una sola línea de `import`. Traducir la regla tal cual
habría dado una regla que pasa siempre. Por eso hay dos comprobaciones: las importaciones cazan los
marcos y los SDK, y las **referencias por nombre** —buscadas como palabra completa sobre el código
con los comentarios y las cadenas retirados— cazan los cruces entre capas. Retirar los comentarios
no es un detalle: sin eso, un comentario que explica por qué `Domain` no debe conocer cierto tipo
dispararía la regla que ese comentario documenta.

**Es análisis de texto, no de AST** —Swift no tiene Konsist—, así que la lista se mantiene corta,
explícita y **con una prueba de la propia regla** (`SourceTreeTests`): una regla que no puede
fallar es una regla que no protege nada. Añadir una regla obliga a añadir su prueba.

Antes de dar por buena cualquier feature, provoca una violación a mano y comprueba que se pone en
rojo. Es el paso 2 de `quickstart.md` de la 001, y está verificado para la regla de capas, la del
color y la del fichero de prueba ausente.

**Trampas conocidas** — las marcadas «heredada» costaron tiempo en Android y el mecanismo sigue
siendo posible aquí; las demás son propias de esta plataforma.

- **`XMLDocument` no existe en iOS.** Solo `XMLParser`, que es SAX. El analizador se escribe
  con estado explícito, y eso es una diferencia real respecto al DOM de Android: el orden de
  llegada de los elementos importa.
- **Los ficheros añadidos en disco entran solos en el target.** El proyecto usa grupos
  sincronizados con el sistema de ficheros (`PBXFileSystemSynchronizedRootGroup`), así que
  crear un `.swift` dentro de `BOCantabria-ios/` basta: **no toques el `project.pbxproj`** para
  añadir fuentes. Sí hay que tocarlo para paquetes, configuraciones y fases de build.
- **Un `.xml` dentro de la carpeta de pruebas entra como recurso del bundle de pruebas.** Las
  muestras se leen con `Bundle(for:)` o `Bundle.module`, nunca por ruta absoluta.
- **`xcodebuild` sin `-quiet` esconde el error.** La salida útil son cuatro líneas dentro de
  decenas de miles; filtra por `error:`.
- **Con concurrencia estricta, un doble de prueba que no sea `Sendable` no compila** en cuanto
  cruza un `actor`. Los dobles se declaran `final class ... : @unchecked Sendable` con su
  estado protegido, o mejor, como `actor`.
- **`@Observable` no notifica lo que no se lee.** Una prueba que afirme sobre el estado debe
  leer la propiedad; observar el objeto entero no dispara nada.
- **Una prueba de interfaz corre en otro proceso y no puede sustituir nada por dentro.** En Android
  bastaba con cargar módulos de Koin desde el propio test; aquí el único mecanismo es pasar
  argumentos al lanzar la aplicación y que el composition root los lea (`LaunchConfiguration`). Es
  una costura en código de producción, así que se mantiene **acotada**: elige entre escenarios de
  un origen desechable, y se sustituye —no se amplía— cuando llegue el origen real.
- **Un contenedor de SwiftUI no se expone como `otherElements`.** Según lo que lleve dentro sale
  como un tipo u otro, o no sale. `app.otherElements["home_error"]` falló por esto y el mensaje
  hacía pensar que la pantalla estaba mal. Busca por identificador **sin fijar el tipo**:
  `app.descendants(matching: .any).matching(identifier: "…").firstMatch`.
- **Comprobar el estado de carga contra una latencia corta es una carrera contra el arranque.** El
  origen de ejemplo tarda 0,6 s y la aplicación tarda más en lanzarse, así que cuando la prueba
  mira ya hay contenido. Hay un escenario lento justo para eso; subir el tiempo de espera no
  arregla nada, porque el problema es el contrario.
- **`Regex` no es `Sendable`**, así que una constante estática de ese tipo no compila bajo
  concurrencia estricta. Se declara calculada: el coste de construirla es irrelevante al lado de lo
  que haya al otro extremo.
- **`${BUILD_DIR%/Build/*}` solo funciona dentro del script de una fase, no en sus ficheros de
  entrada.** La lista que documenta Firebase para subir los símbolos usa esa expansión; en el campo
  de entradas Xcode la evalúa a vacío y la build falla con «Unable to load contents of file list».
  La fase se declara siempre desactualizada y se queda sin lista. Comprobado que la subida corre en
  Release **sin** desactivar `ENABLE_USER_SCRIPT_SANDBOXING`, que la documentación de Firebase da
  por necesario.
- *(heredada)* **Con el reloj congelado, un filtro por fechas es inerte y no se comprueba
  nada.** Las pruebas de integración de los avisos almacenan y activan en el mismo instante:
  las que quieren ver actuar el filtro tienen que **avanzar el reloj** entre ciclos.
- *(heredada)* **Una animación infinita impide que la interfaz llegue a reposo.** El esqueleto
  de carga pulsa sin fin por diseño; una espera que exija reposo se cuelga en lugar de fallar.
- *(heredada)* **Toda cadena que aparezca en dos sitios de la misma pantalla necesita ancla.**
  La cabecera del panel y la barra superior dicen lo mismo, y «Boletín de hoy» está en la
  cabecera editorial **y** en el primer chip. La salida no es debilitar la aserción: es anclarla
  a un identificador de accesibilidad propio.
- *(heredada)* **El contenido de un panel lateral cerrado sigue en el árbol de accesibilidad.**
  No se ve, pero se encuentra.
- *(heredada)* **Una pestaña guardada se restaura por nombre, nunca por índice ni por
  `init(rawValue:)` sin comprobar.** «Preguntar» fue pestaña y hoy es pantalla; un valor
  guardado que ya no existe tumbaría el detalle al volver de la muerte del proceso, en el único
  camino que nadie recorre a mano.
- *(heredada)* **Una prueba que «funcionaba» porque la red era síncrona deja de funcionar al
  hacerla asíncrona.** Si una prueba de red lee el estado justo después de disparar la
  operación, sospecha: hay que **esperar** el estado, no asumirlo.
- *(heredada)* **`.first()` no puede ver que un flujo termina**: toma el primer valor y cancela.
  Las pruebas de la rama de recuperación tienen que contar suscripciones dentro del propio
  flujo.
- *(heredada)* **El repositorio de Material Symbols mezcla dos convenciones de lienzo**: la
  mayoría de los símbolos vienen con `viewBox="0 -960 960 960"` y coordenadas negativas, pero
  otros llegan en escala 24 y sin `viewBox`. Copiar la equivocada no falla: simplemente no
  dibuja nada, y en Android eso pasó desapercibido en los cuatro usos de un icono.
  `Tools/vector-drawable-to-svg.py` lee el lienzo declarado en cada fichero en vez de
  suponerlo, así que la trampa está cerrada en el origen; la nota queda por si algún día se
  añade un icono a mano.
- *(heredada)* **Una aserción sobre el prompt que dependa de dónde cae un salto de línea se
  rompe al reformatear, sin que nada esté mal.** Se comprueba sobre el mensaje con los espacios
  colapsados, no sobre fragmentos elegidos para caber en una línea.
- *(heredada)* **El servicio de IA se agota por tiempo con cierta frecuencia y el reintento
  salva la mayoría de las veces.** Tres intentos con espera creciente no son decoración. Y un
  429 se clasifica por **el retraso que pide**, no por el texto que trae: el texto cambia, está
  en inglés y la especificación prohíbe mostrarlo.
- *(heredada)* **Un arreglo que convierte un error en otro es peor que no arreglar nada.** El
  reintento automático de un resumen vacío chocaba con la cuota del mismo minuto y la persona
  acababa leyendo «se ha alcanzado el límite». Se consulta el margen antes de reintentar.

> **Lo que las pruebas de esta casa no pueden ver, y cómo se ve.** Los dos defectos que de
> verdad rompían el Resumen IA en un móvil Android —el modelo dejando el resumen vacío y el
> techo de salida cortando el JSON— **no los podía encontrar ninguna prueba automática**,
> porque todas usan dobles en la frontera con el servicio y el defecto estaba justo al otro
> lado. La conclusión no es escribir menos pruebas: es que **una frontera con un servicio ajeno
> hay que atravesarla de verdad al menos una vez**, y dejar registrado lo suficiente para saber
> qué pasó cuando falle.

**Cómo se mira cuando algo falla en un dispositivo.** La pantalla nunca dice códigos, a
propósito, así que el registro es el único sitio donde se distingue qué pasó. Se usa
`OSLog` con el subsistema del paquete y categorías por área (`sync`, `document`, `summary`,
`chat`, `alerts`, `reads`), y se leen con la app Consola o con:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.jrblanco.BOCantabria"'
```

Las líneas van en inglés y dicen la fase, el tamaño de lo enviado y el motivo exacto del fallo
—**nunca un título, una palabra clave, el nombre de una regla, el texto de una pregunta o
respuesta, ni la credencial**—. El ámbito declarado por una respuesta del chat **sí** se
registra, y a propósito: es lo único que permite saber sobre un dispositivo de verdad si la
defensa está actuando, y es un enumerado de tres valores que no puede filtrar nada.

---

## Git

- `main` es la rama estable. Cada feature vive en su rama `NNN-slug` creada por Spec Kit.
  **Nunca** implementes una feature directamente sobre `main`.
- Commits en español, imperativo, con prefijo Conventional Commits (`feat:`, `fix:`, `test:`,
  `refactor:`, `chore:`, `docs:`).
- Remoto: `https://github.com/jrcosio/BOCantabria_v2_iOS.git`.

Antes de dar una feature por terminada, en este orden:

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
xcodebuild ... -only-testing:BOCantabria-iosTests -quiet test
xcodebuild ... -only-testing:BOCantabria-iosUITests -quiet test
```

---

## Notas del proyecto

- **Versión mínima soportada**: iOS 18.0. El criterio es el mismo que llevó a `minSdk 28` en
  Android: la cobertura más amplia que no obliga a escribir caminos de compatibilidad.
- **Dispositivos y orientación**: solo iPhone y solo vertical, por decisión de producto, igual
  que en Android.
- **Identificador de paquete**: `com.jrblanco.BOCantabria`. Nótese que **no** lleva la doble
  «c» del package de Android (`com.jrblanco.boccantabria`): aquello era una errata que arrastró
  el registro en Firebase, y aquí se registró bien desde el principio. El
  `GoogleService-Info.plist` que hay que descargar apunta a este identificador exacto.
- **Nombre del target**: el target y las carpetas siguen llamándose `BOCantabria-ios`, de la
  plantilla. Lo que se ve en el dispositivo es `CFBundleDisplayName`, que vale **BOC
  Cantabria**. Renombrar el target tocaría el `project.pbxproj`, los esquemas y las rutas del
  host de pruebas, y no aporta nada.
- **Versión de la aplicación**: `MARKETING_VERSION = 1.0.0`. Es la primera versión de iOS,
  aunque el Android vaya por la 2.0.0. **Consecuencia que hay que resolver al implementar la
  portada**: el parámetro `min_supported_version_code` de Remote Config es un entero pensado
  para el `versionCode` de Android y hoy vale `0` («todo permitido»). Para iOS hace falta una
  condición por plataforma en la consola o un parámetro propio; decidirlo en el `plan.md` de la
  feature 002 y **no** reutilizar el de Android tal cual, o la primera versión publicada de
  iOS se forzaría a actualizar contra una cifra que habla de otra plataforma.
- **Dependencias**: GRDB 7.11.1 y Firebase 12.19.1, declaradas en el proyecto Xcode con
  `upToNextMajorVersion`. Los productos enlazados son `GRDB`, `FirebaseAnalytics`,
  `FirebaseCrashlytics` y `FirebaseRemoteConfig`.
- **Arranque medido**: **815 ms** de media en cinco tomas sobre el simulador de referencia
  (desviación relativa del 0,5 %), medido el 11 de septiembre de 2026 con
  `XCTApplicationLaunchMetric`. El objetivo de la feature 001 es menos de 2 s. La cifra se **mide**
  con esa métrica, no se estima; el Android equivalente daba 648 ms.
- **Documentación de diseño**: `docs/diseno/` contiene las especificaciones visuales y la
  imagen de referencia del arranque. Es la fuente de verdad de la interfaz; si cambias algo
  acordado, actualiza también el documento.
- **Fuentes del BOC**: `Datos_modelo/md/BOC_Cantabria_Consumo_Feeds_RSS.md` es la fuente de
  verdad del formato. `Datos_modelo/` contiene material de referencia y **no se versiona**.
- **Referencia de Android**: `docs/referencia-android/` guarda las quince features íntegras, la
  guía operativa, la constitución y el README del proyecto Kotlin. Es material de consulta:
  **no es norma aquí**.
