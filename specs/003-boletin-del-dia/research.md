# Investigación: boletín del día y pantalla de Inicio (iOS)

Esta feature es la primera que usa GRDB, la primera que usa URLSession y la primera que analiza XML.
La constitución dejó persistencia y red deliberadamente abiertas «hasta la primera feature que las
necesitara», y ésta lo es: aquí se deciden y se argumentan.

**El saldo del portado.** La feature de origen tomó diecisiete decisiones técnicas. Once se
reutilizan por su motivo —son de producto: la sección la manda la fuente, la cascada del
identificador, el tope de concurrencia, la huella del cuerpo, el orden estable, el mapeo de colores,
qué se compone y qué se prueba—. **Seis se descartan por ser mecanismo de plataforma**: Room y su
generador de código, OkHttp, el DOM de `javax.xml.parsers` —que allí se eligió para no depender de
un emulador, problema que aquí no existe—, el desazucarado de `java.time`, el inyector de
dependencias y el argumento de ruta con `SavedStateHandle`. De las seis, **cuatro no tienen
equivalente directo en iOS** y obligan a decidir de cero: el tipo de fecha, la observación reactiva,
el transporte de la selección y la forma del panel lateral.

**Dos decisiones las tomó el propietario** antes de planificar y aquí se recogen, no se reabren: el
panel se abre únicamente con el botón (D-319) y la base se abre y se migra dentro de la comprobación
previa de la portada (D-305).

**Lo que sigue está verificado, no recordado.** Las afirmaciones sobre GRDB se contrastaron contra
las fuentes de la versión 7.11.1 que hay en el checkout de paquetes; las de concurrencia, contra los
ajustes reales del proyecto; las del SDK, contra las cabeceras instaladas.

---

## D-300 · El aislamiento por defecto ya no salta al pool, y eso decide dónde corre el analizador

**Decisión**: cada trozo de trabajo intensivo —analizar el XML, calcular la huella, normalizar— entra
por una función marcada **`@concurrent`**. Todo lo demás sigue siendo síncrono y puro.

**El hecho que lo obliga**: el proyecto tiene `SWIFT_APPROACHABLE_CONCURRENCY = YES`, que entre otras
cosas activa `NonisolatedNonsendingByDefault`. Con esa opción, **una `nonisolated async func` deja de
saltar al pool cooperativo y hereda el ejecutor de quien la llama**. Una función «suelta» invocada
desde el actor principal analiza cinco megabytes de XML *en el actor principal*, y el compilador no
dice absolutamente nada.

**Por qué es la primera decisión del documento**: contamina a las de red, a las del analizador y a
las de normalización. Y es exactamente del género de trampas que este proyecto ya colecciona: no
rompe la build, no rompe ninguna prueba, solo hace que la lista dé tirones en un dispositivo real.

**Alternativas descartadas**:
- **Meter el trabajo dentro de un `actor`**. Sale del actor principal, sí, pero **serializa** el
  análisis de las diecinueve fuentes contra todo lo demás que haga ese actor, con lo que el tope de
  cuatro simultáneas deja de significar nada.
- **`Task.detached`**. Funciona y pierde prioridad, valores de tarea y cancelación estructurada. Es
  lo que se escribe cuando no se sabe que existe `@concurrent`, y por eso la regla 12 lo prohíbe
  (D-325).

**Qué lo demuestra**: una prueba `@MainActor` que llama al analizador y afirma, **dentro** de la
función analizadora vía un `@TaskLocal` de instrumentación, que no se está en el hilo principal. Se
pone roja si alguien quita el atributo. Sin esa prueba, `@concurrent` es una convención.

---

## D-301 · `DatabaseQueue` con WAL explícito, no `DatabasePool`

**Decisión**: una `DatabaseQueue` con `configuration.journalMode = .wal`.

**Motivo, y es de pruebas**: **`DatabasePool` no tiene inicializador en memoria.** Solo
`DatabaseQueue` abre `:memory:`. Con un pool en producción, la suite unitaria probaría un motor
distinto del que corre en el teléfono, o pagaría ficheros temporales y su limpieza en cada prueba.

**Por qué no se pierde nada**: lo que un pool compra es leer mientras se escribe, y **la escritura
larga no existe** porque D-308 escribe por fuente conforme termina: diecinueve transacciones cortas
en vez de una de mil novecientas filas. Las dos decisiones se sostienen la una a la otra, y por eso
se escriben juntas.

**Lo que hay que declarar en voz alta**: la prueba corre en `:memory:`, que **ignora el modo de
diario**. Es inocuo para los invariantes que se prueban —upsert, lista blanca de columnas, ausencia
de borrados— y **no** lo es para nada que dependa de durabilidad o de bloqueo. Se escribe para que
nadie deduzca una cobertura que no hay.

**Qué lo demuestra**: una prueba de integración que abre un fichero temporal real y afirma que
`PRAGMA journal_mode` devuelve `wal`; el resto de la suite, sobre base en memoria.

---

## D-302 · La observación cruza la frontera como `AsyncStream<AppResult<[Publication]>>`

**Decisión**: `PublicationRepository` devuelve `AsyncStream<AppResult<[Publication]>>`. El repositorio
construye el flujo bombeando `observation.values(in:)` a una continuación.

**Motivo**: `AsyncValueObservation` **ya es `AsyncSequence` y `Sendable`**, así que Combine no hace
falta para nada —lo cual es imprescindible, porque la constitución lo prohíbe en código nuevo—. Pero
es un tipo de GRDB, y no puede aparecer en la firma de un protocolo de `Domain` sin violar las reglas
1 y 2. El `AsyncStream` lo borra por completo, y el `AppResult` mantiene la convención de la casa:
los errores no salen de `Data`, viajan traducidos, y el `switch` de la pantalla queda exhaustivo.

**Alternativas descartadas**:
- **`any AsyncSequence<[Publication], any Error>`** como existencial en el protocolo. Compila en
  Swift 6, pero obliga a la pantalla a escribir `for try await` y a traducir errores ella misma, que
  es justo lo que la capa de datos existe para evitar.
- **`AsyncThrowingStream`**. Reintroduce `throws` exactamente donde la guía operativa dice que no lo
  quiere.

**La tarea que bombea tiene dueño, aunque no lo parezca**: se guarda en una variable local y se
cancela desde `continuation.onTermination`. Cuando la vista abandona su `.task`, el `for await` del
modelo de pantalla se cancela, el flujo termina, la tarea se cancela y la observación se desmonta en
su propio `deinit`. La cadena entera se deshace sola. Se documenta en el fichero porque **parece** una
`Task` sin dueño, que el proyecto prohíbe.

**Qué lo demuestra**: una prueba que arranca la observación en una tarea, la cancela, escribe en la
base y afirma que **no** llega otro valor. Y la trampa heredada: no se puede usar «el primer valor»
para comprobar que un flujo termina; hay que contar suscripciones dentro del propio flujo.

---

## D-303 · Planificador `.task`, nunca `.immediate`

**Decisión**: `observation.values(in: dbQueue, scheduling: .task)`.

**Motivo**: `.immediate` entrega el primer valor de forma **síncrona**, lo que exige arrancar desde el
hilo principal —tiene una precondición que lo comprueba— y hace **una lectura síncrona de SQLite en
el actor principal**. Es literalmente lo que la guía prohíbe: «nunca bloquees el actor principal con
E/S».

**Por qué se escribe, si es obvio**: porque no lo es cuando se ve el primer fotograma. `.immediate`
evita el parpadeo del estado vacío, y alguien lo propondrá por eso. El parpadeo se resuelve con el
estado de carga que la pantalla ya modela con esqueletos (FR-041).

**Qué lo demuestra**: no es demostrable con una aserción; lo protege la regla 10, que impide nombrar
tipos de GRDB fuera de `Data/Source/Local/`, y esta nota.

---

## D-304 · El mapeo registro→dominio va dentro del cierre de lectura

**Decisión**: la observación devuelve ya `[Publication]`; `PublicationRecord` nunca existe fuera del
fichero que lo declara.

**Motivo**: así la regla 3 —«`UI` no nombra ningún tipo de `Data`»— se cumple **por construcción** y
no por disciplina. Un registro que sale del cierre es un registro que alguien acabará pasando a una
vista «solo por esta vez».

**Detalle técnico**: `FetchableRecord` **no** exige `Sendable`, pero `AsyncValueObservation<Element>`
sí exige que su elemento lo sea. Un `struct` de valores lo es por inferencia, así que no hay que
anotar nada. El cierre corre en la cola de la base y tiene que quedarse puro.

**Qué lo demuestra**: la regla de arquitectura 3, que ya existe, en cuanto `PublicationRecord` sea un
tipo declarado en `Data`.

---

## D-305 · La base se abre y se migra dentro de la comprobación previa de la portada

**Decisión del propietario**: abrir el fichero y aplicar el migrador es un paso más de
`PrepareStartupUseCase`. Un fallo de migración es un desenlace de la portada, con su mensaje y su
reintento.

**Motivo**: el migrador lanza, y **hoy el único sitio de la aplicación con indicador de progreso,
límite de espera y estado de error con salida es la portada**. Si la base se abriera perezosamente,
ese fallo aparecería con Inicio ya pintado y habría que inventarle un sitio donde contarse.

**Consecuencia deliberada**: el arranque medido en 815 ms va a subir. Es el sitio correcto para que
se note —hay un indicador delante— y D-329 obliga a volver a medirlo.

**Política de recuperación, y su fecha de caducidad**: hoy la base es una caché de un feed público y
borrarla y recrearla no pierde nada de nadie. **Eso deja de ser cierto en la feature de Guardados y
en la de Avisos**, donde habrá datos de la persona. La decisión se toma ahora —recrear ante
corrupción irrecuperable— **y se anota que hay que revisarla entonces**, porque si no alguien
heredará «borrar y recrear» cuando ya haya algo que perder.

**Y una bandera que se queda como está**: `eraseDatabaseOnSchemaChange` vale `false` por defecto y
**tiene que seguir valiendo `false`**. Es la que uno enciende en desarrollo y se deja puesta. Merece
una aserción de una línea.

**Qué lo demuestra**: una prueba de migración que aplica la v1, inserta filas y, cuando llegue la v2,
afirma que siguen ahí —que es la trampa ya anotada de que una columna nueva deja sin rellenar las
filas anteriores—; y una prueba de arranque con una base corrupta sembrada que afirma el estado
terminal de la portada.

---

## D-306 · El fichero vive en Application Support, y con protección declarada

**Decisión**: `boc.db` en el directorio de soporte de la aplicación, incluido en la copia de
seguridad, con clase de protección `.completeUntilFirstUserAuthentication`.

**Motivo, en tres partes**. **No en cachés**, porque el sistema puede vaciar cachés bajo presión de
almacenamiento y esta base es la procedencia de lo que la pantalla muestra —el PDF sí irá a cachés,
y eso ya está escrito para la feature siguiente—. **En la copia de seguridad**, porque reinstalar sin
histórico es una de las consecuencias que la especificación acepta a conciencia, y no hay razón para
agravarla. **Y la clase de protección explícita** porque la protección por defecto puede impedir
escribir con el dispositivo bloqueado, y la feature de Avisos va a sincronizar en segundo plano.
Decidirlo aquí cuesta una línea; descubrirlo allí cuesta una sesión de depuración sobre un fallo que
solo ocurre con la pantalla apagada.

**Qué lo demuestra**: una prueba que lee los atributos del fichero creado y afirma la clase de
protección.

---

## D-307 · «Una sola sincronización a la vez» es una tarea guardada en un actor, y la segunda espera

**Decisión**: `actor FeedSyncCoordinator` con una `Task<SyncSummary, Never>?` guardada. Si hay una en
curso, la segunda llamada **devuelve `await running.value`**.

**Motivo**: FR-025 pide que no se dupliquen, y la alternativa —ignorar la segunda y volver enseguida—
haría que el indicador de refresco desapareciera **antes** que la sincronización. Es la forma más
barata de que alguien refresque tres veces seguidas.

**La sutileza que hay que escribir**: una `Task` creada dentro de un método de actor hereda la
prioridad del llamante pero **no su cancelación**. Eso es justo lo que se quiere —que una pantalla se
cierre no debe matar la sincronización que otra está esperando— y a la vez roza la prohibición de
«`Task` sin dueño». El dueño es el actor: se guarda, se limpia al terminar y se cancela desde un
`cancel()` explícito.

**Qué lo demuestra**: dos llamadas concurrentes con un descargador falso que cuenta invocaciones; se
afirma **diecinueve**, no treinta y ocho, y que las dos llamadas devuelven el mismo resumen.

---

## D-308 · Tope de cuatro con ventana explícita, y escribe el padre

**Decisión**: `withTaskGroup` cebado con cuatro tareas y una ventana —por cada resultado que llega, se
añade la siguiente fuente—. Los hijos descargan, analizan y normalizan; **el padre escribe**.

**Motivo del tope**: FR-005, que es cortesía con el servicio oficial. Diecinueve peticiones a la vez
a un servicio público desde cada teléfono no es aceptable.

**Motivo de que escriba el padre**: un solo escritor. Las diecinueve transacciones salen ordenadas, la
observación emite hasta diecinueve veces en lugar de solaparse, y el invariante de «nunca se borra»
tiene un único sitio donde comprobarse. De propina, la «línea base» que la feature de Avisos va a
necesitar —que se decide **una vez, antes** de lanzar los feeds— se apoya en que exista un punto
único de escritura.

**Alternativa descartada**: `httpMaximumConnectionsPerHost = 4`. Limita conexiones, no tareas; no
cubre ni el análisis ni la escritura; y **no es observable desde una prueba**, que para este proyecto
es descalificante.

**Qué lo demuestra**: un descargador falso que es un `actor`, cuenta cuántas hay en vuelo, guarda el
máximo observado y **se queda suspendido hasta que la prueba lo libera**. Aserción: el máximo es
cuatro con diecinueve fuentes. Sin el mecanismo de retención, la prueba mide la velocidad de la
máquina en vez del tope.

---

## D-309 · Cancelación: dónde no llega sola

**Decisión**: `try Task.checkCancellation()` al cerrar cada `<item>` en el analizador, y
`parser.abortParsing()` al detectarla.

**Motivo**: `URLSession` con `async/await` **sí cancela de verdad** —esa es la lección que a Android
le costó una feature entera, y aquí llega resuelta por construcción—. Pero **`XMLParser.parse()` es
síncrono y no comprueba cancelación**: un análisis de cinco megabytes corre hasta el final después de
que nadie lo esté esperando. Es el mismo defecto con otro disfraz: cambiar de hilo no hace cancelable
un trabajo bloqueante.

**Por qué en `didEndElement` y no más fino**: hay como mucho quinientos items por fuente, así que la
comprobación es barata y el grano es suficiente.

**Y la regla de la casa**: `CancellationError` **se repropaga siempre**, nunca se traduce a un error
de dominio. Una cancelación no es un fallo que contar a nadie.

**Qué lo demuestra**: una prueba que cancela a mitad de una muestra grande y afirma que el analizador
devolvió menos items de los que trae el fichero y que lo que salió fue una cancelación.

---

## D-310 · El jitter se inyecta como una fuente `Sendable`, no como un generador de números

**Decisión**: `protocol AppRandom: Sendable { func fraction() -> Double }` en `Core/Util`, con
`SystemRandom` en producción y `FixedRandom(0.5)` en pruebas.

**Motivo**: la constitución exige que la aleatoriedad se inyecte, y hoy no existe la costura. Pero
inyectar un `RandomNumberGenerator` no sirve: su `next()` es **`mutating`** y el protocolo **no es
`Sendable`**, así que compartir uno entre las tareas del grupo exigiría un actor o un cerrojo para
producir un número. Sería un cerrojo global en el camino caliente para decidir un retardo. Una
función sin estado es trivialmente `Sendable` y el doble de prueba es un `struct` de una línea.

**Qué lo demuestra**: con `FixedRandom` y `ManualClock`, se afirma la lista exacta de esperas
solicitadas para un factor conocido. `ManualClock` ya guarda **qué** se esperó, no solo cuánto: es
exactamente la aserción que hace falta y no hay que inventar nada.

---

## D-311 · Los números de la red que URLSession no sabe expresar

**Decisión**: `timeoutIntervalForRequest = 45`, `timeoutIntervalForResource = 60`,
`waitsForConnectivity = false`, `User-Agent` y `Accept` en `httpAdditionalHeaders`, descarga con
`URLSession.bytes(for:)` contando mientras llega, y validación del esquema y del host **sobre la URL
final**.

**Lo que aquí es distinto de Android, y hay que decirlo**:

- **No hay tiempo de conexión separado.** `timeoutIntervalForRequest` es inactividad, no conexión. Los
  diez segundos de conexión de la feature de origen **no se traducen**: se abandonan, porque
  implementarlos como una carrera contra el reloj añade una pieza para distinguir dos fallos que la
  pantalla trata igual.
- **`URLSession.data(for:)` bufea primero y pregunta después.** Con él, un cuerpo de quinientos
  megabytes ya está en memoria cuando se comprueba el tope. El tope de cinco megabytes se hace de
  verdad **contando bytes mientras llegan**, más un rechazo previo por la longitud declarada. Es la
  diferencia entre una defensa y un comentario.
- **`URLSession` sigue redirecciones sola.** Comprobar el esquema y el host de la URL *pedida* no dice
  nada sobre dónde acabó la petición. Se valida también la URL final, más el tipo de contenido. ATS
  ya bloquea el tráfico en claro por defecto, así que esto es cinturón sobre tirantes; un delegado
  por tarea para interceptar la redirección es más ceremonia bajo concurrencia estricta por muy poco
  más.
- **`waitsForConnectivity` se queda en `false`.** Con `true`, sin red la petición **espera** en vez de
  fallar, y el estado «sin conexión» que FR-027 y FR-043 exigen no llega nunca.

**Qué lo demuestra**: pruebas con un `URLProtocol` de prueba **declarado en el target de pruebas, no
en producción**, para el tope de tamaño, la redirección a otro host, el tipo de contenido incorrecto
y el cuerpo truncado.

---

## D-312 · El delegado del analizador se confina; no se declara `Sendable`

**Decisión**: el acumulador es una subclase de `NSObject` creada **dentro** de la función
`@concurrent` que analiza, sostenida en un `let` local, y lo que sale es un `struct` `Sendable`. No
se anota `@unchecked`.

**Motivo**: `XMLParserDelegate` exige `NSObjectProtocol` y el acumulador tiene estado mutable: no
puede ser `Sendable` honestamente. Declararlo `@unchecked` sería mentirle al compilador para no tener
que pensar. Si nada escapa del ámbito, el compilador no pide nada. **En Swift 6 el aislamiento barato
no es una anotación: es un ámbito.**

**Las tres trampas concretas, que van al `CLAUDE.md`**:

1. **`parser.delegate` es una referencia débil.** Asignar un acumulador recién creado lo libera en el
   acto, y el análisis no devuelve nada **sin error ninguno**. Hay que sostenerlo en un `let` durante
   todo el análisis.
2. **`foundCharacters` llega troceado.** Un título con tildes o con una entidad llega en varias
   llamadas. Hay que acumular en un búfer y confirmar solo al cerrar el elemento. Ésta es *la*
   diferencia con el DOM de Android: la guía ya avisa de que el orden importa, y falta decir que
   también importa la fragmentación.
3. **`parse()` devuelve un booleano** y el motivo está en el error del analizador. Ignorarlo convierte
   un XML roto en «cero anuncios», que es **indistinguible de un feed vacío legítimo** — y la muestra
   `feed_8_1_vacio.xml` existe precisamente porque un feed vacío **no es un error** (FR-009).

**Qué lo demuestra**: una prueba por trampa. La del delegado débil se pone roja si alguien
«simplifica» la asignación; la de la fragmentación necesita una muestra con un título largo con
entidades; la del booleano, un XML truncado.

---

## D-313 · El endurecimiento se hace sobre bytes, no sobre texto decodificado

**Decisión**: la guarda contra `<!DOCTYPE` y `<!ENTITY` busca las secuencias de bytes ASCII, en
mayúsculas y minúsculas, sobre el prefijo del cuerpo. Y el analizador se configura con
`shouldResolveExternalEntities = false` **y** `externalEntityResolvingPolicy = .never`.

**Motivo**: decodificar cinco megabytes para mirar los primeros doscientos bytes es un desperdicio, y
peor: **la codificación declarada puede no ser UTF-8**. Los fixtures lo son, pero el servicio no lo
promete, y una decodificación fallida convertiría la guarda en un pase libre. Sobre bytes es O(n) una
vez e independiente de la codificación para ASCII.

**Por qué dos capas y no una**: la primera es portátil y comprobable con una muestra; la segunda la
pone la plataforma. `shouldResolveExternalEntities` ya vale `false` por defecto y **se escribe
igual**: un valor por defecto no es una decisión hasta que está escrito.

**Qué lo demuestra**: `feed_con_doctype.xml` y `feed_con_entidad_externa.xml`, ya presentes. La
segunda necesita además una aserción de que **no se hizo ninguna petición de red** durante el
análisis, que es el fallo de verdad.

---

## D-314 · `BocDate`, porque Swift no tiene `LocalDate`

**Decisión**: `struct BocDate: Sendable, Hashable, Comparable, Codable` con año, mes y día, un
`init?(iso:)` estricto y una representación ISO.

**Descarta el mecanismo de Android**: allí bastó `java.time.LocalDate`. **Aquí no hay equivalente**, y
es una de las decisiones que no se heredan.

**Alternativas descartadas**:
- **`Date` con una zona fija.** `Date` es un instante: «2026-08-26» se convierte en un punto de la
  línea del tiempo, y formatearlo con otra zona muestra otro día. Es el error clásico del día de más
  o de menos, y llegaría hasta la cabecera editorial.
- **`DateComponents`.** No es `Comparable`, todos sus campos son opcionales y como valor almacenado es
  incómodo.

**La trampa que ya se pagó dos veces**: `Int("+1")` vale 1. Un `init?(iso:)` que trocee y convierta
con `Int(_:)` da por buenas `"+2026-08-26"` y `"2026-8-26"`. Se comprueba longitud y que todo sean
dígitos ASCII, exactamente como se hizo en `AppVersion`. Lo cazó una prueba, no una revisión.

**Qué lo demuestra**: `BocDateTests` con la tabla de entradas malas —signo, mes trece, treinta de
febrero, año de dos cifras, cadena vacía— y `feed_fecha_invalida.xml` para el camino de rechazo
individual que FR-010 exige.

---

## D-315 · En SQLite va como texto ISO, y la conversión vive en `Data`

**Decisión**: columna `TEXT NOT NULL` con la cadena ISO. El **registro** guarda un `String` y el mapeo
registro→dominio hace la conversión.

**Reutiliza el motivo de Android y sigue valiendo**: el orden lexicográfico coincide con el
cronológico, así que ordenar por fecha funciona sin conversión y la base es legible con cualquier
herramienta. Un entero de días desde una época sería más compacto y convertiría cualquier inspección
manual en aritmética.

**Lo que aquí es distinto**: `DatabaseValueConvertible` es un protocolo de GRDB y `BocDate` vive en
`Domain`, que no puede importarlo. Al ser un único módulo, una extensión en `Data/Source/Local/`
compilaría y no dispararía ninguna regla —pero dejaría a un tipo de dominio con una capacidad que
solo existe por la capa de datos—. Se elige la conversión en el mapeo, que es lo que la constitución
ya pide con «los registros no cruzan: se mapean». Si algún día las consultas se vuelven ilegibles por
esto, se declara como desviación y se cambia.

**El orden completo, que es contrato**: fecha descendente, después el identificador numérico del
enlace descendente, y por último la clave externa descendente. El tercer criterio es el desempate
determinista que FR-028 exige: sin él, dos ejecuciones pueden dar órdenes distintos porque las
fuentes responden en orden distinto. Que el servicio devuelva los items ordenados **no es contrato**.

**Qué lo demuestra**: una prueba que inserta fechas desordenadas y afirma el orden devuelto, y otra
con dos publicaciones de la misma fecha que afirma el desempate.

---

## D-316 · El formato largo español se compone a mano; nada de `Locale.current`

**Decisión**: una función pura sobre `BocDate`. Los doce nombres de mes y las dos plantillas de
rótulo viven en el catálogo de cadenas y se componen. Sin `Date`, sin `Calendar`, sin `TimeZone` y sin
`DateFormatter`.

**Alternativas descartadas**:
- **El formateo estándar con estilo largo.** Usa el idioma del dispositivo. En un simulador en inglés
  dice «August 26, 2026», y la prueba que afirma la cadena pasa o falla según la máquina. FR-087 lo
  prohíbe expresamente.
- **Fijar el idioma en el formateador.** Funciona, pero obliga a construir un instante desde un
  `BocDate` —es decir, a reintroducir la zona que D-314 acaba de quitar— y ata el texto a unos datos
  de internacionalización que cambian entre versiones del sistema.

**Dos detalles que no son detalles**: los rótulos son **dos** —«Edición del …» y «Última publicación:
…»— y sin fecha no se pinta ninguno (FR-033 a FR-035), así que la plantilla lleva marcador y **no se
concatena**. Y el recuento de anuncios estrena el primer plural del catálogo.

**Para las pruebas de interfaz**, que sí corren contra un simulador con idioma propio, se lanza la
aplicación fijando idioma y región por argumentos. El sistema de preferencias lee el dominio de
argumentos por su cuenta, así que **esto no toca ni una línea de producción**: no amplía la costura, y
conviene decirlo porque el proyecto tiene una promesa explícita al respecto.

**Riesgo aparte, decidido aquí**: «hoy» depende de una zona horaria. El BOC publica en España. Con la
zona del dispositivo, alguien de viaje vería otro «hoy». Se fija **`Europe/Madrid`**, en un solo
sitio.

**Qué lo demuestra**: `BocDateFormattingTests` sobre las doce fechas con la cadena exacta; y una
prueba que cambia la zona del entorno y afirma que la fecha del boletín no se mueve.

---

## D-317 · `AppClock` gana `now()`, y eso obliga a reescribir `ManualClock`

**Decisión**: `AppClock` añade `nonisolated func now() -> Date`. `ManualClock` deja de ser `actor` y
pasa a `final class … @unchecked Sendable` con un `Mutex` que guarda el tiempo virtual y las esperas
registradas.

**Motivo**: la caducidad de treinta minutos (FR-023) necesita un «ahora» inyectado, y tiene que ser
**síncrono**: comparar dos fechas no puede contagiar `await` a media aplicación. Un `actor` no puede
ofrecer un método síncrono que lea su estado.

**Alternativas descartadas**:
- **Partir el protocolo en dos.** Dos costuras que siempre se inyectan juntas y que nadie recordará
  mantener sincronizadas.
- **Dejar `now()` asíncrono.** Contagia `await` a cada comparación de fechas, incluida la del modelo
  de pantalla.

**Lo que tiene que sobrevivir a la reescritura**: `waitUntilSleeping(count:)`. La trampa ya anotada
—«adelantar el reloj antes de que la espera esté registrada hace que el adelanto se pierda y la
prueba se cuelgue en vez de fallar»— sigue viva palabra por palabra.

**Impacto en `ImmediateClock`**: hoy es un `struct` sin estado; con `now()` necesita una fecha, que
será un valor fijo del inicializador y **no** `Date()`, o vuelve a ser el reloj del sistema
disfrazado. Y se repite el aviso ya escrito: `ImmediateClock` gana toda carrera contra un límite de
espera, así que la prueba de la caducidad es de `ManualClock`.

**El caso raro, decidido**: `now()` es reloj de pared, y tiene que serlo porque la marca de la última
sincronización sobrevive a la muerte del proceso. Si alguien atrasa la hora del dispositivo, el
transcurrido sale negativo. **Un transcurrido negativo, o una marca en el futuro, se tratan como
caducado**, no como recién sincronizado. Si no, la caché se congela hasta que el reloj alcance ese
valor.

**Qué lo demuestra**: a los veintinueve minutos no sincroniza, a los treinta y uno sí, y con la marca
en el futuro sincroniza. Con `ManualClock`, las tres en microsegundos.

---

## D-318 · La selección vive en un almacén inyectado, y se restaura por nombre

**Decisión**: `protocol HomeSelectionStore` en `Domain`, implementado sobre las preferencias del
sistema en `Data`, inyectado por el contenedor en `MainViewModel`.

**Descarta el mecanismo de Android**: allí la selección viajaba como argumento de ruta y sobrevivía
gracias al estado guardado de la plataforma. **Ninguna de las dos cosas existe aquí.**

**Alternativas descartadas**:
- **Una ruta codificable en la pila de navegación.** La selección **no es una entrada de pila**: el
  panel la reemplaza, no apila. Y si apilara, pasear por el panel haría crecer la pila sin fin, que es
  justo lo que la feature de origen descartó por su cuenta.
- **`@SceneStorage`.** Semánticamente es lo correcto, pero solo se usa **desde una vista**, con lo que
  el estado se iría al árbol de vistas en vez de al modelo de pantalla, contra el principio III.
- **`@AppStorage`.** Mismo problema, y además sobrevive a un cierre explícito, que es más de lo que se
  quiere.

**La trampa documentada, aplicada**: se guarda **el código de la sección como cadena** y al restaurar
se **resuelve contra el catálogo**; si no casa, se cae a «Boletín de hoy» en silencio. Nunca un
índice, y nunca un `init(rawValue:)` sin su alternativa explícita detrás. Es literalmente el caso de
«Preguntar fue pestaña y hoy es pantalla»: las subsecciones del BOC pueden cambiar, y un código
guardado que ya no existe tumbaría Inicio en el único camino que nadie recorre a mano.

**Regalo colateral para las pruebas**: las preferencias leen el dominio de argumentos, así que una
prueba de interfaz puede sembrar la selección al lanzar **sin una línea de costura en producción**. Y
el mismo mecanismo resuelve el riesgo contrario: sin él, una prueba que elige una sección deja el
valor puesto y la siguiente arranca contaminada. Pasarlo siempre hace la suite independiente del
orden, que la constitución exige.

**Qué lo demuestra**: `UserDefaultsSelectionStoreTests` —guarda, lee, código desconocido, cadena
vacía— y una prueba de interfaz que lanza con un código inventado y afirma que la cabecera dice
«Boletín de hoy» en lugar de cerrarse.

---

## D-319 · El panel se abre solo con el botón; el deslizar es únicamente para cerrar

**Decisión del propietario**: no se construye gesto de apertura desde el borde. El panel se abre desde
el icono de menú de la barra superior, y se cierra deslizando, tocando fuera y con la flecha de su
cabecera.

**Motivo**: en iPhone el borde inicial ya está ocupado dos veces —por el gesto de retroceso
interactivo de la pila de navegación y por los gestos del sistema—. Una banda de arrastre ahí compite
con los dos y quién gana depende de milímetros. Es el riesgo más caro de esta pieza y se elimina no
construyéndolo.

**Por qué se escribe como decisión y no como omisión**: porque si no está escrito, alguien lo añadirá
«porque en Android estaba». El documento de diseño dice que el panel se abre desde el icono de menú;
los requisitos piden cierre por deslizar y **no** piden apertura por deslizar.

**Forma**: una pila en profundidad alineada al inicio con el contenido, el velo y el panel; el
abierto/cerrado es `@State` de la vista —es efímero y no sobrevive a nada, así que no es un modelo de
pantalla, y esto se escribe porque la regla 5 solo mira los tipos que se llaman así y alguien
propondrá lo contrario—; y el desplazamiento vivo del arrastre, un estado de gesto.

**Lo que falta en el tema**: **no hay token de velo**. La regla 7 impide construir un color fuera del
tema, así que el velo entra en `BocColors` junto con los cinco colores de sección. Es trabajo, no un
detalle.

**Qué lo demuestra**: una prueba de interfaz que abre con el botón, cierra tocando el velo por su
identificador y afirma que el panel desaparece; y otra que cierra arrastrando.

---

## D-320 · Un panel cerrado sigue en el árbol de accesibilidad

**Decisión**: el panel se mantiene montado, con `.accessibilityHidden(!isOpen)` **y**
`.allowsHitTesting(isOpen)`. La aserción de la prueba es sobre existencia, no sobre pulsabilidad.

**Motivo, y la distinción es la clave**: desmontarlo con una condición lo saca del árbol del todo,
pero pierde la animación de entrada y el arrastre. Y `allowsHitTesting(false)` a secas **solo mata la
pulsabilidad**: el elemento sigue existiendo, y buscar un texto del panel con el panel cerrado lo
encuentra. Es exactamente la trampa heredada que la guía ya anota, y la prueba que la vigila tiene
que afirmar que **no existe**, no que no es pulsable, o comprueba la mitad equivocada.

**Lo que se pierde por construirlo a mano, y hay que reponer**: una hoja modal nativa trae gratis el
comportamiento modal para el lector de pantalla y el gesto de escape. Un panel a mano no. Se añaden
el rasgo de accesibilidad modal mientras está abierto —para que el lector ignore lo de detrás— y la
acción de escape. Dos líneas que nadie echa de menos hasta que las echa de menos.

**Y el riesgo de las cadenas duplicadas, que aquí deja de ser un consejo**: la cabecera del panel dice
«BOC Cantabria» y la barra superior también; «Boletín de hoy» está en la cabecera editorial **y** en
el primer chip. Con el panel montado siempre, cada una de esas cadenas aparece dos veces **incluso con
el panel cerrado**. Toda aserción de interfaz sobre esos textos va anclada a un identificador propio.

**Qué lo demuestra**: una prueba que, **antes** de abrir nada, afirma que una etiqueta exclusiva del
panel no existe. Se pone roja si alguien sustituye una modificación por la otra.

---

## D-321 · Un `NavigationStack` por pestaña, y el panel envuelve al `TabView`

**Decisión**:

```text
RootView   → portada  ⟷  MainView            (conmutador, heredado de D-201)
MainView   → ZStack { TabView { … } ; velo ; panel }
cada Tab   → NavigationStack { … }
```

**Motivo**: un `NavigationStack` **envolviendo** al `TabView` es el error habitual: rompe la barra de
pestañas y deja una sola pila para tres destinos. El panel va **por encima** del `TabView` y no dentro
de la pestaña de Inicio, porque un panel que deja la barra de pestañas pulsable es un modal que no lo
es. Y como la portada es hermana de `MainView`, el panel no la alcanza, que es lo que FR-072 pide.

**Detalles con fecha**: con el objetivo en iOS 18 conviene la sintaxis de pestañas con valor y
selección, que es la no obsoleta. Para el fondo blanco con borde superior del apartado 10.1 del
documento de diseño hace falta declarar el fondo de la barra explícitamente, porque por defecto se
pinta un material translúcido. Y ocultar la barra de pestañas es lo que la feature del visor va a
necesitar: anotarlo ahora ahorra el descubrimiento.

**Cómo llega la selección a `HomeViewModel`**, que vive dentro de la pila de su pestaña: `MainView` la
posee y la pasa como `let`; `HomeView` la aplica con una tarea identificada por la selección, que
cancela la consulta anterior al cambiar. Es lo que se quiere y mantiene la regla de «ninguna `Task`
sin dueño». **Nada de `@Environment` para esto**: aunque la selección sea estado de interfaz y no una
dependencia, mezclar los dos mecanismos invita a que el siguiente en viajar así sea un caso de uso.

**La pestaña también se restaura por nombre**, con la misma cautela de D-318.

**Qué lo demuestra**: una prueba de interfaz que recorre los tres destinos y afirma el marcador en
dos; otra que abre el panel, elige una sección y afirma el título de la cabecera **por identificador**;
y una unitaria de `MainViewModel` con un valor guardado inválido.

---

## D-322 · La costura se sustituye, no se amplía: `-boc-data-scenario=`

**Decisión**: `-boc-content-scenario=` desaparece y en su lugar queda `-boc-data-scenario=`, que
**siembra la base** al arrancar con las muestras XML pasadas por el analizador real, sin sincronizar.
Escenarios: `today`, `empty`, `failing`, `offline`, `slow`. Con `-boc-startup-scenario=`, que se queda
como está, la costura sigue teniendo **dos** argumentos, los mismos que hoy.

**Motivo**: la cabecera de `LaunchConfiguration` promete que la costura «se sustituye, no se amplía,
cuando la feature del boletín traiga el origen real». Ésta es esa feature. Los escenarios se nombran
por **el desenlace que la pantalla tiene que pintar**, no por un detalle del transporte, que es lo que
los hace sustituibles cuando cambie el mecanismo.

**Alternativas descartadas**:
- **Un protocolo de URL de prueba registrado en el proceso de la aplicación.** Más fidelidad —ejercita
  descarga, análisis, normalización, escritura y observación— pero **mete la costura en producción** y
  hace las pruebas más lentas.
- **Un servidor local en el proceso de pruebas.** Necesita excepción de seguridad de transporte para
  localhost y trae intermitencia.

**La siembra sintetiza en código, y esto es una corrección del análisis previo.** La primera
redacción de esta decisión decía que la siembra pasaría las diez muestras XML por el analizador real.
**No es implementable**: las muestras de `BOCantabria-iosTests/Fixtures/` viajan solo en el bundle de
pruebas, y el sembrador es código de la aplicación, que corre en otro proceso y no las ve. Las dos
salidas eran embarcar muestras de prueba en el binario que se publica —que es exactamente lo que la
promesa de «costura acotada» quiere evitar— o **construir en código un conjunto determinista de
publicaciones**. Se elige lo segundo, y se acepta su consecuencia: **el analizador no queda ejercitado
desde la prueba de interfaz**, sino desde sus pruebas unitarias, que es donde tiene que estar. Lo que
la prueba de interfaz verifica es la pantalla, no el camino de datos.

**Dos condiciones que no son negociables**: la base sembrada es **en memoria o en un fichero
temporal**, jamás la de la persona; y el conjunto sintético es fijo, de modo que una prueba que
afirme un recuento no dependa de nada externo.

**Lo que se retira a la vez**: el escenario de contenido de `LaunchConfiguration`, el origen de
ejemplo, el origen local en memoria y la entrada correspondiente del contenedor. `HomeStatesUITests`
**se reescribe, no se borra**: sus métodos mapean uno a uno sobre los escenarios nuevos y la guía
prohíbe borrar una prueba para que pase la build.

**Qué lo demuestra**: las pruebas de interfaz existentes, con **los mismos identificadores**, que están
fijados como contrato. Y sigue haciendo falta el escenario lento: comprobar el estado de carga contra
una latencia corta es una carrera contra el arranque, y subir el tiempo de espera no arregla nada
porque el problema es el contrario.

---

## D-323 · El motor de reglas gana `rawCode`, porque una cadena SQL no se ve

**Decisión**: `SourceFile` añade `rawCode` —comentarios fuera, **cadenas dentro**— junto al `code`
actual. Cada regla elige cuál mira.

**El hecho que lo obliga**: el motor retira comentarios **y cadenas literales**, a propósito, para que
un comentario que explica por qué algo no debe pasar no dispare la regla que ese comentario documenta.
Pero **la sentencia SQL de una consulta es una cadena**, así que una regla que busque un borrado sobre
`code` **no ve absolutamente nada y pasa siempre**. Es exactamente el fallo que este proyecto ya
cometió al traducir la regla de capas de Konsist, y por el que añadió la comprobación por referencias.

**Lo que no cambia**: los comentarios se siguen retirando en las dos vistas. `rawCode` **se añade**, no
sustituye.

**Qué lo demuestra**: su caso propio en `SourceTreeTests`. La norma del proyecto es que añadir una
regla obliga a añadir su prueba, y aquí además se está tocando el lector, que tiene pruebas propias.

---

## D-324 · La garantía de «nunca se borra una publicación» es de ejecución, no de texto

**Decisión**: dos capas, y la buena es la segunda.

1. **Textual, barata, avisa pronto**: un fichero que nombre `publications` no contiene `DELETE` en su
   `rawCode`.
2. **De ejecución, la garantía**: una prueba de integración que configura la base para **recoger cada
   sentencia que se ejecuta**, corre una sincronización completa sobre base en memoria y afirma que
   ninguna borra de `publications`.

**El agujero que cierra la segunda**: GRDB borra con métodos de registro, sin que aparezca la palabra
en ninguna cadena del fuente. **Una regla de texto, por bien escrita que esté, no ve ese borrado.**

**Lo que la misma traza compra de propina**: el otro invariante de la casa —que la actualización de la
sincronización es una **lista blanca de columnas** y no menciona la marca de guardado ni la de primera
observación—. Es infraestructura que las features de Guardados y de Avisos van a necesitar tal cual;
montarla aquí es barato y montarla luego es retroajustar.

**Qué lo demuestra**: `NoDeleteRegressionTests`, y el hecho de que se pueda provocar a mano: si alguien
añade un borrado, la prueba se pone roja aunque el código compile.

---

## D-325 · Cinco cambios en la suite: la 6 se amplía y entran la 10, la 11, la 12 y la 13

**Decisión**: la regla 6 se amplía y entran cuatro nuevas, manteniendo la lista corta como el
proyecto exige. Las cinco se verificaron **provocando su violación a mano**, y una de ellas obligó a
corregir el razonamiento con el que se había propuesto.

- **Regla 6, ampliada**: «solo `Data` importa los módulos de Firebase **y GRDB**». Es una entrada en
  una lista que ya existe.
- **Regla 10, nueva**: nadie fuera de `Data/Source/Local/` **nombra** un tipo de GRDB. Lo que añade
  a la 6 es el **grano**: la 6 para en la capa y permite GRDB en cualquier punto de `Data`; ésta lo
  encierra en la carpeta donde vive la base, que es lo que impide que un repositorio o el coordinador
  de sincronización acaben hablando SQL.

  **Corrección de lo que se creyó al proponerla, comprobada provocando la violación.** Se argumentó
  que hacía falta porque «dentro de un módulo Swift, un `import` en un fichero hace nombrable el tipo
  en todos los demás». Eso es cierto para los tipos **declarados en el propio módulo** —que es
  exactamente lo que cazan las reglas 2 y 3, y la trampa número uno del port— y **falso para un
  módulo externo**: sin `import GRDB` en el fichero, `DatabaseQueue` ni siquiera compila. La regla
  sigue valiendo; el motivo era otro. Anotarlo importa porque el argumento equivocado habría viajado
  a la siguiente regla que alguien escribiera.
- **Regla 11, nueva**: nadie construye `Date()` ni usa el idioma, el calendario o la zona del
  dispositivo fuera de `Core/Util`. Es la de mayor valor por línea: la constitución exige pruebas «sin
  reloj del sistema» y **hoy no lo comprueba nada**. Tiene la misma forma que las reglas 7 y 8, que ya
  funcionan.
- **Regla 12, nueva**: `Task.detached` está prohibido. Un solo identificador. Es lo que se escribe
  cuando lo correcto es `@concurrent` (D-300).
- **Regla 13, nueva**: ninguna consulta declara un borrado sobre `publications`. Es la capa barata
  de D-324 y **la única que mira `rawCode`**. Se separa de las demás para que, al fallar, diga qué
  invariante se rompió; y se comprobó que muerde poniendo un `DELETE FROM publications` dentro de una
  cadena, que es donde una regla sobre `code` no habría visto nada.

**Alternativa descartada**: una sola regla que agrupe las tres nuevas. Al fallar no diría cuál de los
tres invariantes se rompió, que es la mitad del valor de una regla.

**Y la presión sobre la regla 9, resuelta aquí y en frío**: entran en la lista de exentos
`EditionType`, `IdSource`, `ParserWarning` y `SectionColorGroup`, cuatro enumerados sin comportamiento
cuya semántica se prueba donde vive. **No se eximen** `Publication`, `BocDate`, `BocSection`,
`HomeSelection` ni `SyncSummary`: los cinco tienen comportamiento de verdad —validación, catálogo,
relación padre-hija, grupo de color, derivadas—. Se decide ahora y no cuando la build esté roja y haya
prisa.

---

## D-326 · Los cinco colores de sección, y el reparto de nueve sobre cinco

**Decisión**: entran en `BocColors` los cinco tokens que el apartado 4.4 del documento de diseño
define, con este reparto:

| Grupo | Secciones |
|---|---|
| `sectionGeneral` | 1 Disposiciones Generales · 9 Elecciones |
| `sectionPersonnel` | 2 Autoridades y Personal |
| `sectionContracting` | 3 Contratación Administrativa |
| `sectionEconomy` | 4 Economía, Hacienda y Seguridad Social · 6 Subvenciones y Ayudas |
| `sectionAnnouncements` | 5 Expropiación Forzosa · 7 Otros Anuncios · 8 Procedimientos Judiciales |

**Por qué aquí**: la feature 001 los dejó fuera **a propósito y con comentario**, porque dependían de
una clasificación de dominio que no existía. Ésta la crea.

**Reutiliza el reparto de Android**, que es decisión de producto, y se vuelve a escribir el motivo
como manda el principio I: el documento define cinco grupos, no nueve. Añadir cuatro colores rompería
una paleta ya validada en contraste y convertiría el color en ruido. **No se pierde información**
porque FR-040 obliga a acompañar siempre de texto: el color agrupa, el texto identifica.

**Qué lo demuestra**: `BocThemeTests` con los cinco valores, y una prueba que afirma que las nueve
secciones mapean a uno de los cinco y que ninguna se queda sin color.

---

## D-327 · Qué se puede registrar de una sincronización, y qué no

**Decisión**: a analítica van `boc_sync` con recuentos —fuentes con éxito, fallidas, sin cambios,
insertadas, actualizadas, rechazadas— y `home_section_selected` con **el código de sección**. Al
registro `OSLog`, categoría `sync`, van fase, número de fuentes, bytes y motivo exacto del fallo.

**Por qué el código de sección sí**: es un enumerado de veintitrés valores de un catálogo público, no
un texto libre. La regla de la casa dice «solo recuentos y enumerados», y esto es un enumerado.

**Por qué se escribe ahora si aquí es fácil**: porque **en la feature de Avisos la misma pregunta llega
con palabras clave**, y entonces la respuesta es la contraria —las palabras, el nombre y el organismo
de una regla son intereses personales y no salen del dispositivo—. Dejar escrito dónde está la línea
evita que el precedente de hoy se invoque mañana para lo que no debe.

**Nunca, en ningún canal**: un título, un organismo, una consulta ni el cuerpo de una respuesta.

---

## D-328 · El esqueleto anima sin fin, así que las pruebas esperan existencia, no reposo

**Decisión**: toda espera de interfaz sobre el estado de carga usa espera por existencia. Nunca una
que exija que la interfaz llegue a reposo.

**Motivo**: es una trampa heredada que esta feature convierte de teórica en activa. El esqueleto pulsa
sin fin por diseño (FR-041), y una espera que exija reposo **se cuelga en lugar de fallar**, que es la
peor forma de fallar.

---

## D-329 · El arranque se vuelve a medir, no se estima

**Decisión**: se vuelve a tomar la cifra con la métrica de lanzamiento y se anota en `tasks.md` con su
número, como exige la constitución.

**Motivo**: los 815 ms actuales se midieron sin base de datos. Esta feature mete abrir un fichero,
migrarlo y arrancar una observación en ese camino (D-305). «Sigue bien» no es una cifra.

---

## D-330 · El archivo solo crece, y la decisión de no podarlo se escribe

**Decisión**: **no se poda nada**, y se escribe por qué.

**El razonamiento**: «nunca se borra una publicación» más «cada fuente publica sus últimos cien
anuncios» dan un archivo monótonamente creciente. Con diecinueve fuentes y sincronizaciones diarias
durante años, la tabla crece sin techo, y con ella la copia de seguridad de la persona. Un orden de
magnitud: unas mil novecientas filas de partida y del orden de unas pocas decenas de miles al año, con
títulos de hasta unos cientos de caracteres — megabytes, no gigabytes.

**Por qué la decisión correcta es no hacer nada**: el coste es despreciable frente al valor de que el
archivo no tenga agujeros, que es la razón por la que la regla de no borrar existe.

**Por qué se escribe igualmente**: porque una decisión de no hacer nada que no está escrita es
indistinguible de un descuido, y dentro de tres años sería un descubrimiento en vez de una decisión.

---

## D-331 · El modelo de error crece dos casos, y «sin conexión con contenido» no es uno de ellos

**Decisión**: `DomainError` pasa de dos casos a cuatro: se añaden **almacenamiento** —la migración o
la escritura fallaron, que es lo que D-305 necesita poder contar— y **cancelado**, para el camino que
FR-087 y D-309 exigen distinguir. La falta de conexión **con** contenido guardado **no** entra: es un
resultado correcto con una bandera en el estado de pantalla.

**Reutiliza el motivo de Android**: solo hay fallo cuando no hay nada que mostrar. Mezclar «si hay
contenido» con «si hay conexión» en un solo enumerado obliga a la pantalla a desenredarlos otra vez.

**Consecuencia inmediata y deliberada**: `DomainError` es un enumerado cerrado, así que **el compilador
va a señalar todos los `switch` existentes** —los de la portada y el de Inicio—. Eso es la
característica, no el coste: ningún camino de error se queda sin traducir por olvido.

---

## D-332 · La columna de texto normalizado se aplaza a la feature de Buscar

**Decisión**: el esquema v1 **no** lleva la columna de texto de búsqueda ni `Core/Util/SearchText`.

**Motivo**: la especificación no pide buscar, y una columna que nadie consulta es una columna que
nadie mantiene. Añadirla ahora obligaría además a decidir en frío qué significa normalizar, que es una
decisión que se toma mejor con la pantalla que la usa delante.

**Lo que hay que saber al retomarlo**, y por eso se anota: cuando llegue, será una **migración con
relleno por lotes**, y la trampa ya está documentada —una columna nueva deja sin rellenar las filas
anteriores, y eso **no se ve en una instalación limpia** porque una sincronización solo refresca los
últimos cien anuncios de cada fuente—. El relleno usará el valor vacío como marcador y el tamaño de
lote se inyectará. Que el esquema de la v1 esté versionado desde el primer día es precisamente lo que
permite escribir esa prueba de migración cuando toque.

---

## Lo que esta feature deja anotado para la siguiente

- **La política de recuperación ante corrupción hay que revisarla** cuando existan datos de la persona
  en la base: hoy recrear no pierde nada, con Guardados y con Avisos sí (D-305).
- **La traza de sentencias** montada para D-324 es la infraestructura con la que Guardados demostrará
  que desmarcar no borra, y Avisos que borrar una regla deja `publications` con las mismas filas.
- **La marca de guardado, la de primera observación y la de evaluación pendiente** no existen todavía,
  pero la actualización de la sincronización ya se escribe como **lista blanca de columnas** para que
  cuando existan no haga falta acordarse de protegerlas.
- **Ocultar la barra de pestañas** es lo que el visor del documento va a necesitar (D-321).
- **El enlace del documento se guarda y no se toca**: ni se descarga, ni se valida, ni se calcula su
  huella. Todo eso es la feature del detalle.
