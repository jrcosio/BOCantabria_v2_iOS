# Investigación: esqueleto de arquitectura (iOS)

La constitución ya fija el marco —capas, MVVM, composition root, testing y observabilidad
desacoplada—, así que aquí no hay incógnitas de arquitectura. Lo que sí requiere decisión son los
huecos que la constitución deja abiertos a propósito y los detalles que condicionan la
testabilidad.

Referencia constante: el proyecto Android resolvió estas mismas preguntas en su feature 001
(`docs/referencia-android/specs/001-esqueleto-arquitectura/research.md`, decisiones D-001 a
D-009). **Cinco de aquellas decisiones se reutilizan y cuatro se reabren**, porque eran elecciones
de herramienta y no de arquitectura. Se indica en cada caso.

---

## D-101 · Forma del tipo de resultado

**Decisión**: `typealias AppResult<T> = Result<T, DomainError>`, sobre el `Result` de la
biblioteca estándar.

**Reabre D-003 del Android**, que eligió un `sealed interface AppResult` propio. Su razón era que
`kotlin.Result` lleva un `Throwable` dentro: el error queda opaco, el `when` de la pantalla no
puede ser exhaustivo y el compilador no avisa al añadir un caso. **Ese problema no existe aquí**:
el `Result` de Swift es genérico también en el error, así que `Result<T, DomainError>` da
exactamente la garantía que se buscaba —un `switch` exhaustivo sobre un enumerado cerrado— sin
escribir ni una línea.

Lo que se gana además: `map`, `flatMap`, `mapError` y `get()` vienen hechos y probados. El Android
tuvo que añadir `map` y `getOrNull` a mano, y ninguna de las dos aparece en su `data-model.md`
—se colaron en la implementación—.

**Alternativa descartada**: `throws(DomainError)`, el lanzamiento tipado de Swift 6. Es lo más
idiomático del lenguaje y el compilador exige tratar el error, pero un error lanzado no se puede
guardar en el estado de la pantalla sin capturarlo antes, y el estado es precisamente donde este
error tiene que acabar. Añadiría ceremonia justo en la frontera con la interfaz, que es donde más
se lee.

**Invariante que se conserva del Android**: una colección vacía es un éxito con colección vacía,
nunca un fallo. «Vacío» y «error» se distinguen en la capa de presentación.

---

## D-102 · Cómo se hace cumplir la organización del código

**Decisión**: una prueba propia que **analiza los ficheros fuente** —su ruta y sus `import`— y
falla la construcción cuando encuentra una violación. Seis reglas.

**Reabre D-006 del Android**, que usó Konsist. Konsist es de Kotlin y no tiene equivalente en
Swift. Lo que sobrevive es la exigencia, no la herramienta: SC-004 pide que el **100 %** de las
violaciones se detecten automáticamente antes de llegar a un dispositivo, y sin una comprobación
explícita ese criterio no sería verificable y la arquitectura se degradaría en silencio.

**Por qué análisis de texto y no de AST**: de las nueve reglas que el Android tiene hoy, **ocho
son puramente léxicas** sobre la lista de `import` y el paquete del fichero. Un analizador de
sintaxis (SwiftSyntax) daría precisión que estas reglas no necesitan, a cambio de una dependencia
nueva en el camino crítico de la puerta de calidad. Se dice en voz alta que es una herramienta más
pobre: por eso la lista de reglas se mantiene **corta, explícita y con prueba de la propia regla**
—una regla que no puede fallar es una regla que no protege nada—.

**Cómo encuentra la prueba el árbol de fuentes**: con `#filePath`, que el compilador sustituye por
la ruta absoluta del fichero. **Verificado, no supuesto**: una sonda ejecutada el 11 de septiembre
de 2026 en el simulador leyó el directorio de fuentes del anfitrión y enumeró su contenido. Si
algún día dejara de funcionar, la salida es inyectar `SRCROOT` en el `Info.plist` del bundle de
pruebas.

**Una diferencia con Kotlin que obliga a partir la primera regla en dos, y que casi se cuela.** En
Kotlin, cruzar de paquete exige un `import`, así que comprobar la lista de importaciones basta
para hacer cumplir la regla de capas. **En Swift, dentro de un mismo módulo no hace falta importar
nada**: un fichero de `Domain` puede nombrar un tipo de `Data` sin que aparezca una sola línea de
`import`. Traducir la regla de Konsist tal cual habría dado una regla que pasa siempre. Por eso
hay dos comprobaciones: las importaciones cazan los marcos y los SDK, y las **referencias a
tipos** —el nombre de un tipo declarado en otra capa, buscado como palabra completa sobre el
código sin comentarios ni cadenas— cazan los cruces entre capas.

**Las nueve reglas**: las seis de la 001 del Android, con la primera partida en dos por lo
anterior, más las dos que protegen el aspecto, que aquí entra en esta feature (D-111).

1. `Domain` no importa SwiftUI, UIKit, GRDB, Firebase ni PDFKit.
2. `Domain` no nombra ningún tipo declarado en `Data` ni en `UI`.
3. `UI` no nombra ningún tipo declarado en `Data`.
4. Todo tipo que acabe en `UseCase` vive en `Domain/UseCase`.
5. Todo tipo que acabe en `ViewModel` vive en `UI`, y es `@MainActor @Observable`.
6. Solo `Data` importa los módulos de Firebase.
7. Solo `Core/UI/Theme` construye colores.
8. Nada hace depender la apariencia del ajuste claro/oscuro del dispositivo (FR-015).
9. Todo tipo de dominio de nivel superior y todo modelo de pantalla tiene fichero de prueba.

**Quitar los comentarios y las cadenas antes de buscar referencias no es un detalle**: sin eso, un
comentario que explica por qué `Domain` no debe conocer `ContentRepositoryImpl` dispararía la
regla que ese comentario documenta, y la primera reacción de cualquiera sería dejar de escribir
comentarios.

Dos detalles de la regla 6 que se replican del Android porque están bien pensados: solo cuenta lo
declarado **al nivel superior del fichero** —los casos de un enumerado pertenecen al fichero de su
padre y no tienen comportamiento propio— y hay una lista de exenciones que lleva escrito al lado
que **cada entrada es un agujero en SC-002**.

**Una regla más que el Android no tenía en su 001** y aquí sí, porque el sistema de diseño entra
en esta feature: la 3 del bloque de aspecto, «solo el tema declara colores». Se comprueba como
regla de `import` y de construcción literal, no buscando cualquier mención de color, para no
marcar usos legítimos. La lección del Android es literal: *una regla que grita lobo es una regla
que la gente aprende a esquivar*.

---

## D-103 · Un solo target frente a paquetes locales por capa

**Decisión**: un único target de aplicación con separación por carpetas.

**Alternativa seriamente considerada**: un paquete Swift local por capa (`Domain`, `Data`, `UI`).
Daría separación **impuesta por el compilador**, que es estrictamente más fuerte que una prueba:
`Domain` no podría importar `Data` porque no lo tendría en su grafo de dependencias.

**Por qué se descarta**: multiplica los targets de prueba, complica las vistas previas de SwiftUI,
obliga a resolver el paquete en cada compilación limpia, y hace que cada feature futura tenga que
decidir en qué paquete cae cada fichero —una decisión nueva catorce veces—. El proyecto Android
tomó la misma decisión con el mismo argumento (un solo módulo `:app`) y la separación aguantó
quince features apoyada solo en la comprobación automática. Si algún día el proyecto crece hasta
que la prueba de reglas se quede corta, partir en paquetes es un refactor mecánico y las carpetas
ya están puestas donde tendrían que estar los targets.

---

## D-104 · Origen de datos de la rodaja de ejemplo

**Decisión**: fuentes **en memoria**, manteniendo la pareja local/remota real. La remota devuelve
una lista fija tras una latencia simulada; la local es una caché en memoria.

**Se reutiliza D-001 del Android tal cual.** El argumento no es de plataforma: mantener las dos
fuentes permite que el repositorio implemente ya la política *remoto con respaldo local* que
heredarán las features reales, y esa política tiene cuatro casos que se pueden probar hoy. Una
sola fuente simulada demostraría el recorrido entre capas pero no la política, que es la parte que
de verdad se reutiliza.

La spec lo declara en sus supuestos: red y persistencia se deciden en la primera feature de
negocio que las necesite.

---

## D-105 · Forma del estado de pantalla

**Decisión**: `enum HomeUiState` con `loading`, `content([ContentItem])`, `empty` y
`error(DomainError)`.

**Se reutiliza D-004 del Android.** El argumento es FR-002: una estructura con banderas
—`isLoading`, `items`, `errorMessage`— permite combinaciones imposibles como «cargando y con error
a la vez», y entonces la pantalla tiene que decidir a cuál hace caso. Con un enumerado, los
estados imposibles **no compilan**, y el `switch` de la vista es exhaustivo.

---

## D-106 · Cómo se consume el sistema de diseño

**Decisión**: constantes estáticas con espacio de nombres — `BocTheme.colors.primary`,
`BocTheme.spacing.md`, `BocTheme.typography.titleMedium`.

**Reabre la forma de D-002/D-013 del Android**, que usaba tres `CompositionLocal` estáticos
provistos por un envoltorio `BOCantabriaTheme`, cada uno con un `error(...)` como valor por
defecto para que leer el tema fuera del envoltorio fallara **en voz alta**.

En SwiftUI el equivalente literal sería una entrada de `EnvironmentValues`, y tiene dos problemas.
El primero es que `defaultValue` es obligatorio y silencioso: la propiedad «fallar si nadie lo ha
provisto» no se puede reproducir sin un `fatalError` en el valor por defecto, que es peor que no
tenerla. El segundo es que un canal de entorno **es un interruptor**: abre la puerta a proveer una
paleta distinta en un subárbol, que es exactamente lo que la constitución prohíbe.

Con constantes estáticas el problema desaparece en lugar de resolverse: no hay nada que proveer,
así que no hay nada que olvidar ni nada que sustituir. Y las vistas previas funcionan sin envolver
nada, que es la diferencia práctica que más se nota.

**Consecuencia aceptada**: no se puede sustituir la paleta en una prueba. No hace falta: lo que se
prueba del tema es que sus valores son los del documento de diseño, y eso se comprueba leyéndolos.

**Divergencia deliberada respecto al Android**: allí hay **dos** vocabularios —`MaterialTheme`
para los roles de Material 3 y `BocTheme` para los propios—, porque Material impone su esquema.
Aquí no hay un sistema que imponga nada, así que hay **uno solo**. Un token que en Android estaba
en `MaterialTheme.colorScheme.primary` aquí está en `BocTheme.colors.primary`, y se acabó.

---

## D-107 · Navegación

**Decisión**: `NavigationStack` con un `enum Route: Hashable`.

**Reabre D-005 del Android**, que usó Navigation Compose con rutas tipadas y por eso tuvo que
añadir el plugin de serialización de Kotlin —con un riesgo declarado y un plan de vuelta atrás—.

Lo que sobrevive es el principio: **una ruta mal escrita tiene que ser un error de compilación**,
no un fallo en el móvil (SC-004). En iOS eso sale gratis: un enumerado con valores asociados es
`Hashable` sin conformidad manual y sin ninguna dependencia. La feature solo necesita un destino,
pero el mecanismo queda montado para que añadir el siguiente no obligue a rediseñarlo (FR-006).

---

## D-108 · Concurrencia y determinismo

**Decisión**: el trabajo de `Data` va en tipos `actor`; el reloj se inyecta a través de un
protocolo propio; los modelos de pantalla se marcan `@MainActor` **explícitamente**, y el
aislamiento por defecto del proyecto es `nonisolated`.

**Se reutiliza el principio de D-007 del Android**, no su encarnación. Allí el problema era que
referenciar `Dispatchers.IO` estáticamente hace imposible controlar el tiempo virtual y produce
pruebas intermitentes, y la solución fue inyectar un `DispatcherProvider`. En Swift 6 no hay un
«despachador» que elegir ni que inyectar. Lo que **sí** sigue haciendo falta inyectar es todo lo
que hace una prueba no determinista, y en esta feature eso es el reloj: la latencia simulada del
origen remoto se pide a un `AppClock` propio, de modo que la prueba no espera de verdad.

**Sobre el aislamiento por defecto, que se decidió dos veces.** La plantilla de Xcode deja
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, y esta decisión lo dio por bueno al redactarse: todo
queda en el actor principal y lo que deba salir se marca a propósito. **Al implementar se vio que
era al revés de lo que esta arquitectura necesita.** Con ese ajuste, los tipos de `Domain` y de
`Core/Telemetry` nacen aislados al actor principal, y en cuanto un `actor` de `Data` o un espía de
pruebas los toca, no compila: el primer doble de analítica lo destapó con tres errores seguidos.
La consecuencia sería sembrar `nonisolated` por las dos capas que **nunca** deben estar en el
actor principal, que además son donde vivirá la mayor parte de las catorce features siguientes.

Puesto en `nonisolated`, la anotación cae donde tiene sentido —el modelo de pantalla se marca
`@MainActor`, y eso ya lo exige la regla de arquitectura 5— y las vistas de SwiftUI lo son por su
propio protocolo. **La regla general que deja escrita**: el ajuste por defecto de una plantilla
describe la aplicación que la plantilla imagina, que es una sin capa de datos.

**Regla que se escribe ahora porque luego cuesta más**: ninguna `Task` sin dueño. Toda tarea de un
modelo de pantalla vive en el `.task` de la vista o en una propiedad que se cancela en su sitio.
Una tarea suelta sobrevive a la pantalla y escribe en un estado que ya no se ve.

---

## D-109 · Qué pasa cuando falta la configuración de Firebase

**Decisión**: el arranque de Firebase es **condicional a la presencia del fichero**, y cuando
falta el contenedor registra las implementaciones de no operación.

**No tiene equivalente en el Android**, donde `google-services.json` sí se versiona porque su
clave está restringida por paquete **y huella de firma**. En iOS la restricción equivalente es
solo el identificador de paquete, sin prueba criptográfica, así que el fichero no se versiona
—decisión tomada el 11 de septiembre de 2026, después de que el escáner de secretos de GitHub
cazara el commit de arranque—.

La consecuencia técnica es que `FirebaseApp.configure()` **lanza** si el fichero no está. Un clon
nuevo del repositorio no lo tiene, así que sin esta decisión la aplicación se cerraría al abrirla
y las pruebas no arrancarían. FR-021 y SC-008 lo convierten en requisito: **sin ningún secreto en
el puesto, la aplicación se construye, arranca y pasa todas las pruebas.**

Esto encaja con el principio VI sin forzarlo: las implementaciones de no operación tienen que
existir de todas formas para poder sustituir la telemetría en pruebas. Lo único que añade esta
decisión es **cuándo** se eligen.

---

## D-110 · Dobles de prueba

**Decisión**: espías escritos a mano contra los protocolos, en una carpeta compartida.

**Reabre D-009 del Android**, que usó MockK. Swift no tiene *mocking* dinámico y no va a tenerlo:
no hay reflexión suficiente. Tampoco hace falta. Lo que se quiere afirmar es **exactamente qué
nombre y qué parámetros se envían**, y para eso un espía que guarda lo recibido en un array es más
directo y más legible que un doble generado.

**Detalle de Swift 6 que hay que tener presente desde el primer doble**: con concurrencia estricta,
un doble que cruce la frontera de un `actor` tiene que ser `Sendable`. Se declaran como `actor`
cuando guardan estado, o como `final class` con su estado protegido si tienen que ser síncronos.
Descubrirlo en el doble número doce sale caro.

---

## D-111 · Qué parte del sistema de diseño entra

**Decisión**: entra todo **menos los colores de sección del boletín**.

En el Android esto estuvo repartido: la 001 solo movió los ficheros de color y tipografía que traía
la plantilla, la 002 construyó el sistema y sus reglas, y los colores de sección llegaron con las
secciones. Aquí el documento de diseño está completo desde el primer día y la plantilla de Xcode no
trae ningún tema, así que ese reparto no se puede reproducir aunque se quisiera.

La línea es: **entra todo lo que no dependa de un tipo de dominio que aún no existe**. Los cinco
colores de sección se eligen a partir de una clasificación del boletín —cinco grupos para nueve
secciones, decidido así a propósito— y ese enumerado es materia de la feature de las secciones.

Y hace falta que entre: la regla «ninguna pantalla escribe un color» no se puede cumplir si la
pantalla de esta feature no tiene tokens de verdad que consumir. Una regla que obliga a inventarse
un token provisional es una regla que enseña a rodearla.

**Dos cosas que se pierden en silencio si no se copian con intención**, y por eso quedan escritas:

- **El espaciado entre letras va a cero en los catorce estilos.** El Android lo consigue no
  declarándolo, porque en Compose eso deja el valor sin especificar. Aquí hay que ponerlo a cero a
  mano: SwiftUI aplica el tracking de la fuente del sistema, que no es cero. Si no se hace, la
  tipografía se parece pero no es la misma, y nadie sabrá decir por qué.
- **Los dos tokens de «pulsado» cambian de papel.** En Android están declarados pero no se
  exponen: el efecto de pulsación de Material los absorbía. En SwiftUI no hay ese efecto, así que
  aquí sí hay que consumirlos explícitamente. Es el único token del inventario que cambia de
  función al portarlo.

---

## Lo que esta feature deja anotado para la siguiente

- **La versión mínima soportada que publica la configuración remota es un entero pensado para el
  `versionCode` de Android**, y hoy vale `0` («todo permitido»). Esta aplicación sale como `1.0.0`
  mientras el Android va por la `2.0.0`. La feature de la portada tendrá que decidir si usa una
  condición por plataforma en la consola o un parámetro propio; **reutilizar el de Android tal cual
  forzaría a actualizar la primera versión de iOS contra una cifra que habla de otra plataforma**.
- La persistencia real y el cliente de red se deciden en la feature del boletín. Las carpetas
  `Data/Source/Local` y `Data/Source/Remote` quedan creadas con la forma que tendrán.
