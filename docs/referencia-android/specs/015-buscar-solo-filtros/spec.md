# Feature Specification: Buscar con solo filtros

**Feature Branch**: `015-buscar-solo-filtros`

**Created**: 9 de septiembre de 2026

**Status**: Draft

**Input**: User description: "Mejora en el buscador «avanzado». Cuando en Buscar aplicas filtros y
no pones nada en el campo de texto no busca nada. Tal vez estaría bien que sí buscara todo lo que
coincide con el filtro que se le ha aplicado. Por ejemplo, si pones una fecha que muestre todos los
de esa fecha; si pones un rango de fechas, pues todos los de ese rango; y si después quieres añadir
algo en el campo de texto para concretar, pues filtros + lo concretado. Y esta misma lógica para el
resto de los filtros."

Decisiones cerradas con el propietario en el plan previo a esta especificación: **con un filtro
activo, el texto acota desde la primera letra** —no se ignora una letra sola—; el **orden** por sí
solo no es un filtro y no lanza la búsqueda; el **tope de 300** resultados y su aviso se mantienen;
y se aprovecha para cerrar un **destello de «no hay resultados»** que hoy existe al cambiar la
consulta y que con esta feature pasaría a verse en cada «Aplicar».

---

## Lo que hay que saber antes de leer nada más *(contexto imprescindible)*

- **No es que los filtros no funcionen: es que nadie les pregunta.** La feature 006 decidió que el
  buscador global no arrancara hasta el segundo carácter, para que una sola letra no devolviera medio
  archivo (D-011 de su `research.md`). Esa misma regla, escrita como «hay texto suficiente», es la que
  hoy deja a los filtros sin efecto cuando el campo está vacío: la hoja de filtros se aplica, las
  etiquetas aparecen, y la pantalla sigue diciendo «Escribe al menos dos letras». El mecanismo que
  recorta por fecha, sección, subsección y organismo **ya existe y ya funciona**: es el que actúa
  cuando además hay texto. Esta feature cambia **cuándo** se busca, no **cómo**.
- **Una letra sobre el archivo entero y una letra sobre una sección no son la misma operación.** El
  motivo del mínimo de dos caracteres era el volumen. Con un filtro puesto, el conjunto ya está
  acotado y una letra solo lo **reduce**; por eso con filtros el texto acota desde el primer carácter
  y sin filtros el mínimo de dos se conserva intacto. Se descartó la alternativa de «ignorar» el texto
  corto con filtros: teclear «a» con una sección puesta y ver «300 resultados» sin moverse se lee como
  que la aplicación se ha quedado colgada.
- **El tope de 300 se va a alcanzar mucho más a menudo, y es correcto.** Una sección sola tiene
  cientos o miles de publicaciones, porque en esta aplicación no se borra nunca ninguna. La pantalla
  ya dice «Hay más de 300 publicaciones. Acota la búsqueda para verlas todas», que es exactamente lo
  que hay que decir: la salida es añadir texto o más filtros. No se pagina ni se sube el tope.
- **Hay un destello que hoy casi nadie ve y que esta feature convertiría en la norma.** Al cambiar la
  consulta, la pantalla combina la consulta nueva con el resultado de la **anterior** durante la
  fracción de segundo que tarda el almacén en responder. Hoy solo se nota al pasar de una a dos
  letras: aparece «No hemos encontrado publicaciones» un instante y luego la lista. Con filtros
  ejecutables, pulsar «Aplicar» desde la pantalla inicial mostraría ese mensaje **cada vez**, y la
  analítica registraría que la búsqueda no encontró nada aunque encontrara trescientas. Se cierra
  aquí porque es el camino principal de esta feature.
- **Nada de esto toca Inicio.** La búsqueda rápida de la barra superior y el puente «no hay nada aquí
  → búscalo en todo el BOC» (FR-006 a FR-020 de la 006) siguen exactamente igual. El puente sigue
  trayendo solo el término escrito.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver todo lo que cumple un filtro sin escribir nada (Priority: P1)

Alguien quiere saber qué publicó el BOC en una fecha, o qué hay en una sección, o qué ha publicado un
organismo. Abre Buscar, abre los filtros, elige lo que le interesa y aplica. Sin escribir ni una
letra, la pantalla le enseña todas las publicaciones que cumplen lo que eligió, con su recuento y, si
son más de las que caben, el aviso de acotar.

**Why this priority**: es la petición literal del propietario y lo que hoy no funciona. Sin esto la
hoja de filtros promete algo que no da.

**Independent Test**: en Buscar, sin texto, aplicar un filtro de sección y comprobar que aparece la
lista de esa sección con su recuento; repetir con una fecha, con un rango, con una subsección y con un
organismo.

**Acceptance Scenarios**:

1. **Given** Buscar en su estado inicial, con el campo vacío, **When** se elige la sección
   «Disposiciones generales» y se aplica, **Then** la pantalla muestra las publicaciones de esa
   sección, el recuento, la etiqueta de la sección, y —si hay más de 300— el aviso de acotar.
2. **Given** el campo vacío, **When** se eligen «desde» y «hasta» con dos fechas distintas y se
   aplica, **Then** la pantalla muestra exactamente las publicaciones con fecha dentro del rango,
   ninguna fuera.
3. **Given** el campo vacío, **When** se eligen «desde» y «hasta» con la **misma** fecha, **Then** la
   pantalla muestra las publicaciones de ese día.
4. **Given** el campo vacío, **When** se elige solo «desde», **Then** aparecen las publicaciones de
   ese día en adelante; **When** se elige solo «hasta», **Then** las de ese día hacia atrás.
5. **Given** el campo vacío, **When** se elige un organismo, **Then** aparecen sus publicaciones; y
   **When** se añade además una sección, **Then** la lista se recorta a las que cumplen las dos.
6. **Given** el campo vacío, **When** se elige una subsección, **Then** aparecen las publicaciones de
   esa subsección y no las del resto de su sección.

---

### User Story 2 - El texto concreta lo que los filtros ya acotaron (Priority: P1)

Con una sección puesta y su lista delante, la persona empieza a escribir para afinar. Desde la
primera letra la lista se recorta; al borrar el texto, la lista de la sección vuelve. Si en cambio
quita la última etiqueta de filtro sin haber escrito nada, la pantalla vuelve a su estado inicial,
porque ya no hay nada que buscar.

**Why this priority**: es la segunda mitad de la petición («filtros + lo concretado») y lo que hace
que las dos vías —texto y filtros— se compongan en vez de estorbarse.

**Independent Test**: con una sección aplicada, escribir una letra y comprobar que la lista se acota;
borrar y comprobar que vuelve; quitar la etiqueta y comprobar el estado inicial.

**Acceptance Scenarios**:

1. **Given** una sección aplicada y su lista en pantalla, **When** se escribe una sola letra,
   **Then** la lista se recorta a las publicaciones de esa sección cuyo texto buscable contiene esa
   letra.
2. **Given** una sección aplicada y dos letras escritas, **When** se borra el texto por completo,
   **Then** vuelve la lista completa de la sección, sin pasar por el estado inicial ni por el vacío.
3. **Given** una sección aplicada y el campo vacío, **When** se quita la etiqueta de la sección,
   **Then** la pantalla vuelve al estado inicial.
4. **Given** una sección aplicada y una sola letra escrita, **When** se quita la etiqueta de la
   sección, **Then** la pantalla vuelve al estado inicial: una letra sin filtros sigue sin ser
   suficiente.
5. **Given** ningún filtro y el campo vacío, **When** se escribe una sola letra, **Then** la pantalla
   se queda en el estado inicial, exactamente como hasta ahora.
6. **Given** varios filtros aplicados y texto escrito, **When** se pulsa «Limpiar todo», **Then** se
   quitan los filtros, el texto se conserva, y la búsqueda sigue o se detiene según ese texto tenga
   o no dos caracteres.

---

### User Story 3 - Sin destellos: la pantalla no dice «no hay nada» antes de saberlo (Priority: P2)

Al aplicar filtros, la persona ve pasar la pantalla del estado inicial —o de la lista que tuviera— a
la lista nueva. En ningún momento aparece «No hemos encontrado publicaciones» para una consulta a la
que el almacén todavía no ha contestado. Cuando el almacén contesta que no hay nada, entonces sí.

**Why this priority**: sin esto, cada «Aplicar» empieza con un mensaje falso, y la analítica de la
feature nace contando ceros.

**Independent Test**: desde el estado inicial, aplicar una sección con publicaciones y observar la
secuencia de estados: inicial → lista, sin «sin resultados» en medio. Después aplicar un rango de
fechas sin publicaciones y comprobar que el estado vacío sí aparece, una vez el almacén ha contestado.

**Acceptance Scenarios**:

1. **Given** el estado inicial, **When** se aplica un filtro con coincidencias, **Then** la pantalla
   pasa del estado inicial a la lista **sin** mostrar el estado vacío entre medias.
2. **Given** una lista en pantalla, **When** se cambia el filtro por otro con coincidencias, **Then**
   la lista anterior se mantiene visible hasta que llega la nueva, y el estado vacío no aparece.
3. **Given** cualquier estado, **When** se aplica un filtro que de verdad no tiene coincidencias,
   **Then** la pantalla muestra el estado vacío una vez el almacén ha respondido.
4. **Given** una búsqueda por filtros que devuelve publicaciones, **When** se consulta la analítica,
   **Then** el evento de esa búsqueda lleva el recuento que se mostró, no cero.

---

### User Story 4 - Volver y encontrarlo igual, también sin texto (Priority: P2)

Alguien deja Buscar con una sección puesta y el campo vacío: abre un resultado, o se va a otra
pestaña, o el sistema cierra la aplicación por falta de memoria. Al volver, la etiqueta está y la
lista de la sección también, sin tener que aplicar nada de nuevo.

**Why this priority**: la 006 ya garantiza que consulta y filtros se conservan (FR-043 a FR-045); lo
que hay que asegurar es que, ahora que los filtros bastan para buscar, al restaurarlos la búsqueda se
relanza sola.

**Independent Test**: aplicar una sección sin texto, forzar la muerte del proceso y volver: la lista
aparece sin intervención.

**Acceptance Scenarios**:

1. **Given** una sección aplicada y el campo vacío, **When** se abre un resultado y se vuelve,
   **Then** la lista de la sección sigue ahí, en la misma posición.
2. **Given** una sección aplicada y el campo vacío, **When** se cambia a Inicio y se vuelve a Buscar,
   **Then** la etiqueta y la lista se muestran de nuevo.
3. **Given** una sección aplicada y el campo vacío, **When** el sistema cierra la aplicación y la
   persona la reabre en Buscar, **Then** la etiqueta se recupera y la lista se vuelve a mostrar sin
   tocar nada.

---

### User Story 5 - El estado inicial ofrece las dos vías (Priority: P3)

Quien llega a Buscar por primera vez lee, antes de hacer nada, que puede escribir **o** aplicar un
filtro. Hoy el texto solo habla de escribir dos letras, que con esta feature dejaría de ser cierto.

**Why this priority**: es un texto. Importa porque es la única pista de que los filtros valen solos,
pero no condiciona el mecanismo.

**Independent Test**: abrir Buscar sin nada y leer el estado inicial.

**Acceptance Scenarios**:

1. **Given** Buscar sin texto ni filtros, **When** se mira la pantalla, **Then** el estado inicial
   dice que se puede escribir al menos dos letras **o** aplicar un filtro.
2. **Given** filtros aplicados sin coincidencias, **When** se mira la pantalla, **Then** el estado
   vacío sigue sugiriendo probar con otras palabras o quitar alguno de los filtros, como hasta ahora.

---

### User Story 6 - Las etiquetas se ven enteras y la hoja no vuelve sola (Priority: P3)

Con dos o más filtros puestos, la persona ve **todas** las etiquetas y la acción «Limpiar todo» sin
tener que desplazar nada: si no caben en una línea, saltan a la siguiente. Y si el sistema cierra la
aplicación mientras tenía la hoja de filtros abierta, al volver encuentra sus filtros aplicados —las
etiquetas y su lista— pero no la hoja, que es una acción a medias y no un estado que conservar.

**Why this priority**: los dos comportamientos son heredados de la 006 y salieron en el recorrido
manual de esta feature. Ninguno impide usar Buscar; los dos hacen que lo aplicado sea menos visible o
más sorprendente de lo debido. Se arreglan aquí, por decisión del propietario, porque tocan la misma
pantalla y la rama está abierta.

**Independent Test**: aplicar fechas, sección y organismo y comprobar que «Limpiar todo» está a la
vista sin desplazar; abrir la hoja, matar el proceso y volver: la hoja no está, las etiquetas sí.

**Acceptance Scenarios**:

1. **Given** una sección aplicada, **When** se añade un rango de fechas, **Then** las dos etiquetas y
   «Limpiar todo» se ven sin desplazamiento horizontal, aunque ocupen dos líneas.
2. **Given** los cuatro filtros aplicados —fechas, sección, subsección y organismo—, **When** se mira
   la fila, **Then** las cuatro etiquetas y «Limpiar todo» están a la vista.
3. **Given** la sección «Disposiciones generales» aplicada, **When** se lee su etiqueta, **Then** dice
   «Sección: Disposiciones», el nombre corto del catálogo, y su acción accesible dice «Quitar el filtro
   Sección: Disposiciones».
4. **Given** la hoja de filtros abierta, **When** el sistema cierra la aplicación y la persona vuelve,
   **Then** la hoja no está abierta; los filtros que estuvieran aplicados siguen en sus etiquetas y la
   lista se muestra.
5. **Given** la hoja de filtros abierta, **When** la pantalla se reconstruye sin que el proceso muera
   (un cambio de tamaño de letra, por ejemplo), **Then** la hoja se cierra, como hacen el panel lateral
   y los menús de la aplicación, y lo aplicado se conserva.

---

### Edge Cases

- **Una sola letra sin filtros**: no se lanza, exactamente como hasta ahora (D-011 de la 006). El
  estado inicial se queda.
- **Una sola letra con un filtro**: acota. La regla del volumen protegía al archivo entero, no a una
  sección ya recortada.
- **Solo el orden, sin texto ni filtros**: no se busca nada. En la práctica ni siquiera se ofrece: el
  selector de orden solo aparece cuando hay resultados.
- **Un filtro con miles de coincidencias** —una sección grande, un rango de un año—: se muestran 300
  y el aviso de acotar. Es la situación normal de esta feature, no una excepción.
- **Un rango de fechas en el que no se publicó nada** (un fin de semana, por ejemplo): estado vacío,
  no error.
- **Publicaciones descargadas antes de la feature 006 cuyo texto buscable aún no se ha rellenado**:
  no se encuentran por texto hasta que el relleno por lotes las alcance, pero **sí por filtros**, que
  no dependen de ese texto. Es una mejora lateral, no un requisito.
- **El archivo vacío** (primera ejecución, sincronización aún sin terminar) con un filtro aplicado:
  estado vacío, no error, igual que con texto.
- **«Limpiar todo» con el campo vacío**: estado inicial. Con dos o más letras escritas: se busca solo
  por texto. Con una letra: estado inicial.
- **Puente desde Inicio con un término de una sola letra**: la búsqueda rápida filtra desde la primera
  letra, así que puede traspasar una; llega sin filtros y no es suficiente → estado inicial con el
  texto ya escrito, como hasta ahora. El puente no traspasa filtros.
- **Cambiar de filtro mientras el anterior aún no ha contestado**: solo cuenta la última consulta; la
  respuesta de una consulta ya sustituida no se muestra ni se registra.
- **Fecha «desde» posterior a «hasta»**: sigue impidiéndose en la hoja (FR-038 de la 006). No cambia.
- **Los cuatro filtros a la vez**: cinco elementos en la fila —cuatro etiquetas y «Limpiar todo»—.
  Ocupan dos líneas y se ven todos. Es el máximo posible: no hay más filtros.
- **Una sección o subsección cuyo código ya no esté en el catálogo** (dato antiguo): la etiqueta
  muestra el código, como hasta ahora.

## Requirements *(mandatory)*

### Functional Requirements

#### Cuándo se busca

- **FR-001**: El buscador global MUST ejecutar la búsqueda cuando haya **al menos un filtro activo**,
  con independencia de que el campo de texto esté vacío o tenga menos de dos caracteres.
- **FR-002**: Sin ningún filtro activo, la búsqueda MUST seguir exigiendo al menos dos caracteres de
  texto; por debajo, la pantalla MUST quedarse en su estado inicial. La regla de la 006 se conserva
  para el caso que la motivó.
- **FR-003**: Con al menos un filtro activo, el texto escrito MUST acotar el resultado desde el
  **primer** carácter.
- **FR-004**: El orden («Más recientes» / «Más antiguas») MUST NOT contar como filtro: por sí solo no
  lanza ninguna búsqueda.
- **FR-005**: Cualquiera de los cinco filtros —fecha desde, fecha hasta, sección, subsección y
  organismo— MUST bastar por sí solo para lanzar la búsqueda, y MUST poder combinarse con los demás
  con el mismo efecto que hoy tienen acompañados de texto.
- **FR-006**: Una fecha «desde» igual a la fecha «hasta» MUST devolver las publicaciones de ese día.
  Solo «desde» MUST devolver las de ese día en adelante; solo «hasta», las de ese día hacia atrás.
- **FR-007**: El texto, cuando lo haya, MUST seguir normalizándose y buscándose exactamente como
  establecen FR-001 a FR-004 de la 006: sin distinguir mayúsculas ni tildes, literal, sin comodines.

#### Qué se ve

- **FR-008**: Los resultados de una búsqueda por filtros solos MUST mostrarse con el mismo recuento,
  la misma tarjeta y las mismas acciones —abrir, guardar, compartir— que una búsqueda con texto.
- **FR-009**: El tope de 300 resultados y el aviso de acotar (FR-032 de la 006) MUST mantenerse sin
  cambio, también para las búsquedas por filtros solos.
- **FR-010**: Borrar el texto con filtros activos MUST mantener en pantalla los resultados de los
  filtros; la pantalla MUST NOT pasar por el estado inicial ni por el vacío al hacerlo.
- **FR-011**: Quitar el último filtro activo con el campo vacío, o con menos de dos caracteres, MUST
  devolver la pantalla al estado inicial.
- **FR-012**: El estado inicial MUST decir que se puede escribir al menos dos letras **o** aplicar un
  filtro. MUST NOT afirmar que escribir sea la única vía.
- **FR-013**: El estado vacío MUST seguir diciendo que no se han encontrado publicaciones y sugiriendo
  modificar o quitar alguno de los filtros (FR-033 de la 006). Vale para los dos casos, con texto y
  sin él.
- **FR-014**: La pantalla MUST NOT mostrar el estado vacío para una consulta a la que el almacén aún
  no ha respondido. Mientras llega la respuesta, la pantalla MUST mantener lo que mostraba —el estado
  inicial o los resultados anteriores— y el campo y las etiquetas MUST reflejar ya la consulta nueva.
- **FR-015**: El estado vacío MUST mostrarse cuando, y solo cuando, el almacén ha respondido a la
  consulta actual sin ninguna coincidencia.
- **FR-016**: Si la consulta cambia antes de que el almacén responda a la anterior, la respuesta de la
  anterior MUST descartarse: ni se muestra ni se registra.

#### Conservación del estado

- **FR-017**: Los filtros aplicados sin texto MUST conservarse al abrir un resultado y volver, al
  cambiar de destino de la barra inferior y volver, y tras la muerte del proceso (FR-043 a FR-045 de
  la 006), y al restaurarse la búsqueda MUST relanzarse sola y mostrar sus resultados.

#### El puente desde Inicio

- **FR-018**: El puente desde la búsqueda rápida de Inicio (FR-018 a FR-020 de la 006) MUST NOT
  cambiar: sigue traspasando únicamente el término escrito, y ese término MUST prevalecer sobre el
  texto que Buscar tuviera, sin tocar los filtros que Buscar tuviera.

#### Privacidad y telemetría

- **FR-019**: El sistema MUST NOT registrar, ni en analítica ni en trazas de error, el texto escrito
  ni el **valor** de ningún filtro: ni las fechas, ni la sección, ni la subsección, ni el organismo.
  Solo MUST registrarse si había filtros, si había texto, y un tramo del recuento de resultados.
- **FR-020**: El evento de una búsqueda MUST reflejar el recuento que el almacén devolvió a **esa**
  consulta, nunca el de una consulta anterior.
- **FR-021**: Dos búsquedas con el mismo texto —o sin texto— pero con filtros distintos MUST contar
  como dos búsquedas distintas en analítica.

#### Transversales

- **FR-022**: Todos los textos nuevos o modificados MUST vivir en los recursos de cadenas de la
  aplicación.
- **FR-023**: Esta feature MUST NOT introducir migraciones de base de datos, MUST NOT cambiar ningún
  dato almacenado y MUST NOT añadir consultas nuevas al almacén: la búsqueda por filtros solos es la
  misma consulta de la 006 con el texto vacío.
- **FR-024**: Ninguna búsqueda, con o sin texto, MUST generar tráfico de red (FR-026 de la 006).

#### Las etiquetas y la hoja (hallazgos del recorrido manual, US6)

- **FR-025**: Todas las etiquetas de filtros activos y la acción «Limpiar todo» MUST verse en la
  pantalla sin desplazamiento horizontal; si no caben en una línea, MUST saltar a la siguiente.
- **FR-026**: Las etiquetas de sección y de subsección MUST usar el **nombre corto** del catálogo de
  secciones («Sección: Disposiciones»), y su acción de quitar MUST describir ese mismo texto.
- **FR-027**: La hoja de filtros MUST NOT restaurarse abierta tras la muerte del proceso ni tras una
  reconstrucción de la pantalla; los filtros aplicados MUST conservarse (FR-045 de la 006), con sus
  etiquetas y su lista.
- **FR-028**: La hoja MUST seguir abriéndose desde la misma acción, y su contenido y comportamiento
  internos —campos, validación del rango, limpiar y aplicar— MUST NOT cambiar.

---

## Requisitos de features anteriores que quedan superados

Se dejan escritos para que no se lean como incumplidos:

- **Feature 006, FR-005** («Un campo con el texto vacío, o con solo espacios, MUST equivaler a no
  haber buscado»): **se acota**. Sigue siendo cierto **sin filtros**. Con al menos un filtro activo,
  el campo vacío equivale a buscar todo lo que cumple los filtros (FR-001 de esta feature).
- **Feature 006, FR-028**, primera frase («Los resultados MUST actualizarse mientras se escribe, sin
  botón de buscar»): **se mantiene**. Segunda frase («La consulta MUST tener al menos dos caracteres;
  por debajo, la pantalla MUST quedarse en su estado inicial»): **superada**. El mínimo aplica solo sin
  filtros (FR-002); con filtros el texto acota desde la primera letra (FR-003).
- **Feature 006, edge case «Consulta de una sola letra en el buscador global»**: **enmendado**. Sigue
  sin lanzarse sin filtros; con filtros acota.
- **Feature 006, asunción del mínimo de dos caracteres**: **enmendada**. El motivo —el volumen de una
  letra sobre el archivo entero— se conserva; con un filtro el conjunto ya está acotado.
- **Feature 006, decisión D-011 de su `research.md`**: **enmendada** en los mismos términos.
- **Feature 006, FR-039** («Los filtros activos MUST mostrarse en la propia pantalla como etiquetas
  legibles, cada una con una acción para quitarla, más una acción para quitarlos todos»): **se
  amplía**. Presentes **y a la vista**: la fila salta de línea en vez de desplazarse (FR-025), y las
  etiquetas de sección y subsección usan el nombre corto (FR-026).
- **Feature 006, FR-045** («La consulta y los filtros MUST sobrevivir a la muerte del proceso»): **se
  mantiene** tal cual. Lo que sobrevive son la consulta y los filtros; la hoja abierta nunca formó
  parte de ese requisito y desde esta feature no se restaura (FR-027).
- **Feature 006, FR-024, FR-032, FR-033, FR-034 a FR-038, FR-040 a FR-044 y FR-046**: **se mantienen
  íntegros**. El tope, el aviso, el estado vacío, el contenido de la hoja de filtros, el orden, la
  conservación de consulta y filtros, y la privacidad no cambian.
- **Feature 006, FR-006 a FR-020** (búsqueda rápida y puente): **se mantienen íntegros**, como ya
  confirmó la 013.
- **Feature 013**: no se toca nada de lo que especificó.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Aplicar una sección sin escribir nada muestra sus publicaciones —hasta 300, con el
  aviso si hay más— en menos de un segundo desde que se pulsa «Aplicar».
- **SC-002**: Un rango de fechas aplicado sin texto devuelve exactamente las publicaciones con fecha
  dentro del rango: ninguna fuera y ninguna de dentro que falte, en el 100 % de los casos.
- **SC-003**: Con un filtro activo, escribir una letra acota la lista y borrarla la restaura, en el
  100 % de los casos.
- **SC-004**: Sin filtros, una sola letra deja la pantalla en el estado inicial en el 100 % de los
  casos: cero regresiones sobre el comportamiento de la 006.
- **SC-005**: En una prueba de recorrido de veinte aplicaciones de filtros con coincidencias, el
  estado vacío aparece **cero** veces.
- **SC-006**: Cero eventos de analítica con recuento «0» para búsquedas que mostraron resultados.
- **SC-007**: Tras la muerte del proceso con filtros y sin texto, la lista vuelve sola al reabrir
  Buscar en el 100 % de los casos.
- **SC-008**: Ningún valor de filtro ni texto de consulta aparece en analítica ni en trazas de error.
- **SC-009**: El recuento de una búsqueda con texto y filtros es idéntico antes y después de esta
  feature, para los mismos datos almacenados.
- **SC-010**: La regla «los filtros bastan para buscar» y la ausencia del destello quedan cubiertas
  por pruebas automáticas que fallan sin el cambio, y las cuatro puertas de calidad del proyecto
  quedan en verde.
- **SC-011**: Con los cuatro filtros aplicados, «Limpiar todo» y las cuatro etiquetas están a la vista
  sin ningún desplazamiento, en el 100 % de los casos y en cualquier ancho de teléfono.
- **SC-012**: Tras la muerte del proceso con la hoja de filtros abierta, al volver la hoja no aparece
  y las etiquetas aplicadas sí, en el 100 % de los casos.

---

## Fuera de alcance

- Paginar los resultados o subir el tope de 300. La salida sigue siendo acotar.
- Añadir filtros nuevos (municipio, tipo de anuncio…). Los cinco de la 006 son los que hay.
- Traspasar filtros en el puente desde Inicio. Llega solo el término.
- Un indicador de carga o estado «buscando». La respuesta llega en una fracción de segundo y la
  pantalla mantiene lo que mostraba hasta entonces.
- Cambiar la búsqueda rápida de Inicio o su mínimo de una letra.
- Búsquedas recientes, búsquedas guardadas u ordenación por relevancia, ya excluidas por la 006.
- Cualquier cambio en Inicio, Guardados, Avisos, el detalle, el visor o las funciones de IA.

---

## Assumptions

- **Con un filtro activo, una letra acota en vez de ignorarse.** Es lo que pidió el propietario («el
  texto concreta») y se decidió en el plan. La alternativa —tratar una letra como si no hubiera texto
  hasta la segunda— se descartó porque dejaría la lista quieta mientras se escribe, que se lee como
  cuelgue.
- El tope de 300 se alcanzará en la mayoría de las búsquedas por sección sola, y se da por bueno: el
  aviso ya dice cómo acotar. Si con el uso el propietario quiere subirlo, es un cambio con su motivo,
  no parte de esta feature.
- El retardo entre aplicar un filtro y ver la lista es el mismo que hoy entre dejar de escribir y ver
  los resultados: una fracción de segundo. No hace falta indicador de carga; basta con no mostrar el
  estado vacío antes de tiempo.
- La redacción propuesta para el estado inicial es «Escribe al menos dos letras o aplica un filtro y
  verás las publicaciones que coincidan.» Puede afinarse en `/speckit-clarify` sin cambiar ningún
  requisito.
- La analítica de búsqueda gana un único dato nuevo, «si había texto», booleano, junto a «si había
  filtros» y el tramo del recuento, que ya existían. Nada más viaja.
- Las publicaciones anteriores a la 006 cuyo texto buscable aún no se ha rellenado se encuentran por
  filtros. Es consecuencia de que los filtros no dependen de ese texto, no un requisito nuevo; el
  relleno por lotes de la 006 sigue su curso.
- El contenido de la hoja de filtros y el comportamiento de las etiquetas al quitarlas (FR-034 a
  FR-038 y FR-040 de la 006) no cambian. Lo que sí cambia, por decisión del propietario tras el
  recorrido manual, es **cómo se disponen** las etiquetas —saltan de línea, nombre corto— y que la hoja
  **no vuelve abierta** tras la muerte del proceso (US6). Se descartó anclar «Limpiar todo» a la derecha
  dejando el resto desplazable, y se descartó restaurar la hoja entera con su borrador.
- La etiqueta del rango de fechas conserva su formato `dd/MM/yyyy - dd/MM/yyyy`. Acortarla sería otra
  decisión y no se toma aquí.
