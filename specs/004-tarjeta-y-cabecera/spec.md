# Feature Specification: La tarjeta se lee de un vistazo, y la cabecera no se va

**Feature Branch**: `004-tarjeta-y-cabecera`

**Created**: 12 de septiembre de 2026

**Status**: Draft

**Input**: User description: «Una mejora visual del listado de publicaciones, te adjunto una captura
de cómo lo quiero. La sección un poco más grande de tamaño. Justo debajo, el nombre de la entidad
que hace la publicación, más grande y en mayúsculas. Y debajo del nombre de la entidad, el título de
la publicación. Y la fecha un poco más grande, alineada con los iconos de guardar y de compartir. Y
el scroll de la Home solo tienen que ser las publicaciones: el título y los botones de secciones se
quedan fijos, es decir, solo hacen scroll las tarjetas de las publicaciones.»

Esta feature **no porta nada de Android**: nace de mirar la pantalla que la 003 dejó funcionando,
con publicaciones reales delante. Es la primera del proyecto que no tiene origen en la aplicación de
la que se porta, y por eso la tabla de orden de portado gana una fila y las demás corren un número.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber de qué va un anuncio sin leerlo entero (Priority: P1)

Una persona abre Inicio y recorre el boletín del día. En cada tarjeta encuentra, sin buscarlos y en
este orden, tres cosas de tamaño decreciente en importancia: de qué sección es, quién lo publica y
qué dice. Descarta la mitad de los anuncios sin llegar a leer el título, porque le basta con ver el
organismo. Y mientras baja por la lista sigue viendo, arriba, qué está mirando y cuántos anuncios
tiene delante: la cabecera y los filtros no se van con el desplazamiento.

**Why this priority**: es la única historia de la feature. Lo que se corrige es que la pantalla, tal
como quedó, obliga a leerlo todo para decidir si algo interesa, y a subir del todo para saber dónde
se está.

**Independent Test**: abrir Inicio con publicaciones a la vista, comprobar que los cuatro datos de
la tarjeta se distinguen por tamaño, y desplazar el listado comprobando que la cabecera y los
filtros siguen ahí.

**Acceptance Scenarios**:

1. **Given** una tarjeta a la vista, **When** la persona la mira, **Then** distingue por tamaño la
   sección, el organismo y el título, en ese orden creciente de peso visual, sin tener que leerlos.
2. **Given** una tarjeta a la vista, **When** la persona busca quién publica, **Then** lo encuentra
   en mayúsculas, justo encima del título.
3. **Given** una tarjeta a la vista, **When** la persona mira su parte inferior, **Then** ve la
   fecha y las dos acciones **en la misma línea**, la fecha al inicio y las acciones al final.
4. **Given** el listado a la vista, **When** la persona lo desplaza, **Then** la cabecera editorial
   y las filas de filtros **permanecen visibles** y solo se mueven las tarjetas.
5. **Given** el listado desplazado, **When** la persona mira la cabecera, **Then** sigue diciendo
   qué se está viendo y cuántos anuncios hay, aunque ocupe menos alto que al principio.
6. **Given** el listado desplazado, **When** la persona vuelve arriba del todo, **Then** la cabecera
   recupera su tamaño y su fecha rotulada.
7. **Given** una sección elegida desde los filtros, **When** la persona desplaza y vuelve a elegir
   otra, **Then** no ha tenido que subir para alcanzar los filtros.
8. **Given** que no hay conexión, **When** la persona desplaza el listado, **Then** el aviso de
   falta de conexión **sigue a la vista**.

---

### Edge Cases

- **Una publicación sin organismo**: el campo es opcional y hay anuncios de los que no se deduce.
  La tarjeta se compone sin esa línea, sin dejar un hueco donde debería estar el nombre.
- **Un título que empieza por el organismo**: es el caso normal, no la excepción. El prefijo no se
  vuelve a pintar (FR-021).
- **Un título cuyo prefijo solo se parece al organismo**: «FRATERNIDAD MUPRESPA MATEPSS Nº 275» no
  es «Fraternidad Muprespa». Se conserva entero: recortar por parecido mutilaría títulos oficiales.
- **Un título que es solo el organismo y dos puntos**: se conserva entero. Una tarjeta sin título
  sería peor que una que repite el organismo.
- **Un organismo muy largo**: los hay de setenta caracteres. En mayúsculas se lee peor, así que se
  mantiene el tope de dos líneas y lo que no cabe se recorta ahí, no en el título.
- **Un título muy largo**: sigue con su tope de cuatro líneas y no se recorta antes por haber
  crecido el resto de la tarjeta.
- **Tamaño de letra al 200 %**: la fecha y las dos acciones dejan de caber en una línea. Se apilan,
  en lugar de pisarse o de recortar la fecha.
- **Una sección con subsecciones**: la zona fija gana una fila de filtros y el listado pierde alto.
  Sigue habiendo tarjetas visibles y desplazables.
- **Un teléfono pequeño**: es donde la zona fija más pesa. La cabecera compactada es lo que hace que
  siga cabiendo contenido.
- **Un listado que no llena la pantalla**: con dos o tres publicaciones no hay desplazamiento, así
  que la cabecera se queda en su tamaño grande y no encoge sin motivo.
- **Un listado vacío o en error**: la zona fija se comporta igual; lo que cambia es lo que hay
  debajo.

## Requirements *(mandatory)*

### Functional Requirements

**La tarjeta**

- **FR-001**: Los cuatro datos de la tarjeta —sección, organismo, título y fecha— MUST presentarse
  con tamaños **distinguibles entre sí**, de modo que el orden de lectura que el documento de diseño
  declara sea visible y no solo esté escrito.
- **FR-002**: El organismo emisor MUST mostrarse **en mayúsculas** y situarse entre la etiqueta de
  sección y el título.
- **FR-003**: El título MUST conservar el color de texto principal. MUST NOT pintarse en el color
  institucional.
- **FR-004**: La fecha MUST compartir línea con las acciones de compartir y guardar, con la fecha al
  inicio de la línea y las acciones al final.
- **FR-005**: Cuando la fecha y las acciones no quepan en una línea sin invadir sus áreas táctiles,
  MUST apilarse en lugar de recortarse o solaparse.
- **FR-006**: La etiqueta de sección MUST seguir acompañando al indicador de color, y MUST NOT
  depender del color como único portador de significado.
- **FR-007**: Un organismo ausente MUST omitir su línea, sin dejar espacio reservado.
- **FR-008**: Los tamaños MUST salir de la escala tipográfica del sistema de diseño. MUST NOT
  introducirse un tamaño nuevo ni escribirse ninguno en el punto de uso.
- **FR-021**: El título MUST NOT repetir el organismo que la línea de encima ya muestra. Cuando el
  título empiece exactamente por el organismo emisor, ese prefijo MUST omitirse **al pintarlo**; lo
  almacenado MUST NOT cambiar, de modo que compartir y buscar sigan viendo el título íntegro. Un
  prefijo que solo se parezca al organismo MUST conservarse entero.

  > **Añadido durante la implementación, 12 de septiembre de 2026.** No es alcance nuevo: es la
  > mitad de la petición original del propietario que esta especificación no había recogido —«y
  > debajo, **sin el nombre de la entidad**, el título de la publicación»—. Lo destapó el volcado
  > del árbol de accesibilidad del paso previo a implementar: el BOC publica el organismo en la
  > ruta de clasificación **y** al principio del título en mayúsculas, y la tarjeta pintaba los
  > dos. Con el organismo a dieciséis puntos y en caja alta, la tarjeta habría quedado con dos
  > líneas seguidas diciendo lo mismo, que es lo contrario de FR-001. Ver `research.md` D-416.

**El desplazamiento de Inicio**

- **FR-009**: La barra superior, la cabecera editorial y las filas de filtros MUST permanecer
  visibles mientras se desplaza el listado. Solo las tarjetas MUST desplazarse.
- **FR-010**: La cabecera editorial MUST compactarse cuando el listado se desplaza, y MUST recuperar
  su tamaño al volver al principio.
- **FR-011**: Compactada, la cabecera MUST seguir mostrando la denominación de lo que se está viendo
  y el número de publicaciones. La fecha rotulada MUST poder replegarse.
- **FR-012**: La transición entre los dos tamaños de la cabecera MUST ser gradual, sin saltos.
- **FR-013**: La zona que no se desplaza MUST distinguirse del listado mediante un fondo sólido y un
  divisor inferior, para que las tarjetas no pasen por debajo de un fondo transparente.
- **FR-014**: El aviso de falta de conexión MUST permanecer visible mientras no haya conexión, sin
  desplazarse con el listado y sin ocultar contenido.
- **FR-015**: La actualización manual mediante el gesto de deslizar hacia abajo MUST seguir
  disponible sobre el listado.
- **FR-016**: El listado MUST conservar la posición de lectura ante un cambio del tamaño de letra
  del sistema y ante un ciclo de segundo plano.
- **FR-017**: La segunda fila de filtros MUST seguir apareciendo y desapareciendo según la selección,
  ahora dentro de la zona fija, sin dejar hueco cuando no procede.

**Verificación**

- **FR-018**: MUST existir una prueba automática que compruebe que los cuatro datos de la tarjeta
  tienen **alturas distintas**, para que nadie pueda igualar los tamaños sin que algo se ponga rojo.
- **FR-019**: MUST existir pruebas automáticas que comprueben que, tras desplazar el listado, la
  cabecera sigue presente, se ha compactado y los filtros siguen alcanzables.
- **FR-020**: Las desviaciones respecto al documento de diseño MUST quedar registradas en el propio
  documento, con su fecha y su motivo.

### Key Entities

Ninguna. Esta feature **no introduce, modifica ni consulta ningún dato**: es la misma publicación
que la 003 ya guarda y observa, pintada de otra forma.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Los cuatro datos de la tarjeta se distinguen por tamaño, y se verifica de forma
  mecánica: una comprobación automatizada falla si dos de ellos pasan a medir lo mismo.
- **SC-002**: Con el listado desplazado, la persona sigue viendo en todo momento **qué está mirando
  y cuántos anuncios hay**.
- **SC-003**: Cambiar de sección desde los filtros **no requiere volver al principio del listado**:
  cero desplazamientos previos.
- **SC-004**: Con el tamaño de letra del sistema al **200 %** no se recorta el organismo, el título
  ni la fecha, y las acciones conservan su área táctil.
- **SC-005**: En el teléfono más pequeño que la aplicación soporta, y con la sección que más filas
  de filtros añade, **sigue habiendo al menos una tarjeta completa visible**.
- **SC-006**: La posición de lectura no se pierde al volver de segundo plano.
- **SC-007**: Las **cuatro comprobaciones de calidad** del proyecto terminan en verde: construcción,
  pruebas sin interfaz, pruebas de interfaz y ausencia de avisos nuevos.

## Assumptions

- **Es un retoque visual, no un cambio de comportamiento.** No entra ni sale un dato, no cambia
  ninguna consulta, no hay migración y el modelo de dominio queda intacto. Lo que se toca es cómo se
  pinta lo que ya existe.
- **El título se queda en el color de texto principal.** En la captura aportada se lee azulado, y se
  acuerda con el propietario que es efecto del tamaño: manda el apartado 12.1 del documento de
  diseño y el color no se toca.
- **La cabecera se queda fija pero se compacta.** Fija y siempre entera se come unos cuatrocientos
  de los seiscientos sesenta y siete puntos de alto del teléfono más pequeño soportado, y con la
  segunda fila de filtros caben una o dos tarjetas. Decisión del propietario: se compacta, y en un
  teléfono grande el resultado es el de la captura.
- **El aviso de falta de conexión va con la parte fija.** Habla de toda la pantalla —de que lo que
  se lee es lo último descargado—, así que perderlo de vista al desplazar haría creer que se está
  leyendo lo de hoy.
- **Cómo se detecta el desplazamiento y cómo se compacta la cabecera son materia del plan.** Esta
  especificación describe qué debe ocurrir y por qué; el mecanismo se decide y se argumenta en
  `plan.md` y en `research.md`.
- **Los tamaños salen de la escala de catorce del documento de diseño**, sin inventar ninguno. Lo
  que cambia es qué peldaño de esa escala usa cada dato, no la escala.
- **El detalle de la publicación no se toca.** Su apartado del documento de diseño dice hoy que su
  cabecera «se desplaza con el contenido». Si Inicio la fija y el detalle no, las dos pantallas
  dejan de hablar el mismo idioma; se anota en el documento para **decidirlo en esa feature**, no
  aquí.
- **Las mayúsculas del organismo son de presentación, no de dato.** Lo guardado no cambia; cambia
  cómo se pinta. Es lo que permite que la búsqueda y el compartir sigan viendo el texto original.
  **Y lo mismo vale para el recorte del prefijo del título** (FR-021): se omite al pintar, nunca al
  guardar.

### Procedencia

- **Esta feature no porta nada.** Es la primera del proyecto sin origen en la aplicación Android:
  nace de mirar el resultado de la 003 con contenido real. Ocupa el número **004** y el detalle de
  la publicación pasa al **005**; las demás corren un número en la tabla de orden de portado, que ya
  estaba desacoplada de la numeración de Android desde que la 013 se absorbió.
- **Sustituye a FR-039 de la feature 003**, que enumeraba los elementos de la tarjeta «en este orden
  … la fecha con su icono, **y** las acciones secundarias», como cuatro pasos consecutivos. Juntar
  la fecha con las acciones lo contradice. **La 003 no se toca**: está cerrada e integrada, y
  reescribir la especificación de una feature terminada convertiría su historia en algo que nunca
  ocurrió.
- **Amplía FR-030 de la 003**, que fija el orden vertical de Inicio pero no dice nada de qué se
  desplaza. Aquel requisito sigue siendo cierto; simplemente no cubría esta pregunta.
- **Conserva FR-040, FR-044 y FR-056 de la 003** —la etiqueta que acompaña al color, la posición de
  lectura y el desplazamiento horizontal de las filas—, que siguen valiendo tal cual y que esta
  feature vuelve a comprobar porque cambia el contenedor en el que viven.
- **Dos requisitos vienen del propio documento de diseño y no del propietario**: el apilado de la
  fila de acciones (FR-005), que su apartado 31.3 pide y su 31.2 exige, y el fondo sólido con
  divisor de la zona fija (FR-013), que su apartado 14.6 ya autorizaba para los filtros fijados. Se
  descubrieron al inventariar qué contradecía el cambio.
