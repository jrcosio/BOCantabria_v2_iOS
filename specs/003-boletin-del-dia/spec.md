# Feature Specification: Boletín del día — lectura del BOC y pantalla de Inicio

**Feature Branch**: `003-boletin-del-dia`

**Created**: 11 de septiembre de 2026

**Status**: Draft

**Input**: User description: «Dos trabajos en una feature. Primero, leer el Boletín Oficial de
Cantabria de sus diecinueve fuentes oficiales y guardarlo en el dispositivo, que pasa a ser la
única procedencia de lo que la aplicación muestra. Segundo, la pantalla de Inicio, donde se
visualiza lo guardado, con la tarjeta de publicación del documento de diseño, un panel lateral
para las secciones del BOC y el armazón de navegación inferior. En la barra superior: el control
que abre el panel, después el escudo con el nombre de la aplicación, y al otro lado la lupa —que
dice «Próximamente»— y un icono de información que todavía no hace nada. Sin campana de avisos.
Abajo, tres destinos: Inicio, que es la pantalla que se está haciendo, y Buscar y Guardados, que
dirán «Próximamente». Pulsar una tarjeta no lleva a ningún sitio: el detalle de la publicación es
la feature siguiente.»

Esta especificación **reutiliza los requisitos de producto** de la feature Android equivalente
—`docs/referencia-android/specs/003-boletin-del-dia/`— y les incorpora de salida las correcciones
que allí llegaron después, en la feature 013. El diseño técnico **no se hereda**: se escribe para
iOS en `plan.md` y en `research.md`. El detalle de qué se reutiliza, qué se retraduce y qué se
añade está al final, en *Procedencia*.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el boletín del día nada más abrir (Priority: P1)

Una persona abre BOC Cantabria. Tras la portada aparece Inicio y, en cuestión de segundos, el
boletín del día: la fecha de la última edición publicada, cuántos anuncios contiene y la lista de
publicaciones en tarjetas legibles, cada una con el organismo que la emite, su título completo y
su fecha. No ha tenido que buscar nada ni configurar nada: la aplicación ha ido al Boletín Oficial
de Cantabria, ha recogido lo publicado en sus fuentes oficiales y se lo ha presentado ordenado.

**Why this priority**: es la razón de ser de la aplicación. Sin esto no hay producto: hoy la
pantalla principal muestra datos de relleno puestos para demostrar que las capas se hablan. Es
además la primera vez que la aplicación habla con el servicio real del BOC.

**Independent Test**: instalar en un dispositivo limpio, abrir con conexión y comprobar que
aparecen publicaciones reales del BOC con su organismo, su título y su fecha, y que la cabecera
muestra la fecha de la última edición disponible, rotulada, y el número de publicaciones de esa
fecha.

**Acceptance Scenarios**:

1. **Given** una instalación limpia con conexión, **When** la persona llega a Inicio, **Then** ve
   primero marcadores de carga y después las publicaciones de la fecha más reciente disponible,
   ordenadas de forma estable.
2. **Given** publicaciones a la vista, **When** la persona lee una tarjeta, **Then** distingue sin
   esfuerzo el organismo emisor, el título y la fecha de publicación, y reconoce la sección por su
   indicador de color acompañado de texto.
3. **Given** la cabecera de Inicio con el boletín del día, **When** hay publicaciones, **Then**
   muestra su denominación, la fecha de la edición en formato legible en español **precedida de un
   rótulo que dice de qué fecha se trata**, y el número de publicaciones que contiene.
4. **Given** una fuente oficial que no responde, **When** las demás sí responden, **Then** la
   persona ve las publicaciones de las que sí respondieron, sin ningún mensaje de error.
5. **Given** que ninguna fuente oficial responde y no hay nada guardado, **When** la persona llega
   a Inicio, **Then** ve un mensaje comprensible con la acción de reintentar, nunca una pantalla en
   blanco.

---

### User Story 2 - Que lo consultado siga estando sin conexión (Priority: P1)

La misma persona vuelve a abrir la aplicación en el metro, sin cobertura. El boletín que consultó
antes sigue ahí, íntegro y al instante, con un aviso discreto de que no hay conexión. Cuando
recupera la señal, desliza hacia abajo y la lista se actualiza sin que el contenido desaparezca
mientras tanto.

**Why this priority**: es lo que convierte la descarga en almacenamiento útil y lo que justifica
guardar en el dispositivo. Una aplicación de consulta oficial que solo sirve con cobertura no
sirve. Es tan crítica como la historia 1 porque comparte con ella el camino de datos.

**Independent Test**: abrir con conexión, cerrar, activar el modo avión y volver a abrir. Debe
verse exactamente el mismo contenido, de inmediato, con el aviso de falta de conexión.

**Acceptance Scenarios**:

1. **Given** contenido consultado previamente, **When** la persona abre la aplicación sin conexión,
   **Then** ve ese contenido de inmediato, sin esperar a ninguna descarga, con un aviso de que no
   hay conexión que no tapa el contenido.
2. **Given** contenido a la vista, **When** la persona desliza hacia abajo para actualizar,
   **Then** aparece un indicador de progreso discreto y el contenido existente permanece visible
   durante toda la actualización.
3. **Given** una actualización que no encuentra novedades, **When** termina, **Then** el contenido
   permanece intacto y no se muestra ningún error.
4. **Given** publicaciones guardadas que han dejado de aparecer en la fuente oficial por
   antigüedad, **When** se sincroniza de nuevo, **Then** esas publicaciones **siguen** guardadas y
   consultables.
5. **Given** la aplicación abierta hace menos de treinta minutos, **When** la persona vuelve a
   abrirla, **Then** no se lanza una descarga nueva y el contenido aparece de forma inmediata.

---

### User Story 3 - Explorar el BOC por secciones (Priority: P2)

Una persona busca oposiciones. Toca el control de la barra superior y entra desde el borde
izquierdo un panel con las nueve secciones oficiales del BOC, encabezado por el escudo y el nombre
de la aplicación. Despliega «Autoridades y personal» y elige «Cursos, oposiciones y concursos». El
panel se retira y la lista muestra las publicaciones de esa subsección, con la cabecera
nombrándola y con la fila de subsecciones desplegada bajo los chips de sección. Un toque en el
primer chip la devuelve al boletín del día.

**Why this priority**: es lo que hace navegable el corpus del BOC más allá del día en curso. Va
después de las dos primeras porque necesita que exista contenido guardado que explorar.

**Independent Test**: abrir el panel, desplegar una sección con subsecciones y elegir una;
comprobar que la lista, la cabecera y las dos filas de chips cambian, y que el primer chip devuelve
al boletín del día.

**Acceptance Scenarios**:

1. **Given** Inicio a la vista, **When** la persona acciona el control de la barra superior,
   **Then** se abre el panel con su cabecera y las nueve secciones principales, cada una con su
   número y su nombre.
2. **Given** el panel abierto, **When** la persona acciona la flecha del final de la cabecera,
   **Then** el panel se retira, no se navega a ninguna parte y la selección no cambia.
3. **Given** una sección con subsecciones, **When** la persona la despliega, **Then** ve sus
   subsecciones agrupadas y visualmente subordinadas a ella; al contraerla, desaparecen.
4. **Given** una sección o subsección elegida, **When** el panel se retira, **Then** la lista
   muestra las publicaciones de esa sección **sin limitarse a una fecha**, ordenadas de la más
   reciente a la más antigua, y la cabecera la nombra con el rótulo de fecha que corresponde a una
   sección.
5. **Given** el boletín del día a la vista, **When** la persona toca el chip de una sección que
   tiene subsecciones, **Then** la lista pasa a la sección completa **y** aparece debajo la fila de
   sus subsecciones, en un solo toque.
6. **Given** una subsección elegida desde la segunda fila, **When** la persona mira la primera
   fila, **Then** la sección padre sigue marcada.
7. **Given** una sección sin ninguna publicación —o sin publicaciones desde hace años—, **When** la
   persona la elige, **Then** ve un estado vacío con un mensaje propio, **nunca** un error.
8. **Given** una sección elegida, **When** la persona toca el primer chip, **Then** vuelve al
   boletín del día y la segunda fila desaparece.
9. **Given** una sección elegida, **When** el sistema operativo termina el proceso y la persona
   vuelve a abrir la aplicación, **Then** la selección se conserva.

---

### User Story 4 - Moverse por la aplicación sin toparse con callejones (Priority: P3)

La persona ve abajo tres destinos —Inicio, Buscar y Guardados— y arriba una lupa y un icono de
información. Todavía no todos hacen algo: los que no, lo dicen con claridad y con el mismo
lenguaje, en lugar de no responder o de llevar a una pantalla rota.

**Why this priority**: es el armazón que sostendrá las features siguientes. No aporta valor por sí
misma, pero evita que la aplicación se perciba como incompleta y fija de una vez la estructura de
navegación.

**Independent Test**: recorrer los tres destinos de la barra inferior y las dos acciones de la
barra superior comprobando que ninguna deja a la persona sin respuesta.

**Acceptance Scenarios**:

1. **Given** cualquier destino, **When** la persona usa la barra inferior, **Then** llega al
   destino elegido y la barra refleja cuál está activo.
2. **Given** Buscar o Guardados, **When** la persona entra, **Then** ve una pantalla con el aspecto
   de la aplicación que indica que la funcionalidad llegará próximamente.
3. **Given** Inicio, **When** la persona toca la lupa de la barra superior, **Then** recibe un
   aviso breve de que la búsqueda llegará próximamente.
4. **Given** una tarjeta de publicación, **When** la persona usa la acción de compartir, **Then**
   el sistema ofrece las formas habituales de compartir el enlace del documento oficial.
5. **Given** una tarjeta de publicación, **When** la persona usa la acción de guardar, **Then**
   recibe un aviso de que esa funcionalidad llegará próximamente.
6. **Given** Inicio, **When** la persona usa el gesto de volver del sistema, **Then** no reaparece
   la portada.

---

### Edge Cases

- **Fuente oficial vacía**: la subsección de Subastas judiciales devuelve una respuesta válida con
  cero publicaciones. Es un resultado correcto, no un fallo, y no debe generar aviso alguno.
- **Fuente sin novedades recientes**: hay subsecciones cuya última publicación es de 2021 o de
  2024. Se muestran tal cual, con su fecha real. No se interpreta como caída del servicio, y el
  rótulo de la cabecera —«última publicación»— es justo lo que evita que una fecha de hace dos años
  se lea como un error.
- **Categorías desordenadas**: en la subsección de Seguridad Social hay publicaciones antiguas
  cuyos componentes de clasificación aparecen permutados. Ni rompen el proceso ni se descartan: se
  clasifican por la fuente de la que proceden y se anota la anomalía.
- **Clasificación ausente o contradictoria**: si una publicación no trae clasificación, o la que
  trae no corresponde a la fuente de la que se obtuvo, manda la fuente y se conserva el valor
  original.
- **Publicación sin identificador en el enlace**: debe seguir siendo identificable de forma estable
  para no duplicarse en sincronizaciones sucesivas.
- **La misma publicación en dos fuentes**: se conserva un único registro, no dos tarjetas iguales.
- **Fecha no interpretable**: la publicación se rechaza sin detener el resto de la fuente, y queda
  constancia del motivo.
- **Respuesta que no es lo esperado**: si una fuente devuelve algo que no es el formato acordado, o
  un cuerpo desmesuradamente grande, se descarta esa fuente y las demás continúan.
- **Título muy largo**: se guarda íntegro, sin recortar; el recorte es solo cosa de la pantalla.
- **Primera apertura sin conexión**: no hay nada guardado y no se puede descargar. Debe ofrecerse
  un mensaje claro con reintento, no una pantalla vacía sin explicación.
- **Actualización mientras hay otra en curso**: deslizar repetidamente no debe lanzar descargas
  simultáneas ni duplicar publicaciones.
- **Sección elegida que se queda sin segunda fila**: al pasar de una sección con subsecciones a una
  que no las tiene, la segunda fila desaparece sin dejar hueco ni desplazar el listado de golpe.
- **Tamaño de letra al 200 %**: las tarjetas crecen; no se recorta el organismo, el título ni la
  fecha, y la posición de lectura no se pierde al cambiarlo.
- **Panel abierto y aplicación en segundo plano**: al volver, el panel está como se dejó y no ha
  perdido la selección.

## Requirements *(mandatory)*

### Functional Requirements

**Obtención del boletín**

- **FR-001**: La aplicación MUST obtener las publicaciones del Boletín Oficial de Cantabria de las
  diecinueve fuentes oficiales publicadas, que cubren las nueve secciones y sus subsecciones.
- **FR-002**: El inventario de fuentes MUST estar declarado de forma explícita y versionada, con su
  identificador exacto, su sección, su subsección cuando la tenga y su orden de presentación. Las
  direcciones MUST NOT construirse por cálculo a partir de otras.
- **FR-003**: El inventario MUST permitir añadir, retirar o desactivar una fuente sin alterar el
  proceso de lectura.
- **FR-004**: El fallo de una fuente MUST NOT impedir el procesamiento de las demás.
- **FR-005**: La obtención MUST limitar el número de fuentes consultadas de forma simultánea, para
  no someter al servicio oficial a diecinueve peticiones a la vez.
- **FR-006**: La obtención MUST aplicar límites de espera holgados y reintentos con espera
  creciente ante fallos transitorios, y MUST NOT reintentar ante fallos que no van a resolverse
  solos.
- **FR-007**: La aplicación MUST identificarse ante el servicio oficial de forma reconocible.
- **FR-008**: El procesamiento del contenido recibido MUST rechazar definiciones de tipo de
  documento y entidades externas, y MUST aplicar un límite de tamaño de respuesta y un límite de
  número de publicaciones por fuente.
- **FR-009**: Una fuente que responde correctamente con cero publicaciones MUST tratarse como
  resultado válido.
- **FR-010**: Una publicación que no cumpla los mínimos —título, enlace válido y fecha
  interpretable— MUST rechazarse individualmente, dejando constancia del motivo, sin detener el
  procesamiento del resto de esa fuente.

**Normalización y clasificación**

- **FR-011**: La fecha de publicación MUST interpretarse en formato año-mes-día.
- **FR-012**: La sección y la subsección de una publicación MUST tomarse de la fuente de la que se
  obtuvo, no del campo de clasificación que acompaña a la publicación.
- **FR-013**: El campo de clasificación original MUST conservarse sin modificar, y MUST utilizarse
  solo para enriquecer y verificar.
- **FR-014**: El tipo de edición —ordinaria o extraordinaria— MUST detectarse en cualquier posición
  del campo de clasificación; si no aparece, MUST registrarse como desconocido.
- **FR-015**: El proceso MUST NOT asumir un número fijo de componentes ni un orden fijo en el campo
  de clasificación, y MUST anotar una advertencia cuando el orden o los valores no sean los
  esperados, sin descartar la publicación.
- **FR-016**: De los componentes restantes MUST deducirse el organismo emisor, y MUST poder usarse
  el prefijo del título como dato auxiliar cuando el título lo lleve.
- **FR-017**: Cada publicación MUST tener un identificador externo estable, obtenido del enlace
  cuando sea posible y, si no, de la dirección canónica o de una huella de su contenido, dejando
  constancia de cuál de los tres se usó.
- **FR-018**: El título MUST guardarse íntegro tal como se recibe, sin recortarlo ni completarlo.

**Almacenamiento y actualización**

- **FR-019**: Las publicaciones obtenidas MUST guardarse en el dispositivo, y lo guardado MUST ser
  la única procedencia de lo que la aplicación muestra.
- **FR-020**: Una publicación ya conocida que vuelve a aparecer MUST actualizarse, no duplicarse.
- **FR-021**: Las publicaciones guardadas MUST NOT borrarse por dejar de aparecer en la fuente
  oficial.
- **FR-022**: La aplicación MUST poder detectar que una fuente no ha cambiado desde la última
  consulta y evitar volver a procesarla.
- **FR-023**: La aplicación MUST sincronizar al abrirse cuando lo guardado tenga más de treinta
  minutos, y MUST NOT sincronizar si es más reciente.
- **FR-024**: La aplicación MUST ofrecer una actualización manual mediante el gesto de deslizar
  hacia abajo, que MUST poder lanzarse siempre, con independencia de la antigüedad de lo guardado.
- **FR-025**: Una actualización en curso MUST NOT poder duplicarse lanzando otra.
- **FR-026**: Durante una actualización el contenido ya visible MUST permanecer en pantalla.
- **FR-027**: Si toda la sincronización falla pero hay contenido guardado, la aplicación MUST
  mostrarlo e indicar que no hay conexión. Si falla y no hay nada guardado, MUST mostrar un mensaje
  con la acción de reintentar.
- **FR-028**: El orden de las publicaciones MUST ser estable y no depender del orden en que
  responden las fuentes: fecha descendente y, a igualdad de fecha, un criterio de desempate
  determinista.
- **FR-029**: La aplicación MUST NOT registrar datos personales identificables en la telemetría de
  la sincronización.

**Pantalla de Inicio**

- **FR-030**: Inicio MUST componerse, de arriba abajo, de barra superior clara, cabecera editorial,
  filtros rápidos, listado de publicaciones y barra de navegación inferior.
- **FR-031**: La barra superior MUST llevar, en el lado inicial, el control que abre el panel de
  secciones, seguido del escudo oficial y del nombre de la aplicación; y en el lado final, la
  acción de buscar y la de información. MUST NOT llevar campana de avisos.
- **FR-032**: La cabecera editorial MUST mostrar la denominación de lo que se está viendo, su fecha
  en formato legible en español y un distintivo perfilado con el número de publicaciones.
- **FR-033**: La fecha de la cabecera MUST ir acompañada de un rótulo que diga qué fecha es,
  redactado en español, sin tecnicismos y sin códigos.
- **FR-034**: Ese rótulo MUST distinguir los dos significados que la fecha tiene: con el boletín del
  día, la fecha de la edición publicada; con una sección o subsección, la de su publicación más
  reciente.
- **FR-035**: Cuando no haya fecha que mostrar, la cabecera MUST NOT mostrar el rótulo.
- **FR-036**: La cabecera MUST NOT mostrar un número de boletín: el servicio oficial no lo publica
  en las fuentes que la aplicación consume, y escribirlo sería presentar un dato inventado como
  oficial.
- **FR-037**: Cuando la selección es el boletín del día, el listado MUST mostrar las publicaciones
  de la fecha más reciente disponible entre todas las secciones.
- **FR-038**: Cuando la selección es una sección o subsección, el listado MUST mostrar las
  publicaciones de esa sección **sin restringirlas a una fecha**, y la cabecera MUST nombrarla.
- **FR-039**: Cada publicación MUST presentarse en una tarjeta que muestre, en este orden, el
  organismo emisor, el título, la fecha con su icono, y las acciones secundarias; con un indicador
  vertical del color de su sección.
- **FR-040**: El indicador de sección MUST ir siempre acompañado de texto, para no depender del
  color como único portador de significado.
- **FR-041**: Durante la primera carga sin contenido guardado, el listado MUST mostrar marcadores
  con la forma del contenido final, en número reducido, en lugar de un indicador giratorio grande.
- **FR-042**: El listado MUST distinguir visualmente «no hay publicaciones» de «se ha producido un
  error», y el estado vacío MUST ofrecer un mensaje propio.
- **FR-043**: La falta de conexión MUST comunicarse mediante un aviso que no oculte el contenido.
- **FR-044**: El listado MUST conservar la posición de lectura cuando cambie el tamaño de letra del
  sistema.

**Filtros rápidos: las dos filas**

- **FR-045**: La fila de secciones MUST desplazarse horizontalmente, MUST reflejar la selección
  vigente y MUST incluir como primera opción la que devuelve al boletín del día.
- **FR-046**: Esa primera opción MUST nombrar el boletín del día y MUST NOT sugerir que muestra
  todas las publicaciones guardadas, porque muestra la última edición publicada y no el archivo
  entero.
- **FR-047**: Al seleccionarse una sección que tiene subsecciones, la pantalla MUST mostrar una
  segunda fila con ellas, debajo de la de secciones.
- **FR-048**: Esa segunda fila MUST incluir una entrada que devuelva a la sección completa.
- **FR-049**: Tocar el chip de una sección con subsecciones MUST mostrar la sección completa **y**
  desplegar la segunda fila, en un solo toque.
- **FR-050**: La segunda fila MUST reflejar cuál es la selección vigente: la subsección elegida, o
  la sección completa.
- **FR-051**: La fila de secciones MUST seguir marcando la sección padre mientras haya una
  subsección elegida.
- **FR-052**: La segunda fila MUST NOT mostrarse cuando la selección sea el boletín del día ni
  cuando la sección elegida no tenga subsecciones.
- **FR-053**: La segunda fila MUST aparecer también cuando se llegue a una subsección desde el
  panel de secciones.
- **FR-054**: La segunda fila MUST distinguirse visualmente de la primera, de modo que se lea como
  subordinada a ella y no como una segunda lista de iguales.
- **FR-055**: Elegir una subsección desde los chips MUST llevar exactamente al mismo resultado que
  elegirla desde el panel.
- **FR-056**: Ambas filas MUST desplazarse horizontalmente y MUST NOT provocar desplazamiento
  horizontal del resto de la pantalla.

**Panel de secciones**

- **FR-057**: El panel MUST entrar desde el borde inicial de la pantalla, por encima del contenido,
  con un velo que atenúe lo que queda detrás.
- **FR-058**: El panel MUST presentar las nueve secciones principales del BOC con su número y su
  nombre, en el orden oficial.
- **FR-059**: Las secciones con subsecciones MUST poder desplegarse y contraerse, mostrando sus
  subsecciones agrupadas y visualmente subordinadas.
- **FR-060**: El panel MUST mostrar como primer elemento una cabecera con el escudo oficial y el
  nombre de la aplicación.
- **FR-061**: Esa cabecera MUST incluir, al final de la fila, un control que recoja el panel, con
  una flecha del mismo tipo que la de volver atrás, para que la dirección del icono coincida con la
  del movimiento.
- **FR-062**: Accionar ese control MUST recoger el panel, MUST NOT navegar a ninguna parte y MUST
  NOT alterar la selección. El control MUST tener descripción para lectores de pantalla.
- **FR-063**: El panel MUST NOT ofrecer campo de búsqueda ni filtrado de la lista de secciones.
- **FR-064**: El panel MUST poder cerrarse además deslizándolo hacia el borde y tocando fuera de
  él.
- **FR-065**: Elegir una sección o subsección MUST cerrar el panel y aplicar la selección al
  listado.
- **FR-066**: El panel MUST poder recorrerse por completo, cabecera incluida, con todas las
  secciones desplegadas.
- **FR-067**: El panel MUST NOT contener campanas de aviso ni tarjeta de alertas: las
  notificaciones quedan fuera del alcance de esta feature.
- **FR-068**: La selección vigente MUST sobrevivir a la terminación del proceso por parte del
  sistema operativo, y MUST restaurarse por su nombre, de modo que una selección guardada que ya no
  exista no deje la pantalla inservible.

**Marco de navegación y acciones aplazadas**

- **FR-069**: La barra inferior MUST ofrecer exactamente tres destinos: Inicio, Buscar y Guardados.
  MUST NOT incluir el destino de Avisos.
- **FR-070**: La barra inferior MUST indicar cuál es el destino activo mediante forma o peso,
  además del color.
- **FR-071**: Buscar y Guardados MUST ser destinos reales que muestren, con el aspecto de la
  aplicación, que la funcionalidad llegará próximamente.
- **FR-072**: El panel de secciones MUST envolver los tres destinos, y MUST NOT alcanzar a la
  pantalla de arranque.
- **FR-073**: La acción de buscar de la barra superior MUST informar de que la búsqueda llegará
  próximamente.
- **FR-074**: La acción de información de la barra superior MUST estar presente y MUST NOT realizar
  ninguna acción todavía.
- **FR-075**: La acción de compartir de una tarjeta MUST ofrecer las formas habituales del sistema
  para compartir el enlace del documento oficial.
- **FR-076**: La acción de guardar de una tarjeta MUST informar de que llegará próximamente.
- **FR-077**: Pulsar una tarjeta MUST NOT navegar a ningún sitio en esta feature; el detalle de la
  publicación corresponde a la siguiente.
- **FR-078**: El gesto de volver desde Inicio MUST NOT hacer reaparecer la pantalla de arranque.

**Identidad visual**

- **FR-079**: Todo lo que esta feature dibuja MUST usar exclusivamente los valores con nombre del
  sistema de diseño ya implantado: ningún color, tamaño ni espaciado escrito directamente en el
  punto de uso.
- **FR-080**: La aplicación MUST conservar su aspecto único, sin depender del ajuste de tema del
  sistema operativo ni de la personalización cromática del dispositivo.
- **FR-081**: Las desviaciones respecto al documento de diseño acordado MUST quedar registradas en
  el propio documento, con su fecha y su motivo, para que documento y aplicación no se contradigan.

**Verificación**

- **FR-082**: El procesamiento del contenido de las fuentes MUST tener pruebas automáticas que se
  ejecuten sin dispositivo y sin red, cubriendo al menos: fuente vacía, recuento declarado
  incorrecto, campos desconocidos, definición de tipo de documento, entidad externa, clasificación
  ausente, clasificación con tres, cuatro y cinco componentes, tipo de edición al principio, en
  medio y al final, tipo de edición ausente, clasificación que no corresponde a la fuente, orden
  anómalo, fecha inválida, enlace sin identificador y título muy largo.
- **FR-083**: El comportamiento de sincronización MUST tener pruebas automáticas que cubran primera
  obtención, segunda sin cambios, publicación nueva, publicación actualizada, publicación que sale
  de la ventana de la fuente, una fuente que falla, todas las fuentes que fallan con y sin
  contenido guardado, y duplicados.
- **FR-084**: MUST existir una prueba automática que demuestre que ninguna operación de
  almacenamiento borra publicaciones guardadas.
- **FR-085**: Cada modelo de pantalla que introduzca esta feature MUST tener pruebas automáticas
  sin dispositivo.
- **FR-086**: MUST existir pruebas automáticas de interfaz que validen los estados del listado
  —cargando, con contenido, vacío, error y sin conexión—, la composición de la tarjeta, las dos
  filas de filtros, la apertura, el recorrido y el cierre del panel de secciones, y la navegación
  entre los tres destinos.
- **FR-087**: Las pruebas MUST ser deterministas: sin red real, sin reloj del sistema, sin depender
  del idioma configurado en el dispositivo y sin depender del orden de ejecución.
- **FR-088**: La frontera con el servicio oficial MUST atravesarse de verdad al menos una vez antes
  de dar la feature por terminada, dejando registradas las cifras obtenidas: fuentes que
  respondieron, publicaciones aceptadas, publicaciones rechazadas con su motivo, publicaciones con
  advertencia e identificadores repetidos.

### Key Entities

- **Publicación**: un anuncio del BOC. Guarda su identificador externo y de dónde salió, la fuente
  de la que se obtuvo, su sección y subsección, el título recibido íntegro, el organismo emisor y su
  ruta jerárquica, el tipo de edición, la fecha de publicación, el enlace al documento oficial, la
  clasificación original sin modificar, y las advertencias que se detectaron al normalizarla.
- **Sección del BOC**: una de las nueve categorías oficiales, con su código, su nombre completo, su
  nombre corto para el chip, su orden de presentación, su grupo cromático y, cuando las tiene, sus
  subsecciones. Las secciones 2, 4, 7 y 8 no tienen fuente propia: su contenido es la suma del de
  sus subsecciones.
- **Fuente del boletín**: cada una de las diecinueve procedencias oficiales, con su identificador,
  la sección y subsección que representa de forma autoritativa, su orden y si está activa.
- **Estado de sincronización de una fuente**: cuándo se consultó por última vez, una huella del
  contenido que devolvió para saber si ha cambiado, y cuántos fallos consecutivos acumula.
- **Selección de Inicio**: lo que la pantalla está mostrando en un instante dado. Es el boletín del
  día, una sección completa o una subsección. Determina el listado, el texto y el rótulo de la
  cabecera, y si hay segunda fila de chips.
- **Resumen de sincronización**: el resultado de una actualización —fuentes consultadas con éxito,
  fuentes sin cambios, fuentes fallidas, publicaciones nuevas, actualizadas y rechazadas—, que es lo
  que permite decidir si mostrar contenido, aviso de falta de conexión o mensaje de error.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Con contenido ya guardado, la persona ve publicaciones en Inicio en **menos de 1
  segundo** desde que la pantalla aparece, con y sin conexión. El tiempo se mide, no se estima.
- **SC-002**: En una instalación limpia con conexión, la persona ve el boletín del día en **menos de
  15 segundos** desde que abre la aplicación.
- **SC-003**: Sin conexión, la persona accede a todo el contenido consultado con anterioridad sin
  encontrar en ningún momento una pantalla vacía o un error irrecuperable.
- **SC-004**: Ninguna publicación aparece duplicada tras **cinco sincronizaciones consecutivas**.
- **SC-005**: Ninguna publicación guardada desaparece por dejar de figurar en la fuente oficial. Se
  verifica de forma mecánica.
- **SC-006**: Las **diecinueve** fuentes oficiales están configuradas y las **nueve** secciones con
  sus **catorce** subsecciones se ofrecen para su consulta.
- **SC-007**: Las anomalías conocidas del servicio —una fuente vacía, una fuente sin publicaciones
  recientes, clasificaciones desordenadas— no producen ningún mensaje de error y no descartan
  ninguna publicación válida. Se verifica de forma mecánica con muestras reales conservadas.
- **SC-008**: Desde Inicio, la persona alcanza cualquiera de las nueve secciones o de sus
  subsecciones en **tres toques como máximo**.
- **SC-009**: Ninguna acción visible deja a la persona sin respuesta: toda acción todavía no
  disponible lo comunica de forma explícita.
- **SC-010**: La pantalla conserva su jerarquía y no recorta el organismo, el título ni la fecha con
  el tamaño de letra del sistema al **200 %**.
- **SC-011**: La fecha de la cabecera nunca aparece sin rótulo cuando hay fecha, y nunca aparece un
  rótulo sin fecha.
- **SC-012**: Toda pieza de reglas de negocio y todo modelo de pantalla que introduce esta feature
  tiene su prueba automática. Se verifica de forma mecánica: una comprobación automatizada falla si
  alguno carece de fichero de prueba asociado.
- **SC-013**: El contraste contra el servicio oficial se ejecuta y sus cifras quedan escritas: qué
  fuentes respondieron, cuántas publicaciones se aceptaron y cuántas se rechazaron.
- **SC-014**: Las **cuatro comprobaciones de calidad** del proyecto terminan en verde: construcción,
  pruebas sin interfaz, pruebas de interfaz y ausencia de avisos nuevos.

## Assumptions

- **No hay servicio propio intermedio.** El documento de consumo de feeds recomienda un servidor
  central que agregue las fuentes, y califica la lectura directa desde el teléfono de solución de
  respaldo. Hoy ese servidor no existe, y se acuerda con el propietario que la aplicación lea las
  fuentes oficiales por su cuenta. Las consecuencias se aceptan a conciencia: no hay histórico más
  allá de lo que cada fuente publica, no hay avisos inmediatos, se genera más tráfico y una
  reinstalación empieza sin contenido. La frontera se coloca de forma que sustituir la procedencia
  por un servicio propio no obligue a rehacer ni la pantalla ni las reglas de negocio.
- **Las decisiones técnicas se justifican en el plan.** Cómo se persiste, cómo se pide por red, cómo
  se analiza el contenido, cómo se observa lo guardado y cómo se conserva la selección son
  **materia de `plan.md` y de `research.md`**. Esta especificación describe qué debe ocurrir y por
  qué. La constitución dejó abiertas persistencia y red hasta la primera feature que las necesitara,
  y ésta lo es.
- **El almacenamiento local es la única procedencia de lo que se muestra.** La pantalla nunca lee de
  la red directamente: observa lo guardado, y la sincronización solo escribe.
- **Las notificaciones quedan fuera por completo.** El documento de diseño incluye campanas de aviso
  y una tarjeta de alertas personalizadas; se ignoran a propósito. Llegarán con su feature, y
  entonces la barra inferior recuperará su cuarto destino.
- **El detalle de la publicación es la feature siguiente.** Aquí la tarjeta no navega. Tampoco se
  descarga ni se valida el documento en PDF: se conserva su enlace, nada más.
- **Buscar y Guardados son marcadores de posición.** Existen como destinos para que la estructura de
  navegación quede fijada, pero su contenido llegará en features posteriores. La lupa de la barra
  superior dice «Próximamente» y **no** es todavía un filtro de la lista: ese control llegará con la
  pantalla Buscar.
- **La ventana de treinta minutos** para considerar caducado lo guardado es un valor de partida
  razonable para un boletín que se publica una vez al día. Se elige por prudencia con el servicio
  oficial y podrá ajustarse con datos de uso.
- **El documento de diseño manda en lo visual**, y las desviaciones se anotan en él en el mismo
  cambio, como se hizo en la feature anterior con el apartado de modo oscuro. Son tres: tres
  destinos en la barra inferior en lugar de cuatro mientras no existan los avisos, la tarjeta de
  alertas del panel en suspenso, y el recuento de anuncios donde el diseño original ponía un número
  de boletín. Se aprovecha además para corregir dos apartados del documento que quedaron
  desactualizados por sus propias enmiendas y que hoy contradicen a las demás.
- **Los textos visibles están en español** y son los mismos que en Android; las fechas se muestran
  en formato largo español, con independencia del idioma configurado en el dispositivo.
- **Los colores de sección** del documento de diseño agrupan más de lo que agrupa el BOC: hay cinco
  colores para nueve secciones. Se asigna cada sección al grupo cromático que le corresponde
  conceptualmente y se acompaña siempre de texto, de modo que la agrupación no reste información.
- **La escala de la primera sincronización** ronda las mil novecientas publicaciones, porque la
  mayoría de fuentes devuelve un máximo de cien. Las sincronizaciones siguientes son incrementales.
- **La rodaja vertical de relleno de la feature 001 se retira**, no se conserva al lado: sus modelos,
  sus orígenes de datos, su repositorio, su caso de uso y la costura que las pruebas de interfaz
  usaban para elegir escenario desaparecen al llegar la cadena real.

### Procedencia

- **Se reutilizan íntegros, por su motivo**, los requisitos de producto de la feature Android
  `003-boletin-del-dia`: los de obtención, normalización, almacenamiento, la anatomía de la
  pantalla, el panel, el armazón de navegación, la identidad visual y la verificación.
- **Se incorporan de la feature Android `013-inicio-secciones-y-panel`**, por decisión del
  propietario, sus requisitos sobre los chips, el rótulo de la fecha y el panel: FR-033 a FR-035,
  FR-046 a FR-055 y FR-060 a FR-063. Allí fueron una corrección posterior; aquí se llega
  directamente al estado final, que es además el que el documento de diseño describe hoy. **La
  feature 013 desaparece del orden de portado** y el motivo se anota en la guía operativa.
- **No se trae de la 013** su bloque sobre el filtro rápido dentro de la lista. Ese control nació
  con la pantalla Buscar de Android; aquí la lupa dice «Próximamente» y su redacción se decidirá
  cuando Buscar exista.
- **Se retraducen** los dos requisitos que en Android hablaban de mecanismo de plataforma: el que
  pedía sobrevivir a un «cambio de configuración» es aquí FR-044, sobre el tamaño de letra, y el que
  pedía sobrevivir a la «destrucción y recreación de la pantalla» es FR-068, sobre la terminación
  del proceso, con la exigencia añadida de restaurar por nombre.
- **Se añaden**: FR-056 y FR-057, sobre el desplazamiento de las filas y la entrada del panel, que
  en Android los ponía el componente del sistema y aquí hay que construir; FR-064, sobre los gestos
  de cierre, por la misma razón; FR-072, que fija que el panel envuelve los tres destinos pero no la
  portada; FR-084, la prueba de que nada borra publicaciones; FR-088, el contraste contra el
  servicio real, que en Android estaba en el protocolo de verificación y aquí se eleva a requisito
  porque es lo único que mira al otro lado de la frontera; y la mención al idioma en FR-087, porque
  ni el esquema ni los planes de prueba de este proyecto lo fijan.
