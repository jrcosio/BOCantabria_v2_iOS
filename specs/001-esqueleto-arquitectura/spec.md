# Feature Specification: Esqueleto de arquitectura de la aplicación

**Feature Branch**: `001-esqueleto-arquitectura`

**Created**: 2026-09-11

**Status**: Draft

**Input**: Portado a iOS del esqueleto de arquitectura. Reutiliza los requisitos funcionales de
`docs/referencia-android/specs/001-esqueleto-arquitectura/spec.md`, que fueron redactados sin
nombrar ninguna tecnología y por tanto siguen valiendo en esta plataforma.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La aplicación arranca y muestra contenido (Priority: P1)

Alguien instala la aplicación por primera vez y la abre. La aplicación llega hasta una pantalla
inicial sin cerrarse. Mientras trae el contenido se lo dice; cuando llega, lo muestra; si no hay
nada que mostrar, lo dice con sus palabras y no con una pantalla en blanco; y si algo falla, lo
explica y ofrece volver a intentarlo.

**Why this priority**: es el mínimo demostrable. Sin esto no hay aplicación, y las otras dos
historias describen propiedades de un código que aún no existiría.

**Independent Test**: se instala en un dispositivo limpio, se abre, y se recorren los cuatro
estados forzando el origen de datos. Entrega valor por sí sola: hay una aplicación que arranca y
muestra algo.

**Acceptance Scenarios**:

1. **Given** una instalación limpia, **When** se abre la aplicación, **Then** aparece la pantalla
   inicial sin ningún cierre inesperado.
2. **Given** la pantalla inicial pidiendo datos, **When** todavía no han llegado, **Then** se
   muestra un indicador de que está cargando y no una pantalla vacía.
3. **Given** que el origen responde con elementos, **When** llegan, **Then** se muestran en la
   pantalla y desaparece el indicador de carga.
4. **Given** que el origen responde sin ningún elemento, **When** llega la respuesta, **Then** se
   muestra un mensaje propio de «no hay contenido», **and** no se muestra un error.
5. **Given** que el origen falla y no hay nada guardado, **When** llega el fallo, **Then** se
   muestra un mensaje de error **and** una acción de reintento.
6. **Given** la pantalla en estado de error, **When** se pulsa reintentar y el origen responde,
   **Then** se muestra el contenido.
7. **Given** la pantalla mostrando contenido, **When** la aplicación pasa a segundo plano y
   vuelve, **Then** el contenido sigue ahí **and** no se vuelve a cargar.

---

### User Story 2 - Un patrón reproducible que no se degrada (Priority: P2)

Alguien que no participó en esta feature tiene que añadir una pantalla nueva. Encuentra un
ejemplo completo que recorre todas las capas, un único sitio donde se declaran las dependencias y
un único sitio donde se define el aspecto. Y si se equivoca —si mete una regla de negocio donde no
toca, o escribe un color a mano— la comprobación automática se pone en rojo antes de que llegue a
un dispositivo.

**Why this priority**: es lo que hace que las catorce features siguientes sean baratas. Sin la
comprobación automática, la separación de capas y la coherencia visual duran hasta el primer día
con prisa.

**Independent Test**: se provoca a mano una violación —una regla de negocio que importa la
plataforma, o un color escrito en una pantalla— y se comprueba que la comprobación falla; se
revierte y se comprueba que vuelve a pasar.

**Acceptance Scenarios**:

1. **Given** el código organizado en capas, **When** una pieza de reglas de negocio importa algo
   de la plataforma o de un proveedor externo, **Then** la comprobación automática falla.
2. **Given** el código organizado en capas, **When** una pantalla nombra un modelo interno de un
   origen de datos, **Then** la comprobación automática falla.
3. **Given** el aspecto definido en un único sitio, **When** una pantalla escribe un color a mano,
   **Then** la comprobación automática falla.
4. **Given** una pieza nueva de reglas de negocio o un modelo de pantalla nuevo, **When** no lleva
   su fichero de prueba, **Then** la comprobación automática falla.
5. **Given** el cableado de dependencias declarado en un único sitio, **When** se construye,
   **Then** todas las pantallas se obtienen sin instanciar nada a mano.

---

### User Story 3 - Visibilidad de uso y de fallos (Priority: P3)

Quien mantiene la aplicación necesita saber que la gente la abre y enterarse de los cierres
inesperados sin que se los cuenten. Y necesita que eso no obligue a que las reglas de negocio ni
las pantallas sepan qué proveedor hay detrás.

**Why this priority**: aporta valor real pero no bloquea a las otras dos. Solo sustituye
implementaciones detrás de contratos que ya existen.

**Independent Test**: se abre la pantalla inicial y se comprueba que el evento correspondiente
llega al panel del proveedor; se provoca un cierre inesperado y se comprueba que llega su traza.

**Acceptance Scenarios**:

1. **Given** la aplicación instalada, **When** se abre la pantalla inicial, **Then** se registra
   un evento de pantalla vista con el nombre de la pantalla.
2. **Given** la aplicación en uso, **When** se produce un cierre inesperado, **Then** se reporta
   automáticamente con su traza.
3. **Given** un evento con parámetros, **When** alguno de ellos es un dato personal
   identificable, **Then** ese parámetro no se envía.
4. **Given** el servicio de telemetría caído o mal configurado, **When** se registra un evento,
   **Then** la pantalla sigue funcionando con normalidad.

### Edge Cases

- **El origen responde sin elementos.** «Sin contenido» y «error» son estados distintos y se
  distinguen en pantalla. Una lista vacía nunca es un fallo.
- **La carga tarda.** El indicador es visible mientras dura y no se lanzan cargas duplicadas.
- **Reintentos encadenados.** Pulsar reintentar repetidamente no lanza varias cargas a la vez.
- **La aplicación vuelve de segundo plano durante la carga.** Ni se reinicia la carga ni se pierde
  el resultado en curso.
- **Falta la configuración de la telemetría.** La aplicación arranca con normalidad y la
  telemetría queda sin efecto; no se cierra ni muestra un error a quien la usa.
- **Falla el cableado de dependencias al arrancar.** El fallo es evidente y atribuible, no un
  cierre silencioso.

## Requirements *(mandatory)*

### Arranque y pantalla inicial

- **FR-001**: La aplicación MUST arrancar hasta la pantalla inicial sin cierres inesperados en una
  instalación limpia.
- **FR-002**: La pantalla inicial MUST representar de forma explícita y mutuamente excluyente los
  estados: cargando, contenido disponible, sin contenido y error.
- **FR-003**: El estado de error MUST ofrecer una acción de reintento que vuelva a solicitar los
  datos.
- **FR-004**: El contenido mostrado MUST proceder de un origen de datos a través de la cadena
  completa de capas, no estar escrito directamente en la pantalla.
- **FR-005**: El estado de la pantalla MUST sobrevivir a un ciclo de segundo plano y vuelta a
  primer plano sin recargar los datos.
- **FR-006**: La aplicación MUST disponer de un mecanismo de navegación entre pantallas preparado
  para incorporar destinos nuevos sin rediseñarlo.

### Organización del código

- **FR-007**: El código MUST organizarse en las capas y ubicaciones que define la constitución del
  proyecto, con un lugar único e inequívoco para cada tipo de pieza.
- **FR-008**: Las reglas de negocio MUST ser independientes de la plataforma y de cualquier
  proveedor externo, de modo que puedan verificarse sin arrancar la interfaz.
- **FR-009**: Los modelos internos de los orígenes de datos MUST NOT llegar a la capa de
  presentación; deben traducirse a los modelos propios de las reglas de negocio.
- **FR-010**: Todas las dependencias de la aplicación MUST declararse en un cableado central
  único, sin construcciones manuales dispersas por el código.
- **FR-011**: El cableado central MUST poder construirse de principio a fin en una comprobación
  automática, sin efectos de arranque y sin acceder a servicios externos.
- **FR-012**: Debe existir al menos un ejemplo completo y funcionando que recorra todas las capas
  y sirva de patrón de referencia para features futuras.

### Aspecto

- **FR-013**: La aplicación MUST definir su aspecto —color, tipografía, espaciado, formas y
  elevación— en un único sitio, a partir del documento de diseño del proyecto.
- **FR-014**: Ninguna pantalla ni componente MUST escribir un color, un tamaño de texto o un
  espaciado literal: todos se consumen del sitio único que los define.
- **FR-015**: El aspecto de la aplicación MUST NOT depender del ajuste claro/oscuro del
  dispositivo: es único y el mismo en todos los dispositivos.
- **FR-016**: Los elementos gráficos MUST ser los del proyecto, no los del sistema, para que la
  identidad sea la misma que en el resto de plataformas.

### Telemetría

- **FR-017**: La aplicación MUST registrar eventos de uso, incluyendo al menos la visita a la
  pantalla inicial.
- **FR-018**: La aplicación MUST reportar automáticamente los cierres inesperados junto con su
  traza.
- **FR-019**: Los servicios de telemetría MUST consumirse a través de una abstracción propia,
  sustituible por un doble en pruebas, y no invocarse desde las reglas de negocio ni desde la capa
  de presentación.
- **FR-020**: Los datos enviados a telemetría MUST NOT incluir información personal identificable.
- **FR-021**: La aplicación MUST arrancar y funcionar con normalidad aunque falte el fichero de
  configuración de la telemetría, que no se versiona; en ese caso la telemetría queda sin efecto.

### Verificación

- **FR-022**: Cada pieza de las reglas de negocio y cada modelo de pantalla MUST tener pruebas
  automáticas que se ejecuten sin arrancar la interfaz.
- **FR-023**: MUST existir una prueba automática que construya el cableado central completo y
  obtenga todas las pantallas.
- **FR-024**: MUST existir al menos una prueba automática que recorra la cadena completa de capas
  de extremo a extremo con el cableado real.
- **FR-025**: La pantalla inicial MUST tener pruebas automáticas de interfaz que validen los
  cuatro estados y la acción de reintento.
- **FR-026**: Las violaciones de la organización del código y de la definición única del aspecto
  MUST detectarse mediante una comprobación automática que falle la construcción.
- **FR-027**: Las pruebas MUST ser deterministas: sin conexiones reales a red o telemetría, sin
  depender del reloj del sistema ni del orden de ejecución.
- **FR-028**: Las plantillas de prueba de ejemplo que trae el proyecto generado MUST eliminarse,
  para no confundirlas con pruebas reales.

### Key Entities

- **Elemento de contenido**: lo que la pantalla inicial muestra. Tiene un identificador estable
  entre cargas —identifica al elemento, no a su posición— y un título no vacío. Es deliberadamente
  trivial: existe para demostrar el recorrido entre capas y se sustituirá por el modelo real.
- **Resultado de una operación**: lo que devuelven las reglas de negocio. O bien trae datos, o
  bien trae un error de un catálogo cerrado. Una colección vacía es un resultado con datos, no un
  error.
- **Error de dominio**: el catálogo cerrado de lo que puede ir mal, expresado en términos del
  problema y no del proveedor que falló.
- **Evento de uso**: un nombre y unos parámetros. El nombre sigue un formato acotado y los
  parámetros nunca contienen datos personales identificables.
- **Aspecto**: el conjunto de valores —colores, estilos de texto, espaciados, formas y
  elevaciones— que define cómo se ve la aplicación. Cada valor tiene nombre propio, y el nombre
  describe su papel y no su apariencia.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: La pantalla inicial es visible en **menos de 2 segundos** desde que se toca el icono
  en un dispositivo de gama media, sin cierres inesperados. El tiempo se mide, no se estima.
- **SC-002**: Toda pieza de reglas de negocio y todo modelo de pantalla tiene prueba propia. Se
  verifica de forma mecánica: una comprobación automatizada falla si alguna carece de fichero de
  prueba asociado.
- **SC-003**: La batería de pruebas que no arranca la interfaz termina en **menos de 2 minutos**.
- **SC-004**: Una violación de la organización del código o de la definición única del aspecto se
  detecta automáticamente antes de llegar a un dispositivo, en el **100 %** de los casos.
- **SC-005** *(seguimiento posterior, no es puerta de aceptación)*: alguien ajeno a esta feature
  añade una pantalla nueva siguiendo el patrón en **menos de 30 minutos**.
- **SC-006**: El evento de pantalla vista y la traza de un cierre inesperado son consultables en
  los paneles del proveedor en **menos de 24 horas**.
- **SC-007**: Las **cuatro comprobaciones de calidad** terminan en verde: construcción, pruebas
  sin interfaz, pruebas de interfaz y ausencia de avisos nuevos.
- **SC-008**: En un puesto **sin ningún secreto** —sin el fichero de configuración de la
  telemetría y sin credenciales— la aplicación se construye, arranca y pasa todas las pruebas.

## Assumptions

- El marco arquitectónico **no se decide en esta feature**: lo fija
  `.specify/memory/constitution.md`.
- **No hay origen de datos real.** El origen es en memoria, con la pareja local/remota completa
  para que la política de respaldo sea la de verdad. Red y persistencia se deciden en la primera
  feature de negocio que las necesite.
- El contenido de la pantalla inicial es **deliberadamente trivial** y se sustituirá.
- El proyecto de telemetría ya existe y la aplicación está registrada en él. Su fichero de
  configuración **no se versiona**, de ahí FR-021 y SC-008.
- Los **colores de sección del boletín quedan fuera**: dependen de una clasificación del dominio
  que no existe hasta la feature que traiga las secciones reales.
- Los textos visibles están en **español**.
- **Procedencia**: los requisitos proceden de la feature 001 del proyecto Android, conservada en
  `docs/referencia-android/specs/001-esqueleto-arquitectura/`. Tres se retradujeron por ser
  específicos de aquella plataforma —los dos del «cambio de configuración del dispositivo», que
  aquí es el ciclo de segundo plano (FR-005), y el de la verificación del cableado, que allí
  resolvía en ejecución y aquí lo garantiza la construcción (FR-011, FR-023)—. Se añadieron los
  del aspecto (FR-013 a FR-016), que en Android llegaron con su feature 002, y el de arrancar sin
  secretos (FR-021), que no tiene equivalente allí.
