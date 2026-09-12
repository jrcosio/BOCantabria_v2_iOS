# Feature Specification: Del titular al documento oficial

**Feature Branch**: `005-detalle-y-documento`

**Created**: 12 de septiembre de 2026

**Status**: Draft

**Input**: User description: «Detalle de publicación, descarga validada del PDF oficial y visor. Port de
la feature `004-detalle-publicacion` de Android. Pulsar una tarjeta abre el detalle; el documento
oficial se obtiene validado y se lee dentro de la aplicación; compartir entrega el PDF, también desde
la tarjeta. Resumen IA, Preguntar y Guardar dicen que llegarán. Cuatro decisiones ya tomadas con el
propietario el 12 de septiembre de 2026: la cabecera del detalle se desplaza con las pestañas fijas;
el orden es sección, título, organismo, fecha; compartir el PDF alcanza a la tarjeta; y entra el
alcance completo.»

Esta es la feature que da sentido a las cuatro anteriores. Hasta aquí la aplicación enseña
**titulares**: dice que existe un anuncio, de qué sección es y quién lo firma, y ahí se acaba. Lo que
la persona ha venido a hacer —**leer el boletín**— empieza en esta pantalla.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Abrir una publicación y leer el documento oficial (Priority: P1)

Una persona ve en el boletín un anuncio que le interesa y lo toca. Se abre una pantalla que le dice
de un vistazo de qué sección es, cuál es el título **completo** —sin recortar—, qué organismo lo
firma y cuándo se publicó, con un distintivo que deja claro que aquello es un documento oficial.
Debajo tiene la ficha del anuncio y el principio del documento. Toca «Abrir PDF oficial» y el
documento se abre **dentro de la aplicación**: lo lee, amplía lo que no ve bien y se desplaza por las
páginas. Al volver, sigue en el mismo punto del boletín donde estaba.

**Why this priority**: es la razón por la que existe la feature y el remate de todo lo anterior. Sin
esto, la persona tiene que salir al navegador, que es exactamente lo que la aplicación viene a
evitar.

**Independent Test**: abrir el boletín, tocar cualquier tarjeta y comprobar que se llega al detalle
con sus datos, y que desde ahí el documento oficial se lee dentro de la aplicación.

**Acceptance Scenarios**:

1. **Given** el boletín en pantalla, **When** la persona toca una tarjeta, **Then** llega al detalle
   de esa publicación con su sección, su título completo, su organismo, su fecha y el distintivo de
   documento oficial.
2. **Given** un título muy largo, **When** se muestra en el detalle, **Then** se ve **entero**, sin
   recortarse ni terminar en puntos suspensivos.
3. **Given** el detalle a la vista, **When** la persona desplaza el contenido, **Then** la cabecera
   del documento **se va con él** y las pestañas **se quedan** bajo la barra superior, de modo que el
   contenido acaba disponiendo de la pantalla entera.
4. **Given** el detalle a la vista, **When** la persona abre el documento oficial, **Then** el
   documento se muestra dentro de la aplicación y puede ampliarse y recorrerse.
5. **Given** el documento abierto, **When** la persona retrocede dos veces, **Then** vuelve al
   boletín en la misma posición de lectura y con la misma sección seleccionada.
6. **Given** un documento ya consultado antes, **When** la persona vuelve a abrirlo, **Then** aparece
   de inmediato, sin volver a descargarse.
7. **Given** el detalle a la vista, **When** la persona mira la parte inferior de la pantalla,
   **Then** **no** hay barra de pestañas de la aplicación: hay una barra de acciones propia, por
   encima del área reservada del sistema.

---

### User Story 2 - Que el documento sea de fiar, y que fallar se note (Priority: P1)

La misma persona abre un anuncio cuyo enlace, ese día, no devuelve el documento: el servicio responde
con una página de error, o la conexión se cae a medias. En lugar de ver un visor en blanco, un
documento ilegible o —peor— algo que no es el anuncio, recibe un mensaje claro y puede reintentar.
Nada roto queda guardado para la próxima vez.

**Why this priority**: es tan crítica como la historia 1 porque decide si lo que la persona lee es el
documento oficial o cualquier otra cosa. Una aplicación que consulta un boletín oficial no puede
presentar como oficial algo que no ha comprobado que lo sea.

**Independent Test**: apuntar la aplicación a un enlace que devuelva algo que no sea el documento y
comprobar que da un error comprensible con reintento, y que no deja nada guardado.

**Acceptance Scenarios**:

1. **Given** un enlace que responde correctamente pero **no** devuelve el documento esperado, **When**
   la persona intenta abrirlo, **Then** ve un mensaje comprensible con la acción de reintentar, y no
   se le presenta ningún contenido como si fuera oficial.
2. **Given** una descarga que se interrumpe a medias, **When** la persona lo intenta de nuevo,
   **Then** la descarga se rehace desde el principio y **no** queda un documento incompleto guardado.
3. **Given** un documento desmesuradamente grande, **When** se intenta abrir, **Then** la descarga se
   detiene y se informa, en lugar de agotar la memoria del dispositivo.
4. **Given** el dispositivo sin conexión y el documento nunca consultado, **When** la persona intenta
   abrirlo, **Then** se le explica que hace falta conexión y se le ofrece reintentar.
5. **Given** el dispositivo sin conexión pero el documento ya consultado antes, **When** la persona lo
   abre, **Then** lo lee con normalidad.
6. **Given** un fallo inesperado al guardar el documento —el almacenamiento lleno, por ejemplo—,
   **When** ocurre, **Then** la pantalla muestra el error con reintento y **no** se queda cargando
   indefinidamente.
7. **Given** una descarga en curso, **When** la persona abandona la pantalla, **Then** la descarga se
   cancela, el documento queda como **no descargado** —nunca como «descargando»— y **no** se registra
   como un fallo.
8. **Given** una copia local cuya huella de verificación esté ausente, vacía o incompleta, **When** la
   persona abre esa publicación, **Then** el documento se muestra con normalidad y la aplicación **no
   se cierra**.

---

### User Story 3 - Compartir el documento, no el enlace (Priority: P2)

La persona quiere mandarle el anuncio a alguien. Toca compartir —da igual si desde la tarjeta del
boletín, desde el detalle o desde el propio visor— y lo que se envía es **el documento**, no una
dirección que la otra persona tendrá que abrir. Si el documento aún no se ha descargado, la
aplicación lo trae mientras se lo dice, y luego lo comparte. Y si no hay forma de traerlo porque no
hay cobertura, se le ofrece compartir el enlace **explicándole por qué**, en lugar de dejarla sin
nada.

**Why this priority**: es la petición explícita del propietario y cambia lo que hacen hoy la tarjeta y
el boletín, que comparten el enlace. Va después de las dos primeras porque necesita que la descarga y
la validación existan.

**Independent Test**: compartir desde las tres pantallas y comprobar que lo que sale es el documento;
repetirlo sin conexión y sin haberlo abierto antes, y comprobar que ofrece el enlace con su
explicación.

**Acceptance Scenarios**:

1. **Given** un documento ya consultado, **When** la persona comparte, **Then** se ofrece **el
   documento** a las aplicaciones del sistema, de inmediato.
2. **Given** un documento no consultado y con conexión, **When** la persona comparte, **Then** se le
   indica que se está preparando y a continuación se ofrece el documento.
3. **Given** un documento no consultado y sin conexión, **When** la persona comparte, **Then** se le
   ofrece compartir el enlace al documento oficial, explicándole por qué.
4. **Given** cualquiera de los casos anteriores, **When** se comparte desde la tarjeta del boletín,
   **Then** ocurre lo mismo que al compartir desde el detalle.
5. **Given** cualquiera de los casos anteriores, **When** se comparte, **Then** la aplicación que
   recibe puede abrir lo compartido sin permisos adicionales, con un nombre de fichero legible, y sin
   que se le exponga nada más que ese documento.

---

### User Story 4 - Saber qué llegará y no toparse con callejones (Priority: P3)

La persona ve dos pestañas —Documento y Resumen IA— y, abajo, un botón para preguntar sobre el
anuncio que abre su propia pantalla. La pestaña de resumen, la pantalla de preguntar y el botón de
guardar todavía no hacen su trabajo, pero lo dicen con claridad y conservan su aspecto, de modo que se
entiende que llegarán y no que están rotas.

**Why this priority**: no aporta valor por sí misma, pero deja fijada la estructura de la pantalla
para las features siguientes y evita que la aplicación se perciba como incompleta.

**Independent Test**: recorrer las dos pestañas y las dos acciones aplazadas comprobando que ninguna
deja a la persona sin respuesta.

**Acceptance Scenarios**:

1. **Given** el detalle a la vista, **When** la persona abre la pestaña de resumen, **Then** ve que
   esa función llegará próximamente, con el icono y la etiqueta que identifican el contenido de
   inteligencia artificial.
2. **Given** el detalle a la vista, **When** la persona usa el botón de preguntar de la barra
   inferior, **Then** se abre una **pantalla propia**, con su sitio en la pila de retroceso, que dice
   lo mismo.
3. **Given** el detalle a la vista, **When** la persona usa la acción de guardar, **Then** se le
   informa de que llegará próximamente.
4. **Given** cualquiera de las anteriores, **When** ocurre, **Then** la acción de abrir el documento
   sigue siendo la más destacada de la pantalla.

---

### Edge Cases

- **Publicación que ya no está guardada**: se llega al detalle de un anuncio que una limpieza de datos
  ha retirado. Debe explicarse y ofrecer volver, no mostrarse una pantalla vacía.
- **Publicación corregida mientras se mira**: una sincronización cambia el título de la publicación
  abierta. El detalle lo refleja sin salir y volver a entrar.
- **Documento de una sola página**: la previsualización y el visor se comportan igual que con uno de
  cincuenta.
- **Documento con muchas páginas**: recorrerlo no puede agotar la memoria ni bloquear la interfaz.
- **Documento protegido con contraseña**: se explica y se ofrece salir. **Es un caso distinto** del
  ilegible, y no se confunden.
- **Documento ilegible o truncado**: el visor no puede abrirlo. Se explica y se ofrece salir, nunca una
  pantalla en blanco.
- **Documento cifrado pero abrible**: hay PDF con restricciones de impresión o copia que se **leen
  perfectamente**. No se rechazan: rechazarlos sería mutilar documentos oficiales legítimos.
- **Dos aperturas seguidas del mismo documento**: no se lanzan dos descargas.
- **Dos pantallas esperando la misma descarga**: si quien la inició se va, la otra la recibe igualmente.
- **Salir mientras se descarga**: la descarga se cancela y no deja nada a medias ni un estado colgado.
- **Espacio de almacenamiento agotado**: se informa con reintento, en lugar de fallar de forma opaca.
- **Huella de verificación perdida o corrupta**: se trata igual que una ausente. El documento se sirve.
- **Publicación sin organismo**: la cabecera se compone igual, sin dejar hueco ni texto vacío.
- **Volver de segundo plano con el documento abierto**: no se pierde la página ni se vuelve a descargar.
- **Tamaño de letra del sistema al 200 %**: el título no se recorta y los botones de la barra de
  acciones se apilan.
- **La caché la vacía el sistema**: un documento que estaba disponible deja de estarlo. Se vuelve a
  descargar sin que la persona tenga que hacer nada raro.

## Requirements *(mandatory)*

### Functional Requirements

**Acceso al detalle**

- **FR-001**: Pulsar una tarjeta de publicación MUST llevar al detalle de esa publicación, desde
  cualquier listado que la muestre.
- **FR-002**: El detalle MUST identificar la publicación por su identificador estable y MUST obtener
  sus datos de lo que la aplicación tiene guardado, **no** de lo que le pase quien navega.
- **FR-003**: El detalle MUST reflejar los cambios que una sincronización posterior haga sobre esa
  publicación, sin salir y volver a entrar.
- **FR-004**: Si la publicación ya no existe entre lo guardado, el detalle MUST explicarlo y ofrecer
  volver al boletín. Que no exista **no** es un fallo: es un desenlace previsto.
- **FR-005**: El retroceso desde el detalle MUST devolver al listado de origen conservando su posición
  de lectura y su selección.
- **FR-006**: El detalle MUST NOT mostrar la barra de pestañas inferior de la aplicación: tiene su
  propia barra de acciones.

**Cabecera del documento**

- **FR-007**: La cabecera MUST presentar, en este orden: etiqueta de sección, **título**, organismo,
  fecha y distintivo de documento oficial.
- **FR-008**: El título MUST mostrarse **completo**, sin recortarlo, y MUST mostrarse **íntegro** —con
  el prefijo del organismo si lo trae—, a diferencia de la tarjeta del listado.
- **FR-009**: El organismo y la fecha MUST ir acompañados de un icono que los identifique.
- **FR-010**: Cuando la publicación no tenga organismo, la cabecera MUST componerse sin dejar hueco ni
  texto vacío.
- **FR-011**: La cabecera MUST desplazarse con el contenido, y las pestañas MUST permanecer fijas bajo
  la barra superior, de modo que un título largo no reduzca de forma permanente la zona de contenido.
- **FR-012**: La zona que permanece fija MUST distinguirse del contenido que pasa por debajo mediante
  un fondo sólido y un divisor, para que no se lean dos cosas superpuestas.
- **FR-013**: La barra superior MUST llevar retroceso, escudo, el título de la pantalla y las acciones
  de guardar y compartir.

**Pestañas**

- **FR-014**: El detalle MUST ofrecer **dos** pestañas: documento y resumen de inteligencia artificial.
- **FR-015**: La pestaña de documento MUST mostrar una ficha con los datos del anuncio —descripción,
  organismo, sección, fecha de publicación, referencia y documento oficial— y, debajo, la **primera
  página** del documento oficial como previsualización.
- **FR-016**: Obtener el documento MUST dispararse al **mostrarse la pestaña de documento**, no al
  abrir el detalle.
- **FR-017**: La pestaña seleccionada MUST sobrevivir a un ciclo de segundo plano y a la muerte del
  proceso, y MUST restaurarse **por nombre y con un valor de respaldo**: un valor guardado que ya no
  exista MUST NOT tumbar la pantalla.

**El documento oficial**

- **FR-018**: La aplicación MUST obtener el documento oficial desde el enlace que la publicación trae,
  y MUST rechazarlo si el enlace no usa un canal seguro o no apunta al servicio del boletín. La
  comprobación MUST hacerse **antes de conectar** y MUST repetirse sobre el destino **final**, si la
  petición fue redirigida.
- **FR-019**: La aplicación MUST comprobar, antes de dar por bueno un documento, que el servicio lo
  declara como documento portátil **y** que su contenido realmente lo es. Una respuesta correcta que
  contenga otra cosa MUST rechazarse.
- **FR-020**: La descarga MUST tener un límite de tamaño y MUST detenerse al superarlo, **contando
  mientras el contenido llega** y sin cargar la respuesta entera en memoria.
- **FR-021**: Una descarga interrumpida o rechazada MUST NOT dejar ningún documento guardado.
- **FR-022**: La aplicación MUST calcular y guardar una suma de verificación del documento obtenido.
- **FR-023**: La suma de verificación MUST escribirse de forma que nunca pueda quedar a medias junto a
  un documento ya visible: MUST escribirse **antes** que el documento, de modo que un documento
  visible implique siempre una suma válida.
- **FR-024**: Una suma de verificación ausente, vacía, incompleta o malformada MUST tratarse como
  **huella desconocida**, exactamente igual que una ausente: el documento MUST servirse igualmente,
  porque sus bytes ya se verificaron al descargarlos, y la aplicación MUST NOT cerrarse.
- **FR-025**: Un documento ya obtenido MUST reutilizarse sin volver a descargarlo.
- **FR-026**: Dos peticiones simultáneas del mismo documento MUST NOT producir dos descargas.
- **FR-027**: Abandonar la pantalla durante una descarga MUST cancelarla. La cancelación MUST NOT
  presentarse como error ni contarse como fallo, y el documento MUST quedar como **no descargado**,
  nunca como «descargando».
- **FR-028**: Si quien inició una descarga la abandona mientras otra pantalla la espera, la otra MUST
  obtener el documento igualmente.
- **FR-029**: **Todo** camino de error —rechazo, red, fallo inesperado al guardar y cancelación— MUST
  publicar un estado final observable por las pantallas, coherente con el resultado devuelto a quien
  pidió la descarga. Un fallo devuelto y no publicado deja las pantallas cargando para siempre.
- **FR-030**: Lo guardado es **caché**: la aplicación MUST poder liberar espacio retirando documentos
  por antigüedad de uso y por tope de tamaño, MUST NOT retirar el documento que se está usando, y
  MUST NOT presentarlo a la persona como una biblioteca de documentos guardados.

**Visor**

- **FR-031**: Abrir el documento oficial MUST mostrarlo **dentro de la aplicación**, sin delegar en
  otra aplicación ni en el navegador.
- **FR-032**: El visor MUST permitir ampliar y recorrer el documento con los gestos habituales, y MUST
  NOT permitir reducirlo por debajo del tamaño que lo hace legible.
- **FR-033**: El visor MUST ocupar una pantalla propia, con retroceso, el título abreviado del
  documento —el del anuncio **sin el organismo**— y la acción de compartir.
- **FR-034**: El visor MUST conservar la página visible ante un ciclo de segundo plano y ante la
  muerte del proceso, y MUST NOT volver a descargar el documento por ello.
- **FR-035**: Un documento que el visor no pueda abrir MUST producir un mensaje claro y una salida,
  nunca una pantalla en blanco.
- **FR-036**: Un documento **protegido con contraseña** y uno **ilegible** MUST distinguirse entre sí.
  Un documento con restricciones de impresión o copia que **sí** puede leerse MUST abrirse con
  normalidad.

**Compartir**

- **FR-037**: Compartir MUST ofrecer el **documento**, no su enlace, cuando el documento esté
  disponible o pueda obtenerse.
- **FR-038**: Compartir MUST comportarse igual desde el detalle, desde el visor y desde la tarjeta de
  cualquier listado.
- **FR-039**: Cuando el documento no esté disponible y haya que obtenerlo, la aplicación MUST indicar
  que lo está preparando.
- **FR-040**: Cuando el documento no pueda obtenerse **por falta de conexión**, la aplicación MUST
  ofrecer compartir el enlace, explicando por qué. Cualquier **otro** fallo MUST NOT disfrazarse de
  enlace: se informa como error.
- **FR-041**: La decisión entre documento y enlace MUST tomarse en un único sitio, y las pantallas MUST
  limitarse a obedecerla.
- **FR-042**: Lo compartido MUST poder abrirse por la aplicación que lo recibe sin exigirle permisos
  adicionales, MUST llevar un nombre de fichero legible y MUST NOT exponerle nada más que ese
  documento.

**Funciones aplazadas**

- **FR-043**: La pestaña de resumen MUST informar de que la función llegará próximamente, conservando
  el icono y la etiqueta que identifican el contenido de inteligencia artificial.
- **FR-044**: El botón de preguntar de la barra de acciones MUST abrir una **pantalla propia**, con su
  sitio en la pila de retroceso, que informa de que la función llegará próximamente.
- **FR-045**: La acción de guardar MUST informar de que llegará próximamente.
- **FR-046**: Abrir el documento oficial MUST ser la acción más destacada de la pantalla, y ninguna
  acción visible MUST quedarse sin respuesta.

**Identidad visual y accesibilidad**

- **FR-047**: Todo lo que esta feature dibuja MUST usar exclusivamente los valores con nombre del
  sistema de diseño: ningún color, tamaño ni espaciado escrito en el punto de uso.
- **FR-048**: El contenido de inteligencia artificial MUST distinguirse por icono y etiqueta, no solo
  por color.
- **FR-049**: Todos los controles MUST respetar un área táctil mínima de 44 puntos, y la barra de
  acciones MUST quedar por encima del área reservada del sistema.
- **FR-050**: Con el tamaño de letra del sistema al 200 %, el título MUST NOT recortarse y los botones
  de la barra de acciones MUST apilarse en lugar de solaparse.

**Lo que esta feature deja arreglado**

- **FR-051**: El modelo de pantalla de Inicio MUST construirse **una sola vez** por aparición de la
  pantalla, y su visita MUST registrarse **una sola vez**. Hoy se construye en cada redibujado del
  armazón, lo que registra visitas que nadie hizo; esta feature lo empeoraría, porque la pila de
  navegación del detalle redibuja el armazón en cada entrada y cada retroceso.
- **FR-052**: MUST existir una regla de arquitectura, verificada automáticamente, que impida nombrar
  el marco del visor de documentos fuera de la carpeta del visor. Sin ella, la exigencia de la
  constitución de que quede «encerrada tras una vista propia» no la comprueba nada.

**Verificación**

- **FR-053**: La obtención y la validación del documento MUST tener pruebas automáticas que se
  ejecuten sin dispositivo y sin red, cubriendo al menos: documento correcto; respuesta correcta cuyo
  contenido no es un documento portátil; tipo declarado inesperado; contenido cuyos primeros bytes no
  corresponden; tamaño por encima del límite; enlace que no usa canal seguro; enlace que no apunta al
  servicio del boletín; redirección a otro destino; y error del servicio.
- **FR-054**: El comportamiento de la caché MUST tener pruebas automáticas que cubran reutilización,
  no dejar restos tras un fallo, retirada por antigüedad y por tope, y **suma de verificación ausente,
  vacía y malformada**.
- **FR-055**: MUST existir una prueba automática que demuestre que **cada** camino de error publica un
  estado final, y otra que demuestre que dos peticiones simultáneas producen **una** sola descarga.
- **FR-056**: Cada modelo de pantalla que introduzca esta feature MUST tener pruebas automáticas sin
  dispositivo.
- **FR-057**: MUST existir pruebas automáticas de interfaz que validen la composición de la cabecera en
  su orden, que el título largo no se recorta, que la cabecera se desplaza mientras las pestañas se
  quedan, las dos pestañas con su contenido, la barra de acciones, los estados del visor y la
  navegación desde la tarjeta hasta el documento y hasta la pantalla de preguntar.
- **FR-058**: Las pruebas MUST ser deterministas: sin red real, sin reloj del sistema y sin depender
  del orden de ejecución.

### Key Entities

- **Documento oficial**: la copia local del documento de una publicación. Guarda a qué publicación
  pertenece, dónde está en el dispositivo, cuánto ocupa, su suma de verificación y cuándo se usó por
  última vez. Es contenido de caché: puede desaparecer sin que se pierda nada. **No guarda el enlace
  de origen**, que ya está en la publicación: duplicarlo sería crear una segunda verdad que puede
  quedarse atrás.
- **Estado del documento**: en qué punto está la copia local para una publicación —ausente,
  obteniéndose, disponible o fallida—. Es lo que el detalle, el visor y compartir observan para saber
  qué dibujar. Al obtenerse lleva cuánto se lleva traído y, **cuando el servicio lo declara**, cuánto
  falta: que el total pueda faltar es información, no un descuido.
- **Selección de pestaña**: cuál de **las dos** pestañas está activa. Sobrevive al segundo plano y a
  la muerte del proceso.
- **Destino de compartir**: qué se acabó ofreciendo —el documento o su enlace— y **por qué**. El
  motivo forma parte del dato: sin él, la pantalla no puede explicar el caso degradado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Desde cualquier listado, la persona llega al detalle de una publicación en **un solo
  toque**.
- **SC-002**: Un documento ya consultado se abre en **menos de 1 segundo**, sin red. El tiempo se
  **mide**, no se estima.
- **SC-003**: Un documento no consultado, con una conexión normal, se abre en **menos de 10 segundos**,
  informando durante la espera. También medido.
- **SC-004**: Ninguna respuesta que no sea el documento oficial llega a presentarse como tal. Se
  verifica de forma mecánica, con respuestas fabricadas para engañar.
- **SC-005**: Ninguna descarga fallida, rechazada, interrumpida o cancelada deja restos en el
  dispositivo. Se verifica de forma mecánica.
- **SC-006**: **Ninguna pantalla se queda cargando.** Todo desenlace de la obtención del documento
  termina en contenido o en un error con reintento, y se verifica de forma mecánica **para cada uno
  de los caminos**, incluido el fallo inesperado al guardar.
- **SC-007**: La aplicación **no se cierra** con una copia local dañada, sea cual sea la pantalla desde
  la que se llegue a ella. Se verifica de forma mecánica.
- **SC-008**: Recorrer un documento de cincuenta páginas no agota la memoria de un dispositivo de gama
  media ni bloquea la interfaz.
- **SC-009**: Compartir entrega el documento en todos los casos en que exista o pueda obtenerse; en los
  demás, ofrece el enlace con una explicación. **Nunca deja a la persona sin nada.**
- **SC-010**: El título de la publicación se lee completo en el detalle, también con el tamaño de letra
  del sistema al **200 %**, y las acciones conservan su área táctil.
- **SC-011**: En el teléfono **más pequeño** que la aplicación soporta, la barra de acciones no tapa
  contenido ni queda bajo el área reservada del sistema, y sigue habiendo contenido legible y
  desplazable.
- **SC-012**: Ninguna acción visible deja a la persona sin respuesta: toda acción aplazada lo dice.
- **SC-013**: Toda pieza de reglas de negocio y todo modelo de pantalla que introduce esta feature
  tiene su prueba automática. Se verifica de forma mecánica.
- **SC-014**: La regla que encierra el marco del visor **se pone en rojo** cuando se viola a propósito.
  Una regla que no puede fallar no protege nada.
- **SC-015**: Las **cuatro comprobaciones de calidad** del proyecto terminan en verde: construcción,
  pruebas sin interfaz, pruebas de interfaz y ausencia de avisos nuevos. El resultado se anota con
  cifras, no con un «pasa».

## Assumptions

- **El enlace del anuncio devuelve el documento directamente.** Así lo documenta el fichero de consumo
  de fuentes y así se observó: no hay página intermedia. Si algún día la hubiera, la validación de
  contenido de FR-019 la detectaría y la rechazaría, que es el comportamiento correcto.
- **Lo descargado es caché, no biblioteca.** Guardar publicaciones para consultarlas sin conexión es la
  funcionalidad de Guardados, que es futura. Meterla aquí sería adelantar una decisión que no toca.
- **La previsualización de la primera página obliga a obtener el documento.** Se obtiene al entrar en
  la pestaña de documento, no al abrir el detalle, para no gastar los datos de quien solo quería ojear
  un anuncio.
- **El límite de tamaño de la descarga se fija en 25 MB y el presupuesto de la caché en 100 MiB.** Son
  las cifras que la aplicación de origen usó y midió, y valen como punto de partida razonable; son
  decisión de producto y se pueden revisar antes de planificar sin que cambie ningún requisito.
- **El resumen de inteligencia artificial y la conversación quedan fuera.** Aquí solo se reserva su
  sitio en la interfaz. Tampoco entra buscar dentro del documento, ni el menú de más opciones del
  visor.
- **El texto del documento no se extrae.** La aplicación muestra el documento, no lo convierte a texto.
  El modo lectura que describe el documento de diseño queda para cuando exista esa extracción.
- **La versión mínima del sistema no se toca y la constitución no se enmienda.** Es la diferencia de
  plataforma más grande de esta feature y está explicada abajo, en *Procedencia*.
- **Los textos visibles están en español** y son los mismos que en la aplicación de origen; las fechas
  se muestran en formato largo español.
- **Compartir cambia respecto a lo que la aplicación hace hoy**, que envía el enlace desde la tarjeta.
  Es un cambio pedido explícitamente por el propietario.
- **Cómo se desplaza la cabecera, cómo se encierra el marco del visor y cómo se coalescen dos
  descargas son materia del plan.** Esta especificación describe qué debe ocurrir y por qué; el
  mecanismo se decide y se argumenta en `plan.md` y en `research.md`.

### Procedencia

- **Porta la feature `004-detalle-publicacion` de Android**, conservada íntegra en
  `docs/referencia-android/specs/`. Sus requisitos funcionales se reutilizan porque son de producto;
  el `plan.md`, el `research.md` y el `tasks.md` se escriben para iOS. **La numeración es nueva**: la
  de origen es irregular —FR-049 y FR-050 aparecen intercalados entre FR-037 y FR-038— y arrastrarla
  habría sido copiar un accidente.

- **No se porta el requisito de subir la versión mínima del sistema** (FR-039 y FR-040 de origen), y es
  la divergencia de plataforma más grande de esta feature. Allí el salto de versión mínima lo pagaba
  el visor de documentos del marco de interfaz, que no estaba disponible por debajo; **aquí el visor
  es parte del sistema operativo**. No hay dependencia nueva que añadir, no hay mecanismo de
  compatibilidad que retirar y **la constitución no se enmienda**. De rebote desaparece también el
  apartado de complejidad que allí justificaba una dependencia en fase beta.

- **Cierra las dos divergencias que el documento de diseño dejó aplazadas «a la 005»**, ambas nacidas
  de la feature 004 de este proyecto, que fue nativa y no portó nada:

  1. **La cabecera se desplaza** (FR-011), al revés que la de Inicio, que desde la 004 se queda y se
     compacta. Los dos motivos son buenos y opuestos, así que el porqué se escribe: en Inicio la
     cabecera dice **dónde estás** y perderla de vista era justamente el problema que la 004 vino a
     arreglar; en el detalle dice **qué es esto**, ya se ha leído, y un título del BOC sin recortar
     ocupa seis líneas — si se queda, el contenido vive en una franja estrecha para siempre.
  2. **El orden es sección, título, organismo** (FR-007), al revés que la tarjeta desde la 004. En un
     listado el organismo es lo que permite descartar sin leer; en el detalle ya se ha decidido leer,
     y el título **es** el contenido.

  Decididas con el propietario el 12 de septiembre de 2026, mirando las dos pantallas juntas, que es
  lo que el propio documento de diseño decía que había que hacer.

- **FR-008 corrige el sentido de FR-021 de la feature 004 (iOS) para esta pantalla.** Allí el título de
  la tarjeta omite el prefijo del organismo **al pintarlo**, porque la línea de encima ya lo dice y
  repetirlo rompía la jerarquía. En el detalle el título va **íntegro**: es el documento, no un
  resumen, y aquí el organismo va **debajo**. Las dos reglas son la misma decisión —no repetir— vista
  desde dos composiciones distintas, y ninguna toca lo almacenado.

- **Compartir el documento alcanza también a la tarjeta** (FR-038), decisión del propietario del 12 de
  septiembre de 2026. En la aplicación de origen el compartir por enlace de la tarjeta se retiró en
  esta misma feature; aquí se **sustituye**, para que la misma acción no haga dos cosas distintas
  según dónde se pulse.

- **Dos hallazgos de la auditoría de la aplicación de origen entran aquí como requisitos, no como
  notas al pie.** No son deuda heredada: son la forma correcta de escribir esto desde el principio, y
  se recogen porque el mecanismo que los produjo sigue siendo posible en esta plataforma.
  - **STAB-001**, de severidad alta, es FR-023 y FR-024. Allí un fichero lateral de verificación
    **presente pero vacío o truncado** no era tratado como ausente, y **cerraba la aplicación** al
    abrir esa publicación, y otra vez en cada reintento. El orden de escritura importa porque la suma
    tiene consumidor: decide si un resumen guardado está obsoleto, y regenerarlo cuesta cuota.
  - **STAB-002** es FR-027, FR-028 y FR-029. Allí un fallo inesperado al guardar devolvía el error a
    quien lo pidió pero **no publicaba el estado**, y como las pantallas solo observan el estado, el
    detalle y el visor se quedaban en «cargando» para siempre, sin error y sin reintento.

- **Dos defectos de la aplicación de origen llegan aquí resueltos por construcción**, y se anotan para
  que no se pierda la razón: la validación del destino de una petición se hace sobre la dirección ya
  interpretada y se repite tras las redirecciones, así que un enlace con credenciales incrustadas no
  la puede engañar; y las llamadas de red de esta plataforma **se cancelan de verdad**, así que
  abandonar la pantalla detiene la descarga en lugar de dejarla viva hasta el límite de tiempo.

- **Un hallazgo de aquella auditoría queda explícitamente fuera**: el que describe que un documento
  visitado quedaba protegido de la retirada durante toda la vida del proceso. FR-030 exige que la
  retirada no toque el documento **en uso**, que es el invariante; afinar cuánto dura «en uso» es una
  optimización de consumo de almacenamiento, no un requisito de esta feature.

- **Se corrige una incoherencia heredada**: el modelo de datos de origen describía la selección de
  pestaña como «cuál de las **tres** pestañas está activa», residuo anterior a la enmienda que las
  dejó en dos. Aquí son dos, y FR-017 añade además cómo se restaura, que es la lección ya escrita
  sobre pestañas retiradas entre versiones.

- **FR-051 y FR-052 no vienen de Android: nacen aquí.** El primero es un defecto propio, encontrado al
  inventariar qué toca esta feature: el armazón construye el modelo de pantalla de Inicio dentro de su
  redibujado, y ese nacimiento registra una visita. No se ve en pantalla porque el estado conserva el
  primero; se ve en el panel de analítica. Entra aquí porque **esta feature lo empeoraría**: la pila de
  navegación del detalle redibuja el armazón en cada entrada y cada retroceso. El segundo es la regla
  de arquitectura que faltaba: la constitución exige que el marco del visor quede «encerrada tras una
  vista propia y no pueda filtrar tipos al resto de la aplicación», y hasta ahora nada lo comprobaba.
