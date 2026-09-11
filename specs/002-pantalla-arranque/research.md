# Investigación: pantalla de arranque (iOS)

La feature 001 dejó resuelto el marco: capas, contenedor, sistema de diseño, telemetría tras
abstracción y nueve reglas que fallan la construcción. Aquí no se reabre nada de eso. Lo que hay
que decidir es cómo se materializa en esta plataforma una pantalla que **existe antes que la
aplicación** y una comprobación que puede terminar de cuatro maneras.

Referencia constante: el proyecto Android resolvió las mismas preguntas en su feature 002
(`docs/referencia-android/specs/002-pantalla-arranque/research.md`, decisiones D-001 a D-013).
**Siete se reutilizan por su motivo y seis se descartan por ser mecanismo de plataforma.** Se dice
en cada caso cuál es cuál, porque el principio I de la constitución exige que las decisiones
técnicas se vuelvan a tomar aquí y la trampa de este proyecto es dar una por heredada.

Las tres decisiones que tomó el propietario —el parámetro de versión mínima, qué pinta el
lanzamiento del sistema y qué pasa con la barra de estado— están en D-207, D-202 y D-213.

---

## D-201 · La portada es un conmutador en la raíz, no un destino de navegación

**Decisión**: `RootView` observa el modelo de pantalla del arranque y muestra **o** la portada
**o** el `NavigationStack` con `HomeView` dentro. `Route` no gana ningún caso y la portada nunca
entra en la pila de navegación.

**Descarta el mecanismo de Android**, que declaraba `Route.Splash` como destino inicial y al
terminar navegaba a `Home` «descartando `Splash` de la pila»
(`contracts/internal-contracts.md:181-192` del Android). Allí el retroceso es un botón del sistema
que recorre la pila, así que FR-007 dependía de escribir bien un `popUpTo`.

**Motivo**: aquí el retroceso es un gesto de `NavigationStack`, y un destino del que se puede
volver es un destino del que **se volverá**. Si la portada nunca está en la pila, FR-007 no es algo
que haya que recordar hacer: es una propiedad de la forma del árbol de vistas. La prueba de
interfaz que lo comprueba sigue existiendo, pero pasa a confirmar una imposibilidad en vez de
vigilar una convención.

**Consecuencia deliberada**: el modelo de pantalla del arranque lo posee `RootView`, no la portada.
Es lo que permite que el estado sobreviva al ciclo de segundo plano (FR-008) sin ningún mecanismo
añadido: `RootView` no se reconstruye al volver.

**Alternativas descartadas**:
- `Route.splash` como destino inicial, calcando Android: reintroduce la pila que el requisito quiere
  vacía.
- Una hoja (`.fullScreenCover`) sobre `HomeView`: `HomeView` se construiría y empezaría a cargar
  **por debajo** de la portada, que es justo lo que el arranque quiere ordenar.

---

## D-202 · El lanzamiento del sistema se configura con el diccionario `UILaunchScreen`

**Decisión**: se desactiva la generación automática
(`INFOPLIST_KEY_UILaunchScreen_Generation = NO`) y se declara a mano un diccionario
`UILaunchScreen` en `Config/Info.plist` con `UIColorName` y `UIImageName`. **Sin Storyboard.**

`UIColorName` apunta a **`AccentColor`**, el colorset que ya existe y ya vale `#063B5C`.

**Reutiliza el motivo de D-003 del Android y descarta su mecanismo.** El motivo es idéntico y
sigue siendo cierto: el sistema **siempre** pinta algo antes que la primera vista, y si no se le
dice de qué color, lo pinta del color de fondo por defecto —blanco, porque la aplicación está
fijada a apariencia clara— y cada apertura empieza con un destello blanco sobre azul. Lo que no se
traslada es `core-splashscreen` ni la condición de permanencia: aquí el lanzamiento se sustituye
solo, en cuanto la primera vista está lista, y no hay nada que retener ni que liberar.

**Por qué `AccentColor` y no un colorset nuevo**: el azul institucional ya está escrito dos veces
—en `BocColors.primary` y en `AccentColor`, que el sistema consume antes de que `BocTheme` exista—
y hay una prueba que falla si se separan (`BocThemeTests`, «el acento del catálogo es el mismo azul
institucional»). Un tercer colorset sería un tercer sitio que mantener sincronizado y **nada** que
lo vigile hasta que alguien mire una captura. Se añade en cambio una prueba que lee el `Info.plist`
compilado y comprueba que el lanzamiento referencia ese color y esa imagen: el contrato deja de ser
una línea de configuración que nadie vuelve a leer.

**Alternativas descartadas**:
- Un `LaunchScreen.storyboard`: es lo que hace la mayoría de los proyectos y la constitución lo
  prohíbe expresamente. No hace falta: el diccionario cubre fondo e imagen, que es todo lo que la
  portada necesita del sistema.
- Dejar la generación automática y aceptar el destello: incumple FR-002, que es un requisito, no
  una preferencia.

---

## D-203 · El escudo del lanzamiento y el de la portada tienen que caer en el mismo sitio

**Decisión**: se genera un recurso propio, `ic_launch_emblem`, con el escudo a **104 pt** de alto y
**relleno transparente inferior**, de modo que al centrarlo el sistema en la pantalla quede a la
misma altura a la que la portada lo dibuja. Se deriva del mismo vector que los demás iconos, no se
dibuja a mano.

**Motivo**: el sistema centra la imagen del lanzamiento en la pantalla, a su tamaño natural, y no
admite posicionarla. La portada, en cambio, coloca el escudo por encima del centro óptico, que es
lo que pide el apartado 13.1 del documento de diseño y lo que muestra la imagen de referencia. Si
las dos posiciones no coinciden, el escudo **salta** en el instante de la transición, que es
exactamente el defecto que FR-002 quiere eliminar y que la decisión del propietario de pintar el
escudo en el lanzamiento pretende evitar. Metiendo el desplazamiento **dentro del lienzo del
recurso**, el desfase es una constante en puntos y no depende del tamaño de la pantalla, igual que
el desplazamiento que aplica la portada.

**Por qué no vale `ic_splash_emblem`, que ya está en el catálogo**: es el icono de arranque **de
Android**, un lienzo de 288×288 con el escudo escalado a 192 pt de alto, que es lo que aquella
plataforma exige. El documento de diseño pide 104 dp de alto en portada (apartado 9.3: entre 96 y
112). Usarlo dejaría un escudo casi al doble de tamaño durante el lanzamiento y un cambio de escala
al aparecer la portada, que se ve peor que el salto de posición que se está evitando.

**A verificar durante la implementación, con su tarea propia**: que el lanzamiento del sistema
acepta un recurso **vectorial** con `preserves-vector-representation`. Si no lo hiciera, la salida
es un PNG a tres escalas generado del mismo vector; la geometría no cambia.

**Alternativas descartadas**:
- Centrar también el escudo de la portada, para que coincidan sin tocar el recurso: contradice el
  documento de diseño y la imagen de referencia, y desplaza hacia abajo todo el bloque de
  identidad.
- Aceptar el salto: es visible y es justo lo que la decisión del propietario descartó.

---

## D-204 · Un solo caso de uso orquesta el arranque

**Decisión**: `PrepareStartupUseCase` encadena las tres comprobaciones y devuelve
`AppResult<StartupStatus>`. La pantalla no conoce los pasos intermedios ni el orden.

**Reutiliza D-006 del Android íntegra**, motivo incluido: si el modelo de pantalla orquestara, la
política de arranque —qué se comprueba, en qué orden, y qué manda cuando fallan dos cosas a la vez—
viviría en presentación, donde no se puede probar sin levantar un modelo de pantalla. Como caso de
uso es Swift puro y se prueba directamente, que es lo que pide FR-027.

**Ahí vive la precedencia** (FR-016), que es la parte que de verdad hay que probar: sin conexión no
se ha podido saber ni la versión mínima ni si hay mantenimiento, así que la falta de conexión manda
sobre las dos. La tabla completa está en `data-model.md`.

**Lo que el caso de uso NO hace**: imponer el tiempo mínimo en pantalla. Eso es una decisión de
presentación y vive en el modelo de pantalla (ver D-210). Un caso de uso que durmiera un segundo
sería un caso de uso imposible de reutilizar.

**Alternativas descartadas**:
- Tres casos de uso invocados desde el modelo de pantalla: reparte la política entre dos capas.
- Las comprobaciones dentro del repositorio: mezcla obtener datos con decidir qué significan.

---

## D-205 · La conectividad es un repositorio, y aquí significa menos que en Android

**Decisión**: `ConnectivityRepository` se declara en `Domain/Repository`, se implementa en `Data`
sobre `NWPathMonitor` encerrado en un `actor`, y su resultado **solo sirve para clasificar el
fallo**, no para decidir si se intenta la petición.

**Reutiliza la forma de D-010 del Android** —modelarla como repositorio para que `Domain` no vea la
plataforma, y para poder simular «sin conexión» en una prueba sin modo avión— **y corrige su
semántica**, que no se traslada.

**La corrección, que es lo importante de esta decisión**: el contrato de Android decía «responde si
el dispositivo tiene una red **con acceso validado a internet**, no si hay una interfaz activa», y
podía prometerlo porque el sistema operativo expone esa distinción. `NWPathMonitor` **no la
expone**: dice si hay un camino utilizable, y un portal cautivo lo tiene. Copiar aquella frase aquí
sería escribir en el contrato una garantía que el código no da. Así que:

- La comprobación **que manda** es que la configuración remota se obtenga. Si se obtiene, hay
  internet, se mire como se mire.
- La conectividad solo elige **qué mensaje** se muestra cuando algo falla: «comprueba tu conexión»
  o «se ha producido un error inesperado». Es la diferencia entre dos cadenas, no entre dos
  comportamientos.

Queda escrito en el contrato para que nadie lo lea al revés más adelante.

**Alternativas descartadas**:
- Cortocircuitar: si no hay camino, ni intentar la petición. Ahorra una llamada que iba a fallar en
  milisegundos y a cambio hace que el resultado dependa de un monitor que puede ir por detrás del
  estado real de la red.
- Prescindir de la conectividad: un fallo de red y un fallo del servicio darían el mismo mensaje, y
  el primero es el caso frecuente y el que la persona puede resolver.

---

## D-206 · La versión instalada es un valor inyectado, no un proveedor

**Decisión**: `AppVersion` es un modelo de dominio y el composition root lo construye una vez
leyendo el paquete. El caso de uso lo recibe **como valor** en su inicializador. No hay
`AppVersionProvider`.

**Reabre D-009 del Android**, que declaraba una interfaz `AppVersionProvider` en `core/util`. Su
motivo era correcto y sigue valiendo —un acceso estático al número de versión no se puede sustituir
en una prueba, así que la rama «versión por debajo del mínimo» exigiría emulador—, pero **aquí el
motivo se satisface sin la interfaz**: la versión es un dato, no un servicio; no cambia mientras la
aplicación vive, no falla y no tarda.

Lo que se gana: una pieza menos, y una prueba que declara la versión que le interesa pasándola al
inicializador, en la misma línea en que construye el caso de uso.

**Alternativas descartadas**:
- El protocolo, calcando Android: un protocolo con una propiedad constante es un doble de prueba
  que hay que escribir y un fichero que mantener, a cambio de nada.
- Leer el paquete dentro del caso de uso: es lo que D-009 prohibía con razón. `Domain` no puede
  saber que existe un paquete, y la rama no se podría probar.

---

## D-207 · La versión mínima es un parámetro propio de esta plataforma, comparado semánticamente

**Decisión del propietario**: se da de alta en la consola un parámetro nuevo,
**`min_supported_version_ios`**, de tipo texto, con la versión de mercado («1.0.0»). Se compara
contra `CFBundleShortVersionString`, que es la versión que la persona ve en la tienda. El valor por
defecto es **«0.0.0»**, que no bloquea a nadie. El `min_supported_version_code` de Android **no se
toca**.

**Es la decisión que `CLAUDE.md` dejó abierta para este plan**, y no tiene equivalente en Android:
allí el `versionCode` es un entero monótono generado en la compilación y el parámetro habla
directamente de él.

**Motivo**: las dos alternativas reales se descartaron por lo mismo, que un solo nombre acabe
significando dos cosas.
- *Condición por plataforma sobre `min_supported_version_code`*: el parámetro seguiría llamándose
  igual en las dos aplicaciones y valdría cosas distintas según una condición que **no se ve desde
  el código**. Quien lea el código iOS no puede saber qué valor recibirá.
- *Parámetro propio, pero por número de compilación*: sería el calco más literal de Android, pero
  el número de compilación no es lo que la persona ve en la tienda, así que decidir qué publicar
  obligaría a consultar qué compilación corresponde a qué versión. Se publica mal una vez y se
  bloquea a quien no tocaba.

**Lo que hace falta probar, y por qué**: FR-015 y SC-006 exigen que un valor **ausente, vacío o no
interpretable no bloquee**. Es la defensa contra el peor fallo posible de esta feature —dejar fuera
a todo el mundo por una errata en una consola— y por eso tiene prueba propia, no solo una rama del
`switch`.

**Consecuencia operativa, que va al quickstart**: el parámetro **todavía no existe** en la consola.
Hasta que el propietario lo dé de alta, la aplicación arranca con el valor por defecto, que es
exactamente lo que FR-014 exige. No bloquea la feature.

---

## D-208 · Los valores por defecto viven en `Domain`, y en ningún otro sitio

**Decisión**: `AppConfig.default` es la única declaración de los valores por defecto. El repositorio
cae a ella cuando el servicio no devuelve nada utilizable. **No se usa `setDefaults` del SDK.**

**Reutiliza el motivo de D-008 del Android y descarta su mecanismo.** El motivo —que los valores por
defecto estén en **un** sitio, y no repartidos por el código detrás de operadores de respaldo— se
conserva íntegro. Lo que cambia es dónde está ese sitio.

Android los cargaba en el propio cliente, con un recurso XML, y así una lectura nunca devolvía
vacío. Aquí ese mecanismo **no basta**, porque hay un caso que Android no tiene: en un puesto sin
`GoogleService-Info.plist` no hay cliente al que cargarle nada (ver D-209). Como el respaldo del
repositorio hay que escribirlo de todas formas, `setDefaults` sería un **segundo** mecanismo para
lo mismo, y dos mecanismos para un valor son dos valores en cuanto alguien toca uno.

**Alternativas descartadas**:
- `setDefaults` además del respaldo: lo dicho, dos sitios.
- Los valores por defecto en `Data`, junto a las claves del servicio: `Domain` tendría que aceptar
  un `AppConfig` opcional y decidir qué hacer con la ausencia, que es precisamente la decisión que
  el valor por defecto existe para evitar.

---

## D-209 · Sin el fichero de configuración del proveedor, la aplicación arranca igual

**Decisión**: la resolución de la telemetría que hizo la feature 001 pasa a resolver **también** la
fuente de configuración remota, en el mismo punto y con la misma comprobación. Cuando el fichero no
está, se registra `UnavailableRemoteConfigDataSource`, que devuelve valores vacíos; el repositorio
cae a `AppConfig.default` y el arranque concluye en «se puede continuar».

**No tiene equivalente en Android** —allí el fichero del proveedor sí está versionado— y es la
extensión natural de D-109 de la feature 001, que resolvió lo mismo para la analítica y el informe
de fallos.

**Motivo**: SC-010 exige que en un puesto sin ningún secreto la aplicación se construya, arranque y
pase todas las pruebas. Si la configuración remota fallara ahí, el arranque terminaría en error
recuperable y **la pantalla de error sería lo normal en desarrollo**, que es la forma más rápida de
que una pantalla de error deje de mirarse.

**Restricción técnica que obliga a resolverlo en un solo punto**: el cliente de configuración
remota exige que la aplicación del proveedor esté configurada, y configurarla dos veces es un
error. Hoy eso ocurre dentro de la resolución de la telemetría; la fuente de configuración tiene
que salir de la misma llamada, no de una segunda.

**Alternativa descartada**: una comprobación independiente de la presencia del fichero en la fuente
de configuración. Serían dos sitios decidiendo lo mismo y nada que garantice que deciden igual.

---

## D-210 · Mínimo de 1.200 ms en paralelo, límite de espera de 8 s

**Decisión**: la portada permanece **1.200 ms** como mínimo, esperando **en paralelo** al trabajo
real y no en serie. La preparación se abandona a los **8 s** y se trata como fallo recuperable. Los
dos tiempos salen del `AppClock` inyectado que ya existe.

**Reutiliza D-004 y D-005 del Android íntegras**, cifras y motivos. Se repiten aquí porque son los
que hay que poder discutir:

- *El mínimo*: en un dispositivo rápido con buena red la preparación puede acabar en 50 ms, y un
  parpadeo se percibe como un error de la aplicación, no como velocidad. **En paralelo** y no en
  serie porque sumarlos haría el arranque artificialmente lento para todo el mundo, y el problema
  solo lo tienen los rápidos.
- *El límite*: sin él, una red que acepta la conexión y no responde deja la portada girando para
  siempre, que es el escenario exacto que la historia 2 quiere evitar. Ocho segundos bastan para
  una red lenta pero honesta y son cortos frente al momento en que la persona cierra la aplicación.

**Lo que aquí es distinto**: el reloj inyectado ya existe desde la feature 001 (`AppClock`), así que
la pieza que faltaba en Android —la inyección— aquí viene puesta. Lo que falta es el doble que la
aprovecha, y es la decisión siguiente.

**Alternativa descartada** (de Android, y se mantiene descartada): fiarse del tiempo de espera
propio del cliente de configuración remota. No cubre el resto de la preparación y su valor no está
bajo nuestro control.

---

## D-211 · Hace falta un reloj de prueba controlable, y el que hay no sirve

**Decisión**: se añade `ManualClock` a los dobles compartidos. Suspende cada `sleep` hasta que la
prueba avanza el tiempo explícitamente, y registra lo que se le pidió esperar.

**No tiene equivalente en Android**, que usaba el tiempo virtual de su biblioteca de corrutinas. Es
una consecuencia directa de la herramienta de esta plataforma.

**Motivo, y es un fallo que habría pasado desapercibido**: el único doble de reloj del proyecto es
`ImmediateClock`, que devuelve al instante. La carrera del límite de espera enfrenta el trabajo
real contra un `sleep(8)`. Con `ImmediateClock`, **ese `sleep` gana siempre**: toda prueba del
arranque terminaría en «se agotó el tiempo», y las que afirmaran el camino feliz fallarían por un
motivo que no tiene nada que ver con lo que quieren comprobar. Peor aún, la prueba del propio
límite pasaría en verde **sin haber comprobado nada**, porque también habría ganado si el límite
estuviera mal escrito.

Lo mismo vale para el mínimo en pantalla: con un reloj que no espera no se puede distinguir
«esperó en paralelo» de «no esperó», que es justo lo que FR-030 y SC-002 piden demostrar.

**Alternativas descartadas**:
- Esperas reales en las pruebas: más de un segundo por caso, una suite sensible a la carga de la
  máquina y el principio V de la constitución incumplido.
- Bajar los tiempos en las pruebas a milisegundos: convierte una prueba determinista en una carrera
  que casi siempre gana quien tiene que ganar. «Casi siempre» es el peor resultado posible en una
  puerta de calidad.

---

## D-212 · La costura de las pruebas de interfaz se amplía, y se dice en voz alta

**Decisión**: `LaunchConfiguration` gana un segundo argumento, `-boc-startup-scenario=`, con los
escenarios `ready`, `offline`, `updateRequired`, `maintenance` y `slow`. El composition root lo lee
y sustituye las dependencias del arranque.

**Esto contradice, a sabiendas, lo que dice la cabecera de ese fichero**: «la costura está acotada a
propósito […] cuando la feature del boletín traiga el origen real, esto se sustituye por lo que
decida su plan, no se amplía». La frase se escribió pensando en el origen de contenido, y sigue
valiendo para él: el escenario de contenido no se toca y desaparecerá con la feature 003.

**Motivo para ampliarla igualmente**: FR-028 exige pruebas de interfaz de los cuatro estados y sus
acciones. Una prueba de interfaz corre **en otro proceso** y no puede sustituir nada por dentro; el
único mecanismo de esta plataforma son los argumentos de lanzamiento. Sin la costura, tres de los
cuatro estados —sin conexión, versión obsoleta y mantenimiento— no son alcanzables desde una prueba
automática, y quedarían verificados solo a mano. Eso no es una opción: son los estados que nadie
mira hasta que fallan.

**Cómo se acota para que no crezca sola**: los escenarios son un enumerado, no una cadena; el
respaldo silencioso sigue siendo el camino normal; y la sustitución ocurre en **un** punto del
composition root. Va a *Complexity Tracking* del `plan.md`, que es donde la constitución exige que
vivan las desviaciones.

**Alternativa descartada**: una compilación aparte para pruebas, con las dependencias cambiadas.
Duplica la configuración del proyecto y hace que lo que se prueba no sea lo que se publica.

---

## D-213 · La barra de estado se oculta, y eso deja intacta la regla 8

**Decisión del propietario**: la barra de estado permanece oculta desde el primer fotograma del
lanzamiento hasta que se pasa al contenido principal. Se declara en el `Info.plist` para que el
lanzamiento del sistema y la portada coincidan, y la portada la mantiene oculta.

**Descarta la consecuencia que D-013 del Android arrastraba** —fijar explícitamente los iconos de
las barras a apariencia clara— porque partía de una interfaz a sangre en la que las barras siempre
se ven.

**Motivo**: las dos fuentes de verdad se contradecían. FR-022 decía «iconos en color claro», que es
la traducción literal de Android; **la imagen de referencia de este proyecto no tiene barra de
estado**. Manda la imagen, y FR-022 queda enmendado en `spec.md` con su porqué.

**La razón técnica que inclina la balanza, y conviene que quede escrita**: el único mecanismo de
SwiftUI para teñir de claro los iconos del sistema es `preferredColorScheme`, que la **regla 8 de
arquitectura prohíbe en todo el proyecto**. Cumplir FR-022 al pie de la letra habría exigido
exceptuar la carpeta de la portada, es decir, abrir un agujero en la regla que garantiza que la
aplicación tiene un solo aspecto, para conseguir un efecto que la imagen de referencia ni siquiera
pide. Ocultar la barra no toca ninguna regla.

**Por qué también en el lanzamiento y no solo en la portada**: si el sistema mostrara la barra
durante el lanzamiento y la portada la ocultara, habría un cambio visible **exactamente** en la
transición que FR-002 protege. Se oculta en los dos o no se oculta en ninguno.

---

## D-214 · Los tres tamaños del apartado 13.2 se declaran en el tema, aparte de la escala

**Decisión**: se añade un grupo `BocTypography.splash` con los tres estilos que el apartado 13.2 del
documento de diseño define para la portada y que **no están** en la escala de catorce del apartado
6.2: el subtítulo (20 pt, peso medio, espaciado entre letras amplio) y las dos líneas de autoría
(13 pt y 15 pt semibold). Obliga a que `tracking` deje de ser una constante cero y pase a ser una
propiedad con cero por defecto.

**Emparenta con D-012 del Android** —los pesos 650 se implementan como semibold, el peso real más
cercano— que se mantiene tal cual: la familia del sistema de esta plataforma tampoco ofrece el 650.

**Motivo**: la regla 7 de arquitectura prohíbe construir colores fuera del tema y la convención del
proyecto extiende esa prohibición a tamaños y espaciados. Los tres valores del apartado 13.2 son
valores del documento de diseño, con nombre y sitio; lo que no tienen es hueco en la escala de
catorce. Meterlos **dentro** de esa escala la ensuciaría: dejaría de ser la transcripción del
apartado 6.2 que su cabecera dice que es. Declararlos como grupo aparte los deja donde la regla
quiere —en el tema— sin mentir sobre qué son.

**El detalle del espaciado entre letras, que es el que obliga al cambio de forma**: la cabecera de
la tipografía explica que los catorce estilos llevan espaciado cero **a propósito**, porque el
apartado 6.2 no lo declara y la fuente del sistema trae el suyo. El apartado 13.2 **sí** lo declara
para el subtítulo («tracking amplio»), así que el hueco que aquella nota dejó abierto se cierra
aquí: la propiedad pasa a ser almacenada y los catorce siguen valiendo cero.

**Alternativas descartadas**:
- Mapear al token más cercano de la escala (20/semibold para el subtítulo, 12 o 14 para la
  autoría): pierde el peso y el espaciado que el documento declara expresamente, y la portada es la
  pantalla en la que SC-009 exige indistinguibilidad respecto a la referencia.
- Escribir los tres valores en la vista: la regla los dejaría pasar —solo vigila colores— y sería
  exactamente el precedente que la convención quiere impedir.
