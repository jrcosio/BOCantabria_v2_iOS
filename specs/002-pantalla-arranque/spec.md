# Feature Specification: Pantalla de arranque y comprobación previa

**Feature Branch**: `002-pantalla-arranque`

**Created**: 2026-09-11

**Status**: Draft

**Input**: Portado a iOS de la pantalla de arranque. Reutiliza los requisitos funcionales de
`docs/referencia-android/specs/002-pantalla-arranque/spec.md`, que son de producto y siguen
valiendo aquí. Se retraducen los que hablaban de mecanismos de aquella plataforma y se reduce a
verificación todo lo relativo a la identidad visual, porque en iOS llegó con la feature 001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Abrir la aplicación y entrar sin fricción (Priority: P1)

Una persona toca el icono de BOC Cantabria. Aparece de inmediato una portada azul con el escudo de
Cantabria y las siglas del boletín, sin ningún destello blanco previo. Mientras la mira, la
aplicación prepara por su cuenta todo lo que necesita para funcionar. En cuanto está lista, la
portada da paso al contenido. La persona no ha tenido que tocar nada, y ya no puede volver atrás a
la portada.

**Why this priority**: es el camino que recorre el 100 % de las aperturas de la aplicación. Si
falla, no hay producto. Es además la primera impresión: determina si la aplicación se percibe como
oficial y cuidada o como improvisada.

**Independent Test**: instalar la aplicación en un dispositivo limpio y abrirla. Debe mostrarse la
portada y, sin intervención alguna, dar paso al contenido principal.

**Acceptance Scenarios**:

1. **Given** la aplicación instalada y con conexión, **When** la persona la abre, **Then** ve la
   portada institucional y a continuación, sin tocar nada, el contenido principal.
2. **Given** el arranque en curso, **When** la preparación termina antes de que la portada haya
   sido legible, **Then** la portada permanece visible el tiempo mínimo necesario para poder
   leerse, en lugar de parpadear.
3. **Given** que la persona ya está en el contenido principal, **When** usa el gesto de retroceso
   del sistema, **Then** no vuelve a la portada.
4. **Given** la aplicación abriéndose, **When** se observa la transición desde el icono del
   sistema, **Then** no aparece ningún destello blanco ni salto de color.
5. **Given** la preparación en curso, **When** la persona sale de la aplicación y vuelve antes de
   que termine, **Then** el arranque continúa donde estaba, sin reiniciarse ni duplicarse.

---

### User Story 2 - Enterarse de que algo va mal, y poder seguir (Priority: P1)

Una persona abre la aplicación en el metro, sin cobertura. En lugar de quedarse mirando un
indicador que gira eternamente, ve un mensaje breve que le explica qué ocurre y dos salidas:
reintentar, o entrar de todas formas para consultar lo que ya tenga guardado. Elija lo que elija,
nunca se queda atrapada en la portada.

**Why this priority**: sin esto, cualquier fallo de red convierte la aplicación en una pantalla
muerta. Es tan crítico como el camino feliz, porque es el que hace que la aplicación sea confiable.

**Independent Test**: activar el modo avión y abrir la aplicación. Debe aparecer el mensaje con sus
dos acciones; «continuar sin conexión» debe llevar al contenido principal.

**Acceptance Scenarios**:

1. **Given** el dispositivo sin conexión, **When** la persona abre la aplicación, **Then** ve un
   mensaje comprensible y las acciones de reintentar y de continuar sin conexión.
2. **Given** el mensaje de error visible, **When** la persona recupera la conexión y pulsa
   reintentar, **Then** la preparación se completa y pasa al contenido principal.
3. **Given** el mensaje de error visible, **When** la persona pulsa continuar sin conexión,
   **Then** entra al contenido principal, que mostrará su propio estado.
4. **Given** la preparación en curso, **When** la persona pulsa reintentar repetidamente,
   **Then** no se lanzan preparaciones simultáneas.
5. **Given** una red que acepta la conexión pero no responde, **When** se supera el límite de
   espera, **Then** la pantalla pasa al mismo mensaje de error con sus dos salidas, en lugar de
   seguir esperando.

---

### User Story 3 - Una puerta que de verdad cierra (Priority: P2)

Llega el día en que una versión antigua deja de poder consultar el boletín, o el servicio entra en
mantenimiento. Quien abre la aplicación en ese momento no ve un error genérico ni consigue colarse
con «continuar»: ve el mensaje que explica su situación concreta y la única salida real, que es
actualizar o volver más tarde.

**Why this priority**: es la palanca que permite retirar una versión rota o avisar de una
incidencia sin publicar una actualización. Va después de las historias 1 y 2 porque sin arranque no
hay nada que bloquear, y porque una puerta que se cierra mal deja fuera a todo el mundo: solo puede
construirse cuando el camino normal ya está verificado.

**Independent Test**: publicar en el servicio de configuración una versión mínima por encima de la
instalada y abrir la aplicación; después publicar un mensaje de mantenimiento y volver a abrirla.
En los dos casos la aplicación debe informar y no debe existir forma de llegar al contenido
principal.

**Acceptance Scenarios**:

1. **Given** que la versión instalada ha dejado de estar soportada, **When** la persona abre la
   aplicación, **Then** se le informa de que debe actualizar, **and** no se ofrece ninguna acción
   que lleve al contenido principal.
2. **Given** que el servicio está en mantenimiento, **When** la persona abre la aplicación,
   **Then** ve el mensaje de mantenimiento que se haya publicado, **and** no llega al contenido
   principal.
3. **Given** que el servicio de configuración no tiene ningún valor publicado, **When** la persona
   abre la aplicación, **Then** el arranque se completa con los valores por defecto propios y llega
   al contenido principal.
4. **Given** el dispositivo sin conexión y una versión que además ha quedado obsoleta, **When** la
   persona abre la aplicación, **Then** se le ofrecen las salidas del error recuperable, porque sin
   conexión no hay forma de saber cuál es la versión mínima.

---

### User Story 4 - Una portada que se ve institucional y se lee siempre (Priority: P3)

Una persona reconoce de inmediato que está ante información oficial: el azul institucional, el
escudo y una tipografía sobria y ordenada, idénticos en su móvil y en el de cualquier otra persona.
No cambian con el ajuste de tema del sistema, y si tiene el tamaño de letra al máximo la portada
sigue leyéndose entera, sin nada recortado.

**Why this priority**: la identidad institucional es un requisito del producto, no un adorno, pero
va después de las tres historias anteriores porque el arranque tiene que funcionar antes de poder
juzgar cómo se ve. En esta plataforma, además, el sistema de diseño ya existe: aquí se consume y se
verifica, no se construye.

**Independent Test**: abrir la aplicación con el tema claro del sistema y de nuevo con el oscuro y
comparar las capturas: deben ser indistinguibles entre sí y respecto a la imagen de referencia.
Repetir con el tamaño de texto del sistema al 200 %: ningún texto recortado. Girar el dispositivo:
la interfaz permanece vertical.

**Acceptance Scenarios**:

1. **Given** el dispositivo con el tema oscuro del sistema activado, **When** la persona abre la
   aplicación, **Then** la portada se ve exactamente igual que con el tema claro.
2. **Given** la portada visible, **When** se compara con la imagen de referencia acordada,
   **Then** coinciden en proporciones, jerarquía y color, salvo en el texto de autoría, que es el
   acordado en esta especificación.
3. **Given** el tamaño de texto del sistema al 200 %, **When** la persona abre la aplicación,
   **Then** la portada conserva su jerarquía y ningún texto queda recortado.
4. **Given** la aplicación abierta, **When** la persona gira el teléfono, **Then** la interfaz
   permanece en vertical.

---

### Edge Cases

- **Preparación muy rápida**: en un dispositivo veloz y con buena red la preparación puede terminar
  en milisegundos. La portada debe permanecer visible un tiempo mínimo legible; un parpadeo se
  percibe como un fallo.
- **Preparación muy lenta**: si el servicio acepta la conexión pero no responde, la espera no puede
  ser indefinida. Pasado un límite razonable se trata como fallo recuperable.
- **Sin configuración publicada**: la primera vez, el servicio de configuración remota puede no
  tener ningún valor definido. La aplicación arranca con valores por defecto propios, nunca se
  bloquea.
- **Sin servicio de configuración disponible**: en un puesto sin el fichero de configuración de la
  telemetría, no hay servicio remoto al que preguntar. La aplicación debe arrancar igualmente con
  los valores por defecto, y eso no es un fallo.
- **Mensaje de mantenimiento vacío o en blanco**: equivale a «sin mantenimiento». Nadie debe tener
  que comprobar dos cosas para saber si el servicio está operativo.
- **Valor de versión mínima ausente, vacío o no interpretable**: no bloquea. Un dato que no se
  entiende no puede dejar a nadie fuera de una publicación oficial.
- **Versión obsoleta y sin conexión a la vez**: si no hay forma de comprobar la versión, la falta de
  conexión manda y se ofrecen sus salidas habituales.
- **Salir y volver durante el arranque**: si la persona sale de la aplicación mientras se prepara y
  vuelve, no debe encontrarse con una preparación duplicada ni con un estado incoherente.

## Requirements *(mandatory)*

### Functional Requirements

**Arranque**

- **FR-001**: La aplicación MUST mostrar una pantalla de arranque como primera pantalla, antes que
  cualquier otra.
- **FR-002**: La transición desde el arranque del sistema hasta la pantalla de arranque de la
  aplicación MUST ser continua, sin destellos ni cambios bruscos de color.
- **FR-003**: La pantalla de arranque MUST preparar la aplicación sin intervención de la persona
  usuaria, comprobando la disponibilidad de conexión, obteniendo la configuración remota del
  servicio y verificando que la versión instalada sigue estando soportada.
- **FR-004**: Cuando la preparación termina correctamente, la aplicación MUST pasar al contenido
  principal automáticamente.
- **FR-005**: La pantalla de arranque MUST permanecer visible un tiempo mínimo suficiente para
  poder leerse, aunque la preparación termine antes. Ese mínimo MUST solaparse con el trabajo real,
  no sumarse a él.
- **FR-006**: La preparación MUST tener un límite de espera; superarlo se trata como fallo
  recuperable.
- **FR-007**: Una vez se ha pasado al contenido principal, la pantalla de arranque MUST NOT quedar
  accesible mediante ningún gesto ni control de retroceso.
- **FR-008**: La preparación MUST sobrevivir a un ciclo de segundo plano y vuelta a primer plano
  sin reiniciarse ni duplicarse.

**Estados y salidas**

- **FR-009**: La pantalla de arranque MUST representar de forma explícita y mutuamente excluyente
  los estados: preparando, listo, error recuperable y acceso bloqueado.
- **FR-010**: Ante un error recuperable, la pantalla MUST ofrecer reintentar y continuar sin
  conexión.
- **FR-011**: Reintentar mientras hay una preparación en curso MUST NOT lanzar una segunda.
- **FR-012**: Cuando la versión instalada sea inferior a la mínima soportada, la aplicación MUST
  informar de ello y MUST NOT permitir continuar al contenido principal.
- **FR-013**: Cuando el servicio publique un mensaje de mantenimiento, la aplicación MUST mostrarlo
  y MUST NOT permitir continuar al contenido principal. Un mensaje vacío o compuesto solo de
  espacios MUST tratarse como ausencia de mantenimiento.
- **FR-014**: Si el servicio de configuración remota no tiene valores publicados, o no está
  disponible en ese puesto, la aplicación MUST arrancar con valores por defecto propios que
  permiten continuar.
- **FR-015**: La comprobación de la versión MUST ser inequívoca para esta plataforma: se compara la
  versión instalada de la aplicación contra un valor publicado que se refiere a esta plataforma y
  no a otra. Un valor ausente, vacío o no interpretable MUST NOT bloquear el acceso.
- **FR-016**: Cuando concurran varias causas, la falta de conexión MUST prevalecer sobre la versión
  obsoleta y sobre el mantenimiento, porque sin conexión esos dos datos no se han podido obtener.
- **FR-017**: La visita a la pantalla de arranque MUST registrarse como evento de uso, y los fallos
  de preparación MUST reportarse al servicio de errores. Ninguno de los dos MUST incluir datos
  personales identificables.
- **FR-018**: Todo camino de fallo de la preparación MUST dejar constancia del motivo exacto en el
  registro del dispositivo, porque la pantalla no muestra códigos ni detalles técnicos.

**Composición de la portada**

- **FR-019**: La pantalla de arranque MUST componerse, de arriba abajo, con el escudo oficial, las
  siglas del boletín, su denominación completa en dos líneas, una línea divisoria, la autoría y un
  indicador de progreso discreto, sobre fondo azul institucional a pantalla completa.
- **FR-020**: La autoría MUST mostrar «Diseñada y desarrollada por» y «José Ramón Blanco Gutiérrez»
  en dos colores distintos, con el nombre destacado sobre la etiqueta.
- **FR-021**: El escudo MUST ser el recurso oficial ya incorporado al proyecto, sin recrearlo ni
  alterar sus proporciones ni sus colores.
- **FR-022**: El fondo de la pantalla de arranque MUST ocupar la pantalla entera, y la barra de
  estado del sistema MUST permanecer **oculta** desde el primer fotograma del lanzamiento hasta que
  se pasa al contenido principal, donde vuelve a mostrarse.
- **FR-023**: Los textos visibles MUST ser los mismos que muestra la aplicación equivalente ya
  publicada, en español.

**Identidad heredada (se verifica, no se construye)**

- **FR-024**: La portada y sus estados MUST tomar todos sus colores, tamaños, espaciados y formas
  de los valores con nombre del sistema de diseño existente. MUST NOT aparecer ninguna cifra ni
  ningún color escritos a mano.
- **FR-025**: La aplicación MUST conservar un único aspecto, el claro. Su apariencia MUST NOT
  cambiar con el ajuste de tema del sistema operativo ni con ninguna otra personalización de éste.
- **FR-026**: La aplicación MUST mostrarse únicamente en orientación vertical.

**Verificación**

- **FR-027**: Cada pieza de reglas de negocio y cada modelo de pantalla que introduzca esta feature
  MUST tener pruebas automáticas que se ejecuten sin interfaz.
- **FR-028**: MUST existir pruebas automáticas de interfaz que validen los cuatro estados de la
  pantalla de arranque y sus acciones.
- **FR-029**: MUST existir una prueba automática que verifique que, tras completarse el arranque,
  el retroceso no devuelve a la pantalla de arranque.
- **FR-030**: Las pruebas MUST ser deterministas: el tiempo mínimo en pantalla y el límite de
  espera se verifican con el reloj inyectado, sin esperas reales.

### Key Entities

- **Configuración de la aplicación**: los parámetros que el servicio remoto publica y que
  condicionan el arranque. Incluye la versión mínima soportada para esta plataforma y un mensaje de
  mantenimiento opcional. Tiene valores por defecto propios, que permiten continuar, para el caso
  de que no haya nada publicado o el servicio no esté disponible.
- **Resultado del arranque**: la conclusión de la preparación. Es una de tres: la aplicación puede
  continuar, la versión instalada ha quedado obsoleta, o el servicio está en mantenimiento.
- **Estado de la pantalla de arranque**: la representación completa de lo que la portada muestra en
  un instante dado —preparando, lista, error recuperable o acceso bloqueado—. Es inmutable y es la
  única fuente de verdad de lo que se dibuja.
- **Versión instalada**: la versión de la aplicación presente en el dispositivo, que se compara con
  la mínima soportada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En una instalación limpia y con conexión, la persona llega al contenido principal en
  **menos de 3 segundos** desde que toca el icono. El tiempo se mide, no se estima.
- **SC-002**: La pantalla de arranque es legible: permanece visible **al menos 1 segundo** en
  cualquier circunstancia, y nunca parpadea.
- **SC-003**: Con el dispositivo sin conexión, la persona alcanza el contenido principal en **dos
  toques como máximo**, sin quedar bloqueada en ningún momento.
- **SC-004**: Ante un servicio que acepta la conexión y no responde, la pantalla ofrece una salida
  en **menos de 10 segundos**; no existe ningún camino que deje el indicador girando
  indefinidamente.
- **SC-005**: Con la versión mínima publicada por encima de la instalada, o con un mensaje de
  mantenimiento publicado, **ninguna** secuencia de toques lleva al contenido principal.
- **SC-006**: Con los valores por defecto, es decir sin nada publicado, la primera versión de la
  aplicación **nunca** queda bloqueada por la comprobación de versión. Se verifica de forma
  mecánica, con una prueba que falla si el valor por defecto bloquea.
- **SC-007**: Toda pieza de reglas de negocio y todo modelo de pantalla que introduce esta feature
  tiene su propia prueba automática. Se verifica de forma mecánica: una comprobación automatizada
  falla si alguno carece de fichero de prueba asociado.
- **SC-008**: La composición de la pantalla de arranque conserva su jerarquía y no recorta ningún
  texto con el tamaño de letra del sistema al **200 %**.
- **SC-009**: La pantalla de arranque implementada es indistinguible de la imagen de referencia en
  proporciones, jerarquía y color, salvo en el texto de autoría, que es el acordado en esta
  especificación. Es además indistinguible de sí misma con el tema claro y con el oscuro del
  sistema.
- **SC-010**: En un puesto **sin ningún secreto** —sin el fichero de configuración de la telemetría
  y sin credenciales— la aplicación se construye, arranca hasta el contenido principal y pasa todas
  las pruebas.
- **SC-011**: Las **cuatro comprobaciones de calidad** del proyecto terminan en verde:
  construcción, pruebas sin interfaz, pruebas de interfaz y ausencia de avisos nuevos.

## Assumptions

- El marco arquitectónico **no se decide aquí**: lo fijan `.specify/memory/constitution.md` y el
  esqueleto de la feature 001.
- **El sistema de diseño ya existe.** La feature 001 entregó los valores con nombre de color,
  tipografía, espaciado, formas y elevación, el aspecto único claro, el bloqueo vertical y el
  destino solo teléfono. Esta feature los **consume y los verifica**; no vuelve a construirlos. Por
  eso los requisitos de identidad visual de la feature equivalente de Android aparecen aquí
  reducidos a FR-024, FR-025 y FR-026.
- **Las abstracciones de telemetría ya existen** y están cubiertas desde la feature 001. Esta
  feature añade sus eventos, no su mecanismo.
- **No hay todavía fuente de datos del boletín.** El arranque comprueba conexión, configuración
  remota y versión soportada, pero **no descarga el boletín**: esa decisión corresponde a la feature
  que publique el boletín. El contenido principal sigue siendo el provisional de la feature 001.
- **No se incluyen preferencias de usuario en el arranque.** No existe todavía ninguna preferencia
  real que cargar.
- **La versión que se compara es la visible en la tienda**, la que la persona reconoce como «la
  versión de la aplicación». El parámetro del proyecto Android es un entero pensado para el
  contador de compilación de aquella plataforma y hoy vale cero, de modo que **no se reutiliza tal
  cual**: qué valor se publica, con qué nombre y cómo se distingue de la otra plataforma es una
  decisión del `plan.md` de esta feature, acotada por FR-015 y SC-006.
- **Enmienda de FR-022, acordada con el propietario el 11 de septiembre de 2026.** El requisito
  decía «el fondo se extiende tras las barras del sistema, con los iconos de éstas en color claro»,
  que es la traducción literal de la feature equivalente de Android, donde la interfaz a sangre
  siempre deja las barras a la vista. **La imagen de referencia de este proyecto no tiene barra de
  estado**, y las dos fuentes no podían cumplirse a la vez. Manda la imagen: la barra se oculta. Dos
  consecuencias que conviene tener escritas: se oculta ya en el lanzamiento del sistema, no solo en
  la portada, porque si no habría un cambio visible justo en la transición que FR-002 protege; y la
  regla de arquitectura que prohíbe que la apariencia dependa del ajuste claro/oscuro del sistema
  **queda intacta**, cosa que la redacción anterior habría obligado a exceptuar, porque el único
  mecanismo para teñir de claro los iconos del sistema es precisamente el que esa regla prohíbe.

- **El escudo y la imagen de referencia ya están en el repositorio**: el recurso se convirtió en la
  feature 001 y la referencia visual es `docs/diseno/pantalla-arranque-referencia.png`, con sus
  medidas en el apartado 13 de `docs/diseno/especificaciones-diseno.md`.
- Los textos visibles están en **español** y son los mismos que en la aplicación equivalente ya
  publicada, cuyo original se conserva en `docs/referencia-android/res/strings.xml`.
- **Procedencia**: los requisitos proceden de la feature 002 del proyecto Android, conservada en
  `docs/referencia-android/specs/002-pantalla-arranque/`. Se retradujo el de «cambio de
  configuración del dispositivo», que aquí es el ciclo de segundo plano (FR-008). Se añadieron los
  de la comprobación de versión propia de esta plataforma (FR-015), la precedencia entre causas
  (FR-016), la constancia del motivo en el registro (FR-018) y el arranque sin servicio de
  configuración disponible (FR-014, SC-010). Se retiraron los que construían el sistema de diseño,
  por estar ya entregados.
