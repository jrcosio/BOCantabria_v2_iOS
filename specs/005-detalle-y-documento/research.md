# Research: Del titular al documento oficial

**Feature**: `005-detalle-y-documento` | **Fase**: 0 | **Fecha**: 12 de septiembre de 2026

Veinticinco decisiones. La numeración sigue donde la dejó la 004: **D-5xx**.

**Método**: todo lo que aquí se afirma de una API está **comprobado contra el SDK instalado**
(`iPhoneSimulator26.5.sdk`, Xcode 26.6, Swift 6.3.3), con la ruta del fichero de interfaz o de la
cabecera donde se comprobó. Lo que no se pudo comprobar leyendo se dice que hay que medirlo, y dónde.

---

## 1 · La copia local

### D-501: La copia local del documento NO entra en la base de datos

**Decisión**: el documento vive en `<cachés>/documents/` y su estado se **deriva del sistema de
ficheros**. No hay tabla nueva, no hay migración y GRDB no se toca.

**Rationale**: es caché. El sistema puede vaciar ese directorio cuando quiera y sin avisar, así que
una fila que sobreviva al fichero es una mentira que luego hay que reconciliar —y reconciliarla es
código que solo existe para arreglar el problema que uno mismo se creó—. FR-030 dice que es caché;
esta decisión es lo que hace que lo sea de verdad.

Además hay una razón propia de esta plataforma que Android no tenía tan clara: el directorio de
cachés es exactamente el que el sistema puede vaciar bajo presión de almacenamiento **y el que no
entra en la copia de seguridad**. La base de datos, en cambio, vive en Application Support
(`BocDatabase.swift`, que ya lo dice en su cabecera: «El PDF sí irá a cachés, que es donde le toca»).

**Alternativas descartadas**:
- *Una tabla `documents` en GRDB*: obliga a mantener sincronizados base de datos y sistema de
  ficheros para un dato que **se deriva** del segundo. Y la regla 13 vigila que nadie borre de
  `publications`; una tabla de caché con borrados de verdad al lado invita a confundir las dos
  políticas.
- *Guardar en Documentos en vez de en cachés*: lo convertiría en biblioteca, entraría en la copia de
  seguridad de la persona y el sistema no podría liberarlo. Es la funcionalidad de Guardados, que es
  la 006, y adelantarla aquí sería decidir por esa feature.

### D-502: Se escribe a disco en streaming, con la huella calculada al vuelo

**Decisión**: `session.bytes(from:)`, un acumulador `[UInt8]` de 64 KiB, `FileHandle.write(contentsOf:)`
y `SHA256` **incremental**. Nunca hay más de 64 KiB del documento en memoria.

**Comprobado**: `URLSession.AsyncBytes.Element == UInt8` y es `Sendable`
(`Foundation.swiftinterface:18259-18263`); no existe API pública por trozos, así que la iteración es
byte a byte. `FileHandle.write(contentsOf:)` **lanza** (`Foundation.swiftinterface:417-419`).
`SHA256` expone `init()`, `update(bufferPointer:)`, `update(data:)` y `finalize()`
(`CryptoKit.swiftinterface:290-298, 411-425`).

**Rationale**: es la traducción literal de la lección que `HttpFeedDownloader` ya lleva escrita en su
cabecera —«`data(for:)` bufea primero y pregunta después»—, y aquí pesa veinte veces más: el tope del
feed son 5 MiB y el del documento 25 MB. `FileHandle` y no `OutputStream` porque **el error de
escritura tiene que llegar**: `OutputStream` devuelve `-1` y deja el motivo en una propiedad opcional
que hay que acordarse de consultar; con el disco lleno, el fallo se pierde en silencio. Eso es
exactamente STAB-002, que FR-029 prohíbe.

**Diferencia con el feed, y es deliberada**: `HttpFeedDownloader` acumula en un `Data` byte a byte.
Con 5 MiB de XML es aceptable; con 25 MB el reasignador de `Data` domina el perfil. Aquí el
acumulador es `[UInt8]` con `reserveCapacity` y se vacía con `removeAll(keepingCapacity: true)`.

**Lo que había que medir, y está medido.** La iteración byte a byte de `AsyncBytes` tiene un camino
rápido inlineado, pero sigue siendo una llamada asíncrona por byte, y la alternativa era
`session.download(from:delegate:)` (`Foundation.swiftinterface:18256-18258`), que transmite a disco
de forma nativa a cambio de perder el rechazo temprano por cabeceras y de obligar a releer el fichero
entero para la huella.

> **Resuelto el 13 de septiembre de 2026: 1,841 s para 25 MB**, con la huella y la escritura
> incluidas y sin red de por medio. El presupuesto de SC-003 son **diez segundos con la red**, así
> que aguanta con holgura y **la descarga nativa no hace falta**. La medición quedó como prueba
> —«un documento en el tope del tamaño se descarga dentro del presupuesto»—, para que avise si
> alguien toca el tamaño del trozo o la reserva del acumulador.

### D-503: El rechazo viaja como valor, y el orden de las comprobaciones es el requisito

**Decisión**: `DocumentDownloadResult` es `downloaded(byteCount:checksum:)` o `rejected(DocumentRejection)`.
El descargador **nunca lanza**. Las comprobaciones, en este orden:

1. **Antes de conectar**: esquema `https` y host del boletín. No se abre el enchufe.
2. **Con las cabeceras**: el destino **final** —tras las redirecciones que la sesión sigue sola— y el
   tipo declarado.
3. **Con los cinco primeros bytes del cuerpo**: la firma del documento portátil.
4. **Durante el cuerpo**: corte al superar el tope, contando mientras llega.
5. **Al terminar**: la huella.

**Rationale**: es el mismo patrón que `FeedFetchResult` de la 003, y por la misma razón: el motivo
tiene que llegar arriba para poder contarlo y registrarlo, y una excepción por cada forma de
desconfiar convertiría el repositorio en una escalera de capturas. El orden importa porque **se
rechaza en cuanto se sabe**: comprobar el host después de descargar cinco megas de una página de error
es haber pagado el precio para nada.

**Lo que aquí llega gratis y en Android no**: la guarda del host se hace sobre `URL.host()`, no
recortando cadenas, y se **repite sobre el destino final**. La auditoría de origen encontró que
`https://boc.cantabria.es:443@otro.invalid/x.pdf` pasaba su comprobación textual, porque lo anterior
a la arroba es información de usuario y el host real era el otro. `HttpFeedDownloader` ya lo hace
bien; el del documento lo copia.

**El host NO es el mismo que el del feed.** `HttpFeedDownloader.trustedHost` vale `www.cantabria.es`;
`documentUrl` apunta a `boc.cantabria.es`. Son dos constantes distintas y confundirlas rechazaría
todos los documentos —o, peor, aceptaría cualquiera de los dos en los dos sitios—.

### D-504: El documento NO se reintenta solo; el feed sí

**Decisión**: `HttpDocumentDownloader` hace **un** intento. El reintento lo pide la persona con el
botón que FR-025 y el componente de error ya exigen.

**Rationale**: el feed reintenta tres veces con espera creciente porque son diecinueve peticiones
pequeñas y automáticas que nadie está mirando. Un documento son hasta 25 MB **pedidos a propósito**:
reintentar tres veces sin preguntar son 75 MB de los datos de la persona, gastados mientras mira una
pantalla que no dice por qué tarda. Y el estado de error con reintento ya existe, así que la
alternativa no es «no hay reintento»: es «el reintento lo decide quien paga los datos».

### D-505: El nombre del fichero se deriva de una huella de la clave, no de la clave

**Decisión**: `<cachés>/documents/<huella-de-la-clave>.pdf`, donde la huella es el SHA-256 de
`externalKey` en hexadecimal.

**Rationale**: `externalKey` vale `boc:439765` cuando el enlace trae identificador, y **una URL
entera** cuando no lo trae (`IdSource.canonicalUrl`). Los dos puntos y las barras dentro de un nombre
de fichero son, en el mejor caso, un fichero que no se puede abrir y, en el peor, una escritura fuera
del directorio previsto. Una clave que se cuela en una ruta es una forma conocida de escribir donde no
se debe, y aquí la clave viene **de la red**.

### D-506: El lateral con la huella se escribe ANTES que el documento, y se valida al leer

**Decisión**: el directorio contiene cuatro formas de fichero:

```text
<huella>.pdf            visible solo si está completo
<huella>.pdf.part       descarga en curso
<huella>.sha256         la huella, 64 hexadecimales en minúscula
<huella>.sha256.part    escritura en curso
```

Y el orden de `commit` es: escribir `.sha256.part` → renombrarlo a `.sha256` → renombrar `.pdf.part` a
`.pdf`. Si el último renombrado falla, se borra el lateral. **Invariante: documento visible ⇒ lateral
válido.** Al leer, un lateral que no sea exactamente 64 hexadecimales —vacío, truncado, con espacios,
en mayúsculas— se trata como **ausente**, y el documento se sirve igual con «huella desconocida».

**Rationale**: es FR-023 y FR-024, y es el hallazgo de severidad alta de la auditoría de origen. Allí
el lateral se leía con «lo que haya, y si no hay nada, el valor vacío»; un lateral **presente pero
vacío** devuelve la cadena vacía, que no es «nada», así que el respaldo no se aplicaba nunca al caso
que importaba, el modelo exigía 64 caracteres y **la aplicación se cerraba al abrir esa publicación**,
y otra vez en cada reintento.

Servir el documento sin huella es correcto y no es una concesión: **sus bytes ya se verificaron al
descargarlos**, y solo se hizo visible cuando estaban completos. La huella no valida el fichero; la
huella dice **si lo que hay corresponde a lo que se resumió**, y por eso importa el orden: es la
columna que decide si un resumen guardado está obsoleto, y regenerarlo cuesta cuota. Con el orden
contrario existe una ventana —documento visible, lateral aún sin escribir— en la que un resumen bueno
se declara obsoleto.

El renombrado dentro del mismo volumen es atómico, así que **nunca existe un fichero a medias con el
nombre bueno** (FR-021).

---

## 2 · La coalescencia y el estado

### D-507: La tarea en vuelo se tipa `Task<AppResult<OfficialDocument>, Never>`, y eso ELIMINA la clase de bug de STAB-002

**Decisión**: el trabajo en vuelo se guarda como `Task<AppResult<OfficialDocument>, Never>` y quien
espera hace `await task.value`.

**Comprobado**, y es la decisión con más consecuencias del documento
(`_Concurrency.swiftinterface:2556-2571`):

```swift
extension Task {                                  // el genérico
  public var value: Success { get async throws }
}
extension Task where Failure == Swift.Never {     // el nuestro
  public var value: Success { get async }         // ← NO lanza
}
```

**Rationale**: en la aplicación de origen, quien esperaba una descarga que otro había iniciado
heredaba la cancelación del dueño, porque el `await` de aquella primitiva propaga la excepción de
cancelación. La consecuencia medida allí: los dos botones de reintento —que cancelan y relanzan—
dejaban la pantalla cargando **sin botón de reintento**, atascada hasta salir. El arreglo fueron seis
líneas que distinguían «me han cancelado a mí» de «han cancelado al que yo esperaba».

Aquí **no hace falta ninguna de esas seis líneas**, y no por listeza: porque con `Failure == Never` no
existe el canal por el que heredar nada. El compilador no deja siquiera escribir el `try`. FR-028 sale
del sistema de tipos.

**La trampa, y por eso esto es una decisión y no una observación**: si alguien tipa la tarea como
`Task<OfficialDocument, Error>` —que es lo que sale natural cuando se escribe `try await` dentro—,
**vuelve el bug entero**. La forma del tipo *es* el requisito. Va anotada en el fichero y tiene prueba
propia (D-510).

### D-508: Un recuento de espectadores decide cuándo se cancela la descarga

**Decisión**: cada trabajo en vuelo lleva un contador. Quien pide el documento lo incrementa; quien
abandona la pantalla lo decrementa. **Se cancela cuando llega a cero.**

**Rationale**: FR-027 dice que abandonar cancela y FR-028 dice que si otro sigue esperando, lo recibe.
Las dos a la vez solo se cumplen si «abandonar» significa «dejar de ser espectador», no «cancelar».
Sustituye al traspaso de propiedad que la aplicación de origen necesitó, y es más simple: no hay
dueño, hay público.

`Task { … }` **no hereda la cancelación** del contexto que lo crea —hereda prioridad, valores de tarea
y aislamiento—, así que la descarga pertenece al almacén y no a la pantalla que la pidió primero. Y
**no es `Task.detached`**, que la regla 12 prohíbe y que además perdería la prioridad y los valores.

### D-509: `settle()` no necesita envoltorio de no-cancelable, y hay que escribir por qué

**Decisión**: la limpieza —borrar el temporal, retirar la entrada en vuelo y publicar el estado
final— vive en un método **síncrono y aislado al actor**, sin un solo `await` dentro.

**Rationale**: en la aplicación de origen esta limpieza necesitaba un envoltorio explícito de
no-cancelable, porque su primitiva de concurrencia comprueba la cancelación al suspender. En Swift la
cancelación es cooperativa y **un salto a un actor no es un punto de cancelación**: llamar a un método
de actor desde una tarea ya cancelada lo ejecuta entero. `FileManager` es síncrono y no consulta
`Task.isCancelled`. Por tanto el método es no-cancelable **por construcción**.

**La regla que eso impone, y que hay que dejar escrita en el fichero**: dentro de `settle` no puede
aparecer ni un `Task.sleep`, ni un `Task.checkCancellation()`, ni ninguna API sensible a la
cancelación. El día que haga falta trabajo asíncrono ahí, el equivalente es un `Task { }` poseído por
el actor, nunca un `await` en línea.

Y cierra de paso un cuelgue latente que la auditoría de origen describe: allí la limpieza del camino
de cancelación corría dentro de una corrutina ya cancelada, y un cerrojo que tuviera que suspender
justo ahí dejaba colgados **para el resto del proceso** a todos los que esperasen esa clave.

### D-510: El estado se difunde con un diccionario de continuaciones, y se REPRODUCE al suscribirse

**Decisión**: el almacén guarda, por clave, el estado vigente y un diccionario de continuaciones. Al
suscribirse, lo primero que recibe el nuevo observador es **el estado que hay ahora**.

**Comprobado**: `AsyncStream.makeStream(of:bufferingPolicy:)` existe
(`_Concurrency.swiftinterface:855`), y `Continuation.onTermination` es
`(@Sendable (Termination) -> Void)?` — **síncrono**, no asíncrono
(`_Concurrency.swiftinterface:820`).

**Rationale**: un `AsyncStream` tiene **una** continuación. Tres pantallas observan el mismo documento
—detalle, visor y compartir—, así que la difusión se hace a mano en el actor.

**La reproducción no es una comodidad: es la feature.** El visor se abre cuando el documento ya está
disponible; la publicación de ese estado ocurrió **antes** de que el visor se suscribiera, así que sin
reproducir, el visor no recibe nada y **se queda cargando para siempre**. Es un cuelgue silencioso,
sin excepción y sin nada en el registro, y es indistinguible a simple vista del defecto que FR-029
viene a evitar. Tiene prueba propia: «un observador que llega tarde ve el estado disponible de
inmediato».

`onTermination` es síncrono, así que retirar la continuación del actor obliga a saltar con un `Task`
desde dentro. Sin eso no compila; con un `nonisolated(unsafe)` compilaría y sería una carrera.

### D-511: La política de almacenamiento del flujo es «el más nuevo, uno»

**Decisión**: `bufferingPolicy: .bufferingNewest(1)`.

**Rationale**: el progreso de una descarga son cientos de valores de los que solo interesa el último.
Con la política por defecto —sin límite— un consumidor lento acumula la historia entera y pinta el
progreso con retraso creciente. «El más nuevo, uno» descarta los intermedios **y conserva el terminal**,
que es el único que no se puede perder.

### D-512: El detalle observa la fila, y por eso el repositorio gana `observePublication`

**Decisión**: `PublicationRepository` se amplía con
`observePublication(externalKey:) -> AsyncStream<AppResult<Publication?>>`, y la consulta entra en
`PublicationQueries`.

**Rationale**: FR-002, FR-003 y FR-004 son la misma decisión vista tres veces. Si la publicación
viajara como objeto por la ruta, el detalle mostraría una foto del momento en que se tocó la tarjeta:
una sincronización que corrigiera el título no se vería (FR-003), y «ya no está guardada» habría que
inventárselo (FR-004). Observando la fila, las tres salen gratis y **ninguna necesita código propio**.

El `nil` dentro del `success` es información, no un fallo: es exactamente lo que FR-004 necesita
distinguir de un error de lectura.

---

## 3 · El visor

### D-513: PDFKit vive tras una vista envoltorio, y de `UI/PDF/` no sale un solo tipo suyo

**Decisión**: una única vista `UIViewRepresentable` sobre `PDFView` en `UI/PDF/`. Fuera de esa carpeta
solo circulan `URL`, `Int`, tipos propios y vistas de SwiftUI.

**Comprobado**: `PDFView` tiene `displayMode`, `displayDirection`, `autoScales`, `pageShadowsEnabled`,
`backgroundColor`, `minScaleFactor`, `scaleFactorForSizeToFit`, `interpolationQuality`,
`goToPage(_:)`, `currentPage` y la notificación de cambio de página
(`PDFView.h:53,107,130,134,157,160,163,190,194,199,204`).

**Y lo que decide el diseño**: `PDFDocument` y `PDFPage` son `NSObject` pelados, **sin anotación de
concurrencia** (`PDFDocument.h:130`, `PDFPage.h:50`): no son `Sendable` ni están aislados al actor
principal. Guardar uno en un `UiState` **no compila**, y está bien que no compile. Por eso el estado
del visor lleva una `URL` y un entero, no un documento.

**El detalle no embebe una imagen: embebe una vista de `UI/PDF/`.** Es lo que hace que la regla 14
(D-521) se cumpla sola en vez de a base de disciplina.

**Alternativa descartada**: dibujar el documento a mano sobre Core Graphics. Reescribiría el zoom, el
reciclado de páginas y la gestión de memoria —peor— justo en la parte para la que existe la
aplicación.

### D-514: «Ilegible», «protegido» y «cifrado pero legible» son tres cosas distintas

**Decisión**:

| Lo que se observa | Qué significa | Qué se hace |
|---|---|---|
| El documento no se puede construir | ilegible o truncado | error con salida |
| Se construye y está **bloqueado** | protegido con contraseña de usuario | error con salida, con su propio texto |
| Se construye, está **cifrado** pero no bloqueado | restricciones de impresión o copia | **se abre con normalidad** |
| Se construye y no tiene páginas | ilegible | error con salida |

**Comprobado**: `isEncrypted` y `isLocked` son propiedades distintas, y la cabecera lo explica —«con la
contraseña, un PDF puede desbloquearse; aun así sigue indicando que está cifrado»—
(`PDFDocument.h:158-164`). Hay PDF que se desbloquean solos con la contraseña vacía.

**Rationale**: FR-036. Rechazar por «cifrado» sería un falso negativo **sobre documentos oficiales
legítimos**: un boletín publicado con restricción de copia se lee perfectamente. Lo que cierra la
puerta es «bloqueado», no «cifrado». Confundirlos es la forma de escribir esta comprobación que
parece más segura y es simplemente incorrecta.

### D-515: La página visible se guarda en el almacenamiento de escena, no en el estado de la vista

**Decisión**: la página visible vive en `@SceneStorage`, como la pestaña del armazón ya hace con
`main_tab`.

**Rationale**: FR-034 habla de segundo plano y muerte del proceso, **no de rotación**: la aplicación
es solo vertical, así que el caso que en Android era «cambio de configuración» aquí no existe. Lo que
sí existe es que el sistema mate el proceso con la aplicación en segundo plano, y eso es exactamente
lo que `@SceneStorage` sobrevive y `@State` no.

**La trampa de la configuración inicial**: `minScaleFactor` se fija **después** de asignar el
documento. Antes vale cero, y con cero el pellizco deja reducir el documento a nada sin forma de
recuperarlo. Se ve mirando la pantalla, no leyendo el código — igual que el botón invisible sobre azul
de la 002.

### D-516: La previsualización va marcada `@concurrent`, y tiene una prueba que lo demuestra

**Decisión**: la función que dibuja la primera página se marca `@concurrent`, recibe la escala de
pantalla **por parámetro** y devuelve una imagen.

**Comprobado**: `UIImage` es `NS_SWIFT_SENDABLE` (`UIImage.h:76`), así que cruza a la vista sin
envoltorio ni `@unchecked`. `PDFPage` ofrece `thumbnail(of:for:)` (`PDFPage.h:129`).

**Rationale**: es la trampa que `CLAUDE.md` ya tiene anotada y que aquí vuelve a morder.
`SWIFT_APPROACHABLE_CONCURRENCY = YES` activa que una `nonisolated async func` **herede el ejecutor de
quien la llama**; sin el atributo, rasterizar una página desde la vista la rasteriza **en el actor
principal**, y el compilador no dice nada. El síntoma no es un error: es que la pestaña se congela
medio segundo al abrirse y se diagnostica como «el visor es lento».

Por eso lleva la misma costura que el analizador de RSS de la 003: un cierre opcional que la prueba usa
para afirmar, **desde el actor principal**, que el dibujado no ocurre en él. Sin esa prueba, el
atributo es una convención.

**La escala por parámetro** tiene dos motivos: el tamaño de la miniatura se interpreta en puntos, así
que sin multiplicar por la escala la previsualización sale borrosa en cualquier iPhone; y tomarla del
entorno en vez de de la pantalla hace la función comprobable sin simulador.

**El tope de píxeles no es una optimización**: hay anuncios con planos urbanísticos en tamaño A0. A
escala 3 son decenas de megapíxeles en una sola imagen.

---

## 4 · Compartir

### D-517: Compartir usa un tipo transferible propio con cierre ASÍNCRONO, no un controlador de UIKit

**Decisión**: un tipo propio que declara cómo se exporta, con el cierre de exportación **asíncrono**, y
el nombre de fichero sugerido.

**Comprobado** (`CoreTransferable.swiftinterface:204, 213, 223, 164-167`):

```swift
FileRepresentation(exportedContentType:shouldAllowToOpenInPlace:exporting:)
//                 exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile
SentTransferredFile(_ file: URL, allowAccessingOriginalFile: Bool = false)
func suggestedFileName(_ fileName: @escaping @Sendable (Item) -> String?)
```

**Rationale**: tres problemas y una sola respuesta.

1. **El nombre.** El fichero en disco se llama `<huella>.pdf` (D-505). Compartirlo así manda a la otra
   persona un fichero con sesenta y cuatro caracteres hexadecimales por nombre. El nombre sugerido lo
   arregla, y es FR-042.
2. **El «preparando».** La hoja de compartir necesita el elemento de antemano, y cuando el documento no
   está descargado no lo hay. Pero **el cierre de exportación es asíncrono**: la hoja se abre al
   instante y, cuando la persona elige destino, el sistema espera a que el proveedor resuelva
   enseñando **su propio** indicador. Un solo toque, sin controlador a mano. Eso es FR-039.
3. **La constitución.** Un `UIActivityViewController` envuelto es, literalmente, **una pantalla escrita
   en UIKit**, y la única excepción que la constitución concede es el visor de documentos. Usarlo
   exigiría una enmienda; el tipo transferible la evita.

**`allowAccessingOriginalFile` se deja en falso a propósito, y se escribe por qué**: el fichero vive en
el directorio de cachés, que **el sistema puede vaciar mientras la hoja está abierta**. Dejando que el
receptor acceda al original, se encontraría una ruta vacía y guardaría un fichero de cero bytes, sin
error visible. Con la copia, el sistema se lleva los bytes antes.

### D-518: El caso degradado se decide ANTES de dibujar, y la tarjeta lo recibe por parámetro

**Decisión**: el destino de compartir —documento o enlace, con su motivo— se calcula en un único caso
de uso y llega a la vista como un valor. `PublicationCard` gana un parámetro y **sigue sin estado**.

**Rationale**: FR-040 y FR-041. Dentro del cierre asíncrono no se puede ofrecer el enlace: si lanza, la
persona ve un error del sistema, no nuestra explicación. Así que la decisión se toma antes: si está en
caché, documento; si hay conexión, documento —con la descarga perezosa dentro del cierre—; si no hay
ninguna de las dos, enlace **con su motivo al lado del botón**.

**La consecuencia que hay que aceptar y escribir**: la tarjeta vive en `Core/UI/Component`, es sin
estado y la usan tres listados. No puede preguntar por el estado de caché de cada documento, así que
deriva su destino de la bandera de conexión que el estado de Inicio **ya tiene**. Sin conexión pero con
el documento en caché, la tarjeta ofrecería el enlace pudiendo ofrecer el documento. Es un caso de
borde barato; consultar el sistema de ficheros diez veces para pintar una lista, no. El detalle y el
visor, que sí conocen el estado del documento, no tienen esa limitación.

**Un fallo que no sea la falta de conexión NO se disfraza de enlace** (FR-040). Es la lección de la
002 dicha en otro sitio: un arreglo que convierte un error en otro es peor que no arreglar nada.

---

## 5 · La composición

### D-519: La tarjeta se hace pulsable con forma de contacto y gesto, NO con un enlace de navegación

**Decisión**: `contentShape` + gesto de toque + rasgo y acción de accesibilidad sobre la tarjeta. La
navegación la hace el armazón con una ruta explícita.

**Rationale**: es el punto de mayor riesgo de la feature, y la razón es el árbol de accesibilidad.
`PublicationCard` se declara elemento combinado y lleva dentro dos controles. `CLAUDE.md` documenta
**tres caras** de la misma trampa de contenedores anidados, y la tercera es justo ésta: «no se anidan
dos contenedores declarados, porque entonces el de dentro desaparece». Un enlace de navegación
envolviendo la tarjeta crea ese segundo contenedor.

**Ocho aserciones penden de ese árbol**, y dos de ellas —en `AccessibilityUITests`— miden **el alto de
la tarjeta a dos tamaños de letra** y **el marco de su acción de compartir**. Son exactamente las dos
cosas que un envoltorio altera. Con el gesto, el árbol queda **idéntico**: mismo elemento combinado,
misma etiqueta, mismos dos controles como elementos propios.

Los dos controles siguen funcionando sin nada especial, porque consumen el toque antes de que llegue al
gesto del contenedor; y el gesto no compite con el desplazamiento, porque el arrastre lo cancela.

**Lo que se pierde, dicho en voz alta**: el resalte nativo al pulsar. Si el propietario lo echa en
falta, se recupera con un gesto de pulsación larga de duración cero escribiendo un estado de presión,
sin volver a un botón. **No se hace por adelantado.**

**Alternativas descartadas**:
- *Enlace de navegación envolviendo la tarjeta*: el riesgo de arriba, y además obliga a cambiar el
  estilo de los dos controles internos para que reciban su propio toque.
- *Enlace para la tarjeta y los controles superpuestos aparte*: limpio en accesibilidad, pero rompe el
  reflujo de la fila de fecha y acciones que la 004 resolvió con `ViewThatFits`, y tira una prueba que
  costó descubrir.

### D-520: La cabecera se va con un encabezado fijado, NO midiendo el desplazamiento

**Decisión**: `LazyVStack(pinnedViews: [.sectionHeaders])` con la cabecera **fuera** de la sección y
las pestañas como encabezado de la sección.

**Comprobado**: `LazyVStack(alignment:spacing:pinnedViews:content:)`
(`SwiftUICore.swiftinterface:3406`).

**Rationale**: FR-011 pide que la cabecera se vaya y las pestañas se queden, que es **lo contrario** de
lo que la 004 hizo en Inicio. Allí la cabecera **se queda y encoge**, y por eso hubo que medir el
desplazamiento y devolver al contenido lo que la cabecera liberaba. Aquí la cabecera simplemente sale
de la pantalla, que es lo que un encabezado fijado hace **solo**.

**Y esto es la trampa número uno del port, dicha de nuevo en su versión interna**: reutilizar
`onScrollGeometryChange` porque «ya estaba resuelto en la 004» sería reimplementar a mano lo que el
sistema regala, para obtener un comportamiento distinto del que se necesita. La constitución de este
proyecto dice que ante la duda gana la opción más simple; aquí ni siquiera hay duda.

**Tres trampas del mecanismo**, que van al `quickstart` porque ninguna prueba las alcanza:
- **Encabezado fijado sin fondo opaco**: el contenido pasa por debajo y se leen dos cosas a la vez. Es
  FR-012, y es la misma lección que la zona fija de Inicio ya lleva aplicada.
- **Sin orden de dibujado explícito**: en una pila perezosa, el contenido que se crea al desplazar
  puede dibujarse **encima** del encabezado fijado. Aparece y desaparece, y parece un fallo de render.
- **Una sección por pestaña**: cambiar de pestaña desmontaría el encabezado fijado y el desplazamiento
  daría un salto. Una sola sección, con el contenido conmutado dentro.

### D-521: Hace falta la regla de arquitectura 14, y con las dos mitades

**Decisión**: regla 14 — nadie fuera de `UI/PDF/` importa PDFKit **ni nombra** sus tipos.

**Rationale**: la regla 1 prohíbe PDFKit en `Domain`; la 6 solo encierra a los proveedores —Firebase y
GRDB— y PDFKit no lo es. Hoy **nada** impediría importarlo desde la pantalla de detalle. Y la
constitución lo exige por escrito: el visor «DEBE quedar encerrada tras una vista propia y no puede
filtrar tipos de PDFKit al resto de la aplicación». Sin regla, esa frase es un acuerdo de caballeros.

Es el mismo caso que la 10 con GRDB, y se escribe igual: **las dos mitades**. La importación caza el
marco; la referencia por nombre caza el tipo que se cuela por una firma. Y sobre el código con los
comentarios retirados, para que una nota que explique por qué el detalle no debe conocer un tipo de
PDFKit no dispare la regla que esa nota documenta.

**Y lo que la regla obliga a arrastrar**: `CLAUDE.md` dice «**trece**, en una prueba propia» y la
cabecera del fichero de reglas dice «Nueve reglas». Los dos números suben en el mismo cambio, y la
regla necesita **su propia prueba** más el paso manual del `quickstart`: provocar la violación y verla
roja. Una regla que no puede fallar no protege nada.

### D-522: Los colores que UIKit necesita se construyen en el tema, no en el visor

**Decisión**: un fichero nuevo en `Core/UI/Theme/` que expone los pocos colores de UIKit que la
interoperabilidad necesita.

**Rationale**: el fondo del visor lo pide el documento de diseño y el token **ya existe sin usar**
(`readerSurface`, `#D9DEE2`). Pero la propiedad de la vista de UIKit toma un color de UIKit, y la
regla 7 **falla la build** si alguien construye uno fuera de `Core/UI/Theme/`. La salida correcta es
obedecer la regla poniendo la construcción donde la regla la permite. La incorrecta —y la tentadora—
es dejar el fondo transparente y seguir adelante: compila, pasa las pruebas, y el visor pinta sobre el
fondo que le toque.

### D-523: El modelo de pantalla de Inicio sale del cuerpo del armazón

**Decisión**: el armazón lo construye en su inicializador y lo guarda en estado, igual que ya hace con
el suyo propio.

**Rationale**: es FR-051. Hoy se construye dentro de una propiedad calculada que el sistema evalúa en
cada redibujado, y ese nacimiento **registra una visita de pantalla y abre un intervalo de medición**.
El estado de la vista conserva el primero, así que no se ve en pantalla: se ve en el panel de
analítica, con una visita por cada apertura del panel lateral.

Entra en esta feature porque **esta feature lo empeora**: la pila de navegación del detalle añade
estado al armazón, y entonces cada entrada y cada retroceso redibujan y registran. Arreglarlo después
sería arreglar algo que habremos empeorado a sabiendas.

Se descubrió leyendo el fichero para decidir dónde colgar la ruta del detalle, no por ninguna prueba
—ninguna mira ese lado—, que es el mismo patrón por el que se descubrió lo del indicador del
enlazador: **mirando al otro lado de la frontera**.

### D-524: Los escenarios de prueba NO ganan un tercer argumento

**Decisión**: `DataScenario` gana cuatro casos nuevos, nombrados por **el desenlace que la pantalla
tiene que pintar**. La costura sigue teniendo **dos** argumentos.

**Rationale**: `LaunchConfiguration` lleva escrita la promesa de la 001 —«se sustituye, no se
amplía»—, y la 002 ya gastó su excepción, declarada en su apartado de complejidad. Un tercer argumento
sería honesto y sería exactamente lo que la constitución acota. `DataScenario` ya es el mando que
gobierna «de dónde salen los datos», y el documento es un dato más.

**La consecuencia, declarada y no supuesta**: el enumerado pasa a llevar **dos ejes** —el del boletín y
el del documento—. Con cuatro casos es aceptable. Si algún día apareciera un tercer eje, el enumerado
se parte; anotarlo ahora es lo que permite reconocerlo entonces.

La sustitución va en el mismo sitio y con la misma forma que la del descargador de feeds en el
contenedor: por encima de esa frontera, **todo es producción** —caché, almacén, repositorio, casos de
uso, modelos de pantalla y visor—, que es lo que hace que la prueba de interfaz pruebe algo.

**El documento del escenario se sintetiza en código**, no se lee de una muestra: las muestras viven en
el bundle de pruebas y **el proceso de la aplicación no las ve**, como el sembrador de la 003 ya
explica. Además, un documento literal da una huella constante que las pruebas pueden afirmar.

### D-518 · Corrección al implementar: la tarjeta NO lleva el destino dentro

**Lo que decía esta decisión**: `PublicationCard` gana un parámetro `share: ShareTarget`, derivado
por Inicio de su bandera de conexión, y sigue llevando el enlace de compartir dentro.

**Por qué no se sostiene**: decidir entre documento y enlace exige el **caso de uso**, porque puede
tener que descargar. Una vista sin estado no puede llamarlo, así que el destino que la tarjeta
recibiera nunca podría ser `document(localPath:)` de verdad —solo la promesa de uno— y el cierre de
exportación fallaría sin que nadie pudiera enseñar la explicación de FR-040.

**Lo que se hizo**: la tarjeta **emite el evento** y quien la usa resuelve y presenta, con la misma
hoja que el detalle y el visor. Consecuencias, las dos declaradas:

- `HomeUiState` **gana un campo**, `share`, y el `plan.md` decía que no ganaría ninguno.
- La tarjeta deja de llevar un `ShareLink` dentro y pasa a llevar un botón con el mismo
  identificador, la misma etiqueta y el mismo marco de cuarenta y ocho puntos.

**Y sale ganando**: FR-038 —«compartir se comporta igual desde las tres pantallas»— pasa a cumplirse
**por construcción** en vez de por parecido, porque las tres recorren exactamente el mismo camino.

### D-526: Escribir el mismo campo desde dos observaciones es una carrera, otra vez

**Decisión**: el fallo al **leer la publicación** tiene su propio campo en el estado del detalle
—`loadFailed`—, y no se escribe dentro de `document`.

**Rationale**: la primera versión lo metía en `document` con el argumento de que así reutilizaba el
error con reintento que ya estaba pintado. Y funcionaba, salvo que **la observación del documento
escribe ese mismo campo**: emite `absent` un instante después y borra el fallo que acababa de
aparecer. Lo destapó la prueba «un fallo de lectura sí es un error», que leía `.absent` donde
esperaba `.failed`.

Es **literalmente** la trampa que la feature del boletín dejó escrita —«escribir dos veces el mismo
estado desde dos sitios es una carrera aunque los dos sean correctos»—, y volvió a morder en la
feature siguiente. Se anota por segunda vez porque la primera no bastó.

**Alternativa descartada**: derivar `document` de las dos observaciones en una sola función, como
hizo Inicio con su contenido. Aquí no aplica: no son dos vistas del mismo dato, son **dos datos**
—si se pudo leer la publicación, y en qué punto está su documento—, y fundirlos obligaría a
desenredarlos otra vez en la pantalla.

### D-525: El tiempo hasta el documento se mide con un hito, no con la espera de la prueba

**Decisión**: un *signpost* nuevo, hermano del que la 003 usa para el tiempo hasta el contenido.

**Rationale**: SC-002 pide «menos de 1 segundo» y **XCUITest no sabe medir por debajo del segundo**: su
sondeo del árbol tiene granularidad de aproximadamente un segundo. La primera medición de SC-001 de la
003 dio 1,10 s y con un hito dio **126 ms**; lo que se estaba midiendo era el instrumento. Medir
SC-002 con esperas daría siempre «algo más de un segundo» y sería imposible saber si el objetivo se
cumple.

Es también el instrumento con el que se decide lo que D-502 deja abierto: si la iteración byte a byte
aguanta 25 MB dentro del presupuesto de SC-003.
