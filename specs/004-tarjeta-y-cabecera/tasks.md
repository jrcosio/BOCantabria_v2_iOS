# Tasks: La tarjeta se lee de un vistazo, y la cabecera no se va

**Input**: Documentos de diseño en `specs/004-tarjeta-y-cabecera/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/, quickstart.md. **Sin `data-model.md`**,
a propósito: no entra ni sale un dato.

**Tests**: **OBLIGATORIOS.** El principio V de la constitución los declara no negociables y la
especificación los exige en FR-018 y FR-019. La prueba de una pieza se escribe **con** la pieza y
ninguna tarea se da por terminada sin su prueba en verde. **Prohibido** `.disabled`, comentar o
borrar una prueba para que pase la build — y esta feature pone **dos** en rojo a propósito, que se
arreglan diciendo lo que querían decir (**D-412**).

**Organization**: una sola historia de usuario, P1. No hay fase *Foundational* porque no hay nada
que desbloquear: los tres ficheros que se tocan existen desde la 003.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizable (ficheros distintos, sin dependencias entre sí)
- **[Story]**: a qué historia pertenece (US1, la única)
- Las rutas son exactas y relativas a la raíz del repositorio

**Abreviaturas**: `APP/` = `BOCantabria-ios/` · `TEST/` = `BOCantabria-iosTests/` ·
`UITEST/` = `BOCantabria-iosUITests/` · `DOC/` = `docs/diseno/especificaciones-diseno.md`

---

## Phase 1: Setup

**Purpose**: no hay dependencias que resolver, ni cadenas nuevas, ni tokens nuevos. Lo único que hay
que hacer antes de tocar nada es **dejar constancia del punto de partida**, porque las dos cosas que
esta feature tiene que demostrar al final son diferencias, y una diferencia sin el antes no
significa nada.

- [X] T001 Medir y anotar aquí mismo las **cifras de las cuatro puertas ANTES del cambio**, sobre la
      rama `004-tarjeta-y-cabecera` sin tocar. Medidas el 12 de septiembre de 2026, con datos
      derivados nuevos en `/tmp/boc-dd004`:

      | Puerta | Antes | Al cerrar la 003 |
      |---|---|---|
      | 1 · Construcción | **26 s**, 0 errores | 30,21 s |
      | 2 · Pruebas sin interfaz | **275 pruebas en 40 suites, 0,504 s** | 275 en 40, 0,471 s |
      | 3 · Pruebas de interfaz | **34 pruebas, 252,2 s** | 34, 246,3 s |
      | 4 · Avisos | **1**, el ajeno de `appintentsmetadataprocessor` | 1, el mismo |

      Las cuatro coinciden con el cierre de la 003 dentro del ruido de una ejecución a otra, que es
      lo que había que comprobar: **se parte de donde se dijo que se partía**. Nota de método: el
      recuento de avisos se mide **sin `-quiet`**, porque con él no se imprimen.

      **Y un hallazgo que no se buscaba**: el target de pruebas de interfaz compila con avisos de
      aislamiento de actor (`main actor-isolated property 'firstMatch' can not be referenced from a
      nonisolated autoclosure`, en `HomeBackgroundUITests.swift` y otros). **No cuentan para la
      puerta 4**, que mide el target de la aplicación, y son anteriores a esta feature. Se anota
      aquí para que no se lea como algo que esta feature introdujo.
- [X] T002 Volcar el **árbol de accesibilidad de Inicio antes del cambio** y guardarlo en
      `/tmp/boc-004-tree-antes.txt`: se pone un `print(app.debugDescription)` temporal en
      `UITEST/Home/HomeStatesUITests.swift`, se ejecuta esa sola prueba con
      `-boc-data-scenario=today` y se retira el `print`. Es **contra esto** contra lo que se compara
      en T022, y es el riesgo real de la feature: mover el `ScrollView` cambia de sitio cuatro
      contenedores y **quince funciones de prueba usan `home_content` como puerta de entrada**
      (**D-405**).

**Checkpoint**: ✅ las cifras de partida y el árbol de antes, anotados. El volcado está en
`/tmp/boc-004-tree-antes.txt`, 125 líneas, con la jerarquía
`home_root` → `home_menu`/`home_search`/`home_info` → `ScrollView` → `home_header`
(`home_header_date`, `home_header_count`) → `home_section_chips` (`chip_today`…`chip_9`) →
`home_content` (`publication_card_0`…, cada una con `publication_share` y `publication_save`).

**Y el volcado ha destapado un defecto que ninguna prueba veía** (ver T007): la etiqueta combinada
de la primera tarjeta es

> `Sección Oposiciones, Consejería de Salud, CONSEJERÍA DE SALUD: Convocatoria de
> concurso-oposición para el acceso a plazas de Enfermería., 27 de agosto de 2026`

El organismo está **dos veces**: como línea propia y como prefijo del título.
`testTheIssuerIsNotPaintedTwice` está en verde **solo porque las dos cajas no coinciden**, que es
exactamente el accidente que esa prueba existía para impedir.

---

## Phase 2: User Story 1 — Saber de qué va un anuncio sin leerlo entero (Priority: P1) 🎯 MVP

**Goal**: que los cuatro datos de la tarjeta se distingan por tamaño y que la cabecera y los filtros
no se vayan al desplazar.

**Independent Test**: abrir Inicio con el escenario `today`, comprobar que sección, organismo y
título se distinguen sin leerlos y que la fecha comparte línea con las dos acciones; desplazar el
listado y comprobar que la cabecera sigue ahí, encogida, y que los chips se alcanzan sin subir.

**El orden importa**: la tarjeta es independiente del desplazamiento y se puede ver en verde antes
de mover nada. Si algo se tuerce con el `ScrollView`, la mitad de la feature ya está demostrada.

### La tarjeta

- [X] T003 [US1] **D-403** `APP/Core/UI/Component/PublicationCard.swift`: declarar el tipo anidado
      `PublicationCard.Typography` con `section`, `organisation`, `title`, `date`, y las dos
      colecciones `hierarchy` —los tres primeros, en orden de peso creciente— y `all`. Son
      propiedades **calculadas** que devuelven tokens de `BocTheme.typography`, no valores nuevos.
      Es lo que hace afirmable FR-018: la tarjeta está combinada en un solo elemento de
      accesibilidad, así que sus cuatro textos **no existen en el árbol** y ninguna prueba de
      interfaz puede medirlos.
- [X] T004 [US1] **FR-018, FR-008, SC-001** `TEST/Core/PublicationCardTypographyTests.swift`: la
      prueba, con cuatro aserciones —los cuatro tamaños son **distintos dos a dos**;
      `section.size < organisation.size < title.size`; `date.size >= 12`, que es el suelo del §6.3;
      y **los cuatro pertenecen a `BocTheme.typography.all`**, con lo que «no se introduce un tamaño
      nuevo» deja de ser una intención—. Va junto a `BocThemeTests.swift` porque habla de la escala.
- [X] T005 [US1] **Comprobar que la prueba muerde**, que es el paso 5 del quickstart: provocar a
      mano, sobre `APP/Core/UI/Component/PublicationCard.swift`, las cuatro violaciones —igualar `organisation` y `title`; intercambiar `section` y
      `title`; poner `date` en `labelSmall`; escribir un `BocTextStyle(size: 18, …)` a mano— y ver
      cada una en rojo antes de revertirla. **Una prueba que no puede fallar no protege nada.**
- [X] T006 [US1] **FR-001, FR-003, D-401** `APP/Core/UI/Component/PublicationCard.swift`: consumir
      los cuatro peldaños en el `body` — sección de `labelSmall` a `Typography.section` (15),
      organismo de `labelMedium`/`textSecondary` a `Typography.organisation` (16) **en
      `textPrimary`**, título de `titleMedium` a `Typography.title` (20) **sin tocar el color**, y
      fecha de `bodySmall` a `Typography.date` (14). El organismo pierde el `semibold` al subir a
      `bodyLarge`, y es deliberado: cuerpo, caja y peso a la vez pesarían más que el título.
- [X] T007 [US1] **FR-002, FR-021, D-402, D-416** mismo fichero: el organismo se pinta con
      `.textCase(.uppercase)` —**nunca** `issuer.uppercased()`, que cambiaría el dato— y declara
      `.accessibilityLabel(Text(issuer))` con el texto **original**. Es lo que hace que lo que se
      oye no dependa de cómo se pinta: hay organismos de setenta caracteres y hay siglas. Se
      mantiene `lineLimit(2)`.

      **Esta tarea creció durante la implementación, y hay que decir por qué.** El volcado del
      árbol de T002 destapó que el BOC publica el organismo **dos veces** —en la ruta de
      clasificación y otra vez al principio del título, en mayúsculas— y que la tarjeta pintaba
      las dos. Subir el organismo a 16 puntos y a caja alta habría dejado dos líneas seguidas
      diciendo lo mismo, que es exactamente lo contrario de FR-001. Y es lo que el propietario
      pidió literalmente: «y debajo, **sin el nombre de la entidad**, el título de la
      publicación». Se añade `Publication.titleWithoutIssuer` —recorte exacto y sin distinguir
      mayúsculas, presentación y no dato— con cinco pruebas unitarias en
      `TEST/Domain/PublicationTests.swift`, y la spec gana **FR-021** (research.md D-416).
- [X] T008 [US1] **FR-004, FR-005, D-404** mismo fichero: fundir la fila de la fecha con la de las
      acciones en un `ViewThatFits(in: .horizontal)` de dos candidatos —la fila, con la fecha al
      inicio y las dos acciones al final; y la pila—. **El primer candidato lleva
      `Spacer(minLength: BocTheme.spacing.sm)` y NO `Spacer()`**: un espaciador sin longitud mínima
      tiene un ideal minúsculo, con lo que la fila «cabe» siempre y **no apila nunca**. Eso compila,
      no rompe ninguna prueba y **no lo caza nada**: se comprueba en el paso 8 del quickstart (T031).
- [X] T009 [US1] **FR-007** mismo fichero: añadir las vistas previas que hoy no tiene —«Con
      organismo largo» y **«Sin organismo»**—. La segunda es la que demuestra el caso límite de que
      el campo es opcional y que su línea **se omite**, sin dejar hueco. Hoy eso no se puede mirar
      sin arrancar la aplicación y buscar una publicación que lo cumpla.

### La cabecera editorial

- [X] T010 [P] [US1] **FR-010, FR-011, D-410**
      `APP/UI/Home/Component/BulletinHeaderView.swift`: añadir `var isCompact: Bool = false`.
      Compacta, oculta la fecha rotulada —con ella desaparece `home_header_date`, que es lo que la
      prueba afirma—, baja el relleno vertical de `spacing.lg` a `spacing.sm` y el rótulo de dos
      líneas a una. **La denominación NO cambia de peldaño y el recuento no se toca**: SwiftUI no
      interpola tamaños de fuente, los resuelve con un fundido, y FR-012 pide lo contrario. El valor
      por defecto es `false` para que las tres llamadas existentes no cambien. `[P]` porque es un
      fichero distinto del de la tarjeta y no depende de ella.
- [X] T011 [US1] **FR-012, D-411** mismo fichero: declarar
      `.animation(.easeInOut(duration: 0.2), value: isCompact)` **en la cabecera**, no en quien
      cambia el valor. Así la animación es una propiedad de la cabecera y no una copia de la
      duración que alguien tenga que mantener; y además no anima el primer valor que el `ScrollView`
      publica al aparecer, que puede no ser cero.
- [X] T012 [US1] Mismo fichero: **dos vistas previas nuevas**, una por estado —«Boletín del día,
      compacta» y la que ya hay, expandida—, para que la versión compacta sea revisable sin arrancar
      la aplicación. Las tres existentes no se tocan.

### El desplazamiento de Inicio

- [X] T013 [US1] **FR-009, FR-015, D-405** `APP/UI/Home/HomeContentView.swift`: sacar la cabecera,
      las filas de chips y el aviso del `ScrollView` y dejarlos como hermanos dentro del
      `VStack(spacing: 0)`; el `ScrollView` pasa a envolver **solo** `listing`, con el `refreshable`
      dentro. Las tres piezas condicionales siguen siendo ramas `if` del mismo `VStack`, de modo que
      **la posición del `ScrollView` entre sus hermanos no cambia** al aparecer o desaparecer la
      segunda fila —si cambiara, SwiftUI lo recrearía y se perdería la posición de lectura (FR-016)—.
- [X] T014 [US1] **FR-013, D-406** mismo fichero: la zona fija lleva
      `.background(BocTheme.colors.surface)` y un rectángulo de un punto con
      `BocTheme.colors.divider` superpuesto a su borde inferior. **No un `Divider()`**: ése pinta el
      color de separador del sistema y no el token del proyecto. Los dos colores ya existen, así que
      **la regla 7 no tiene nada nuevo que cazar**.
- [X] T015 [US1] **FR-015, D-407** mismo fichero: añadir
      `.scrollBounceBehavior(.always, axes: .vertical)` al `ScrollView` del listado. Hasta ahora el
      contenedor envolvía la pantalla entera y siempre rebotaba; con el listado solo, en los estados
      **vacío** y **de error** el contenido cabe, y sin rebote **no hay gesto de actualizar** justo
      donde reintentar es lo único que se puede hacer. No rompe ninguna prueba existente: se ve
      usando la aplicación.
- [X] T016 [US1] **FR-010, FR-012, D-408, D-409** mismo fichero: `@State private var isHeaderCompact`
      y `.onScrollGeometryChange(for: Bool.self)` sobre el `ScrollView` del listado. Se publica **un
      booleano, no el desplazamiento** —el cierre se evalúa en cada fotograma y SwiftUI solo entrega
      cuando el valor cambia—, y con **dos umbrales, no uno**: compacta por encima de **24** puntos
      y expande por debajo de **8**. Con un solo umbral, compactar agranda el contenedor, el sistema
      recorta el desplazamiento y la cabecera vuelve a crecer: **un salto visible** con el listado
      apenas desplazable. Las dos cifras van como constantes con nombre y comentario, no como tokens
      del tema: son un umbral de gesto, no un espaciado. El umbral es positivo a propósito, porque
      `refreshable` hace negativo el desplazamiento al tirar.
- [X] T017 [US1] **D-409** mismo fichero: corregir la **cabecera del fichero**, que hoy dice «The
      stateless rendering of the initial screen» y «No conoce el modelo de pantalla. Recibe estado y
      emite eventos». La segunda mitad sigue siendo cierta; la primera deja de serlo. Se explica que
      el único estado propio es efímero, describe dónde está el dedo y tiene el precedente exacto
      del panel lateral (D-319). **Una promesa escrita que deja de ser cierta es peor que no haberla
      escrito.**

### Las pruebas de interfaz

- [X] T018 [P] [US1] **FR-019, SC-002, SC-003** `UITEST/Home/HomeStickyHeaderUITests.swift`, nuevo:
      con `-boc-data-scenario=today`, desplazar el listado y afirmar que `home_header` **sigue
      existiendo**, que `home_header_date` **ha dejado de existir**, que `home_header_count` sigue,
      y que `home_section_chips` sigue alcanzable; volver arriba y afirmar que `home_header_date`
      reaparece. Y una segunda prueba: tocar un chip **sin haber subido antes** y comprobar que la
      lista cambia (SC-003).
- [X] T019 [US1] **D-412, D-416** `UITEST/Home/AccessibilityUITests.swift`,
      `testTheIssuerIsNotPaintedTwice`: contar «Consejería de Salud» **sin distinguir mayúsculas**.

      **Y resulta que era una prueba de regresión, no un retoque.** Con la comparación exacta
      estuvo en verde toda la 003 **por accidente**: el organismo se pintaba dos veces y las dos
      cajas no coincidían. Comprobado ejecutando: con el título sin recortar, la prueba corregida
      falla con «(2) is not equal to (1)»; con el arreglo de T007, pasa. Es exactamente lo que la
      constitución pide de todo defecto corregido — una prueba que **falla antes del arreglo**.
- [X] T020 [US1] **D-412, D-417** mismo fichero,
      `testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes`.

      **La predicción del plan era falsa y la aserción se queda como estaba.** El plan daba por
      hecho que comparar la etiqueta combinada por igualdad dejaría de valer, porque al apilarse la
      fila cambiaría el orden en que `.combine` concatena. No cambia: **las dos acciones son
      botones**, elementos propios del árbol, y nunca formaron parte de esa etiqueta; la fecha es
      el último texto tanto en fila como apilada. Comprobado ejecutando. Debilitar la igualdad a
      una contención habría hecho la prueba más floja a cambio de nada, así que **no se toca**: solo
      se anota en el fichero por qué la predicción falló.

      **Y a cambio aparece la prueba que el plan decía que no podía existir**:
      `testTheDateSharesItsRowWithTheActionsAndStacksWhenItDoesNotFit`, en el mismo fichero. El
      plan afirmaba que ninguna prueba automática puede ver **qué candidato elige** el
      `ViewThatFits`. Sí puede: se compara el solapamiento **vertical** entre `publication_date` y
      `publication_share` —al 100 % se solapan, al 200 % el botón queda estrictamente debajo—, que
      es una diferencia grande e inequívoca. Para eso la fecha gana el identificador
      `publication_date`, el único añadido al contrato (**D-404 corregida**).
- [X] T021 [P] [US1] **FR-016, D-413** `UITEST/Home/HomeBackgroundUITests.swift`: desplazar el
      listado, **guardar el origen vertical de `home_content`**, hacer el ciclo de segundo plano y
      afirmar que ese origen no ha cambiado y que la cabecera **sigue compacta**. Se mide sobre el
      listado y no sobre la enésima tarjeta porque es un `LazyVStack` y la que se estaba mirando
      puede no estar realizada al volver. Las dos aserciones que ya había —que el listado existe y
      que no ha vuelto el esqueleto— se conservan.
- [X] T022 [US1] **D-405** Volcar otra vez el árbol de accesibilidad y **compararlo con el de
      T002**: que `home_menu`, `home_search` y `home_info` no se hayan convertido en `home_root`
      —sería el identificador propagándose por falta de `.contain`—; que `home_header`,
      `home_header_date` y `home_header_count` sigan siendo tres elementos; que dentro de
      `home_section_chips` se sigan encontrando los `chip_*` uno a uno; y que `home_content` cuelgue
      ahora del `ScrollView` interior. Es el paso 6 del quickstart, y así se encontraron las tres
      caras de la trampa en la 003.

**Checkpoint**: ✅ la pantalla hace las dos cosas que se pedían.

- **285 pruebas sin interfaz en 41 suites, 0,493 s** — eran 275 en 40. Las diez nuevas: cinco de
  `PublicationCardTypographyTests` y cinco de `titleWithoutIssuer` en `PublicationTests`.
- **40 pruebas de interfaz, 298 s, cero fallos** — eran 34 en 252 s. Las seis nuevas: cuatro de
  `HomeStickyHeaderUITests`, el apilado de la fila y la posición de lectura.
- **El árbol de accesibilidad no se ha descolocado** (T022). Comparados
  `/tmp/boc-004-tree-antes.txt` y `/tmp/boc-004-tree-despues.txt`, el conjunto de identificadores
  difiere en **uno solo**: `publication_date`, que es la adición deliberada. `home_root`,
  `home_menu`, `home_search` y `home_info` siguen llamándose como se llamaban —no ha habido
  propagación—, `home_header` conserva su marco `{{0, 126}, {402, 107}}` con sus dos hijos
  distintos, los `chip_*` se siguen encontrando uno a uno dentro de `home_section_chips`, y
  `home_content` arranca en el mismo `y = 299`.
- **Y una cifra que no se esperaba: la tarjeta ha ENCOGIDO.** 199,7 puntos frente a 207,0, con los
  cuatro peldaños más grandes. Fundir dos filas en una devuelve más alto del que gana el texto.

---

## Phase 3: Cierre y puertas

**Purpose**: que los documentos digan lo que el código hace, y que las cuatro puertas queden
anotadas **con cifras**.

### Los documentos

Las cinco enmiendas caen en el **mismo fichero**, así que van en orden y **ninguna lleva `[P]`**.
Todas se firman **«feature 004 (iOS)»**: el §18.2 ya tiene una enmienda firmada «feature 004» que es
la de Android, y sin el paréntesis las dos serían indistinguibles (**D-414**).

- [X] T023 **FR-020, D-414** `DOC/` §6.3: «Reservar mayúsculas para categorías cortas» gana su
      excepción —el organismo emisor de la tarjeta— con el tope de dos líneas y el porqué: hay
      organismos de setenta y dos caracteres. Dejarlo sin escribir convertiría la regla en una
      contradicción silenciosa.
- [X] T024 **FR-020, D-401, D-402, D-404** `DOC/` §12.1: los cuatro peldaños nuevos —Organismo pasa
      a `BodyLarge` y `TextPrimary`, Título a `TitleLarge`, Metadatos a `BodyMedium`—, el organismo
      **en mayúsculas** y la fecha compartiendo fila con las acciones, con el apilado cuando no cabe.
- [X] T025 **FR-020, FR-006, D-414** `DOC/` §12.1: **añadir la etiqueta de sección**, que el
      apartado no menciona en ningún sitio. **Es una omisión, no un cambio**: la tarjeta la pinta
      desde la 003 por exigencia de FR-040 —el color agrupa nueve secciones en cinco, así que por sí
      solo no identifica nada— y el documento nunca la recogió. Se descubrió al inventariar qué
      contradecía este cambio.
- [X] T026 **FR-020, D-405** `DOC/` §14.6: «La cabecera editorial sale de la pantalla de forma
      natural» pasa a «se mantiene y se compacta», con su motivo. Los otros tres puntos del apartado
      **no cambian**: la barra superior fija y los filtros con fondo sólido y línea inferior ya
      estaban autorizados, y ahora se ejercen.
- [X] T027 **FR-020, D-414** `DOC/` §18.2 y §18.3: una nota que **no decide nada**. El §18.2 dice
      que la cabecera del detalle «se desplaza con el contenido» y el §18.3 fija su secuencia visual
      como sección → **título** → **organismo**; con esta feature, Inicio fija su cabecera y pone el
      organismo **antes** del título. Son **dos** divergencias entre dos pantallas que tienen que
      hablar el mismo idioma, y se deciden en la **005**, que es la del detalle.
- [X] T028 [P] **D-415** `specs/003-boletin-del-dia/contracts/internal-contracts.md`: corregir las
      **dos** firmas que ya no coincidían con el código antes de esta feature —
      `PublicationCard(publication:sectionName:colorGroup:onShare:onSave:)` →
      `PublicationCard(publication:onShare:onSave:)`, y `…onOpenDrawer…` → `…onOpenSections…` en
      `HomeContentView`—. **La spec de la 003 NO se toca**: está cerrada e integrada, y reescribirla
      convertiría su historia en algo que nunca ocurrió.
- [X] T029 [P] `CLAUDE.md`: la tabla de orden de portado gana la fila de la **004** con origen
      «— (nativa)» y las demás corren un número, con el detalle en la **005**. La tabla ya estaba
      desacoplada de la numeración de Android desde que la 013 se absorbió, así que esto no rompe
      ninguna correspondencia: la hace explícita.

### El recorrido a mano

Es donde viven las tres cosas que **ninguna prueba de esta casa puede ver**.

- [X] T030 Quickstart **paso 7**: la tarjeta con contenido real. Los cuatro datos se distinguen por
      tamaño; el organismo en mayúsculas encima del título; el título **no** es azul; la fecha y los
      dos iconos en la misma línea. Y a mano: una publicación **sin organismo** —que no deja hueco—
      y una con organismo largo —que se corta a dos líneas, y lo que se recorta es el organismo, no
      el título—.
- [X] T031 Quickstart **paso 8**: con el texto al 200 %, **la fila de la fecha se ha apilado**. Es
      lo único que demuestra que `ViewThatFits` está eligiendo de verdad y no quedándose siempre con
      el primer candidato (**D-404**, T008). Y con **VoiceOver encendido**: la tarjeta se recorre de
      un solo gesto y el organismo se oye **en su caja original**, no deletreado (**D-402**). Aquí
      se comprueba además, desde Ajustes y con la aplicación en segundo plano, la mitad de FR-016
      que ninguna prueba de interfaz alcanza: cambiar el tamaño de letra **relanza la aplicación**.
- [X] T032 Quickstart **paso 9**: los cuatro escenarios —`today`, `empty`, `failing`, `offline`—
      renderizan correctamente, comprobado sobre capturas del simulador. El aviso de falta de
      conexión queda dentro de la zona fija, encima del divisor.

      **El gesto de actualizar en sí NO se ha podido automatizar, y hay que decirlo.** Se
      intentaron dos vías y las dos fallan por el instrumento, no por el producto: (1) buscar el
      indicador de actualización tras el arrastre —no queda en el árbol, la actualización del
      escenario `empty` termina antes de que la prueba mire—; y (2) sostener el arrastre y medir el
      desplazamiento del contenido —**XCUITest devuelve el marco en reposo**, no el transitorio: la
      misma medición sobre el escenario `today`, donde el rebote existe con total seguridad, da
      también «299,0 no es mayor que 299,0»—. Ese contraste es la prueba de que falla la medición.
      El intento se retiró en vez de dejar una prueba floja o falsa. **Queda como comprobación
      manual del paso 9 del quickstart**, y anotado en `research.md` D-407 para que nadie repita la
      hora.
- [X] T033 Quickstart **paso 10**: la cabecera se queda, encoge y vuelve; los chips se alcanzan sin
      subir; con una sección con subsecciones sigue habiendo tarjetas desplazables; sin conexión el
      aviso sigue a la vista. **Y la histéresis**: con un listado apenas más alto que la pantalla, la
      cabecera **no parpadea** entre sus dos tamaños (**D-408**, T016).
- [X] T034 **SC-005** Quickstart **paso 11**: simulador del **iPhone SE (3.ª generación)** creado
      con `xcrun simctl create` —375 × 667, el más pequeño que soporta iOS 18, y **no viene
      creado**—. Medido con la sección 2 elegida —que añade la segunda fila de filtros— y el
      listado desplazado:

      | | |
      |---|---|
      | Zona fija, compactada | termina en **238,5** — cabecera 58,5 de alto, frente a 109 entera |
      | Banda visible del listado | de 238,5 a 584, donde empieza la barra de pestañas |
      | `publication_card_1` | **366,5 – 572,0** · entra **entera** |

      **SC-005 se cumple**, y con margen. Sin compactar, la cabecera sola se llevaría 109 de los
      667 y la tarjeta entera no cabría.

      **Y el SE destapó un defecto de las pruebas que el simulador de referencia no puede ver.**
      `testTheOfflineBannerStaysVisibleWhileScrolling` fallaba allí diciendo que el aviso había
      desaparecido. Lo que había desaparecido era la pantalla entera: el marco que XCUITest da a
      `home_content` es el de su **contenido** —665,5 puntos sobre una ventana de 667—, así que el
      centro desde el que `swipeUp()` sintetiza el gesto cae **sobre la barra de pestañas** y el
      arrastre cambiaba a la pestaña Buscar. Los cinco desplazamientos de
      `HomeStickyHeaderUITests` y `HomeBackgroundUITests` pasan a hacerse con **coordenadas de la
      ventana**. Las seis pruebas quedan en verde **en los dos dispositivos**, y la trampa está
      anotada en `CLAUDE.md`.

### Las cuatro puertas

**SC-007.** No hay CI, por la constitución 1.1.0: se ejecutan aquí y **el resultado se anota con
cifras y con su delta respecto a T001**. Un «pasa» no vale.

- [X] T035 Puerta 1 · Construcción sobre datos derivados nuevos → **en verde, 24 s**, cero errores.
      Eran **26 s** en T001: **−2 s**, que es ruido de una ejecución a otra.
      **Tras la corrección de la Phase 4: 26 s**, cero errores.
- [X] T036 Puerta 2 · Pruebas sin interfaz → **285 pruebas en 41 suites, 0,524 s**, todas en verde.
      Eran **275 en 40 suites, 0,504 s**: **+10 pruebas y +1 suite**. Las diez: cinco de
      `PublicationCardTypographyTests` —la suite nueva— y cinco de `titleWithoutIssuer` en
      `PublicationTests`. **Tras la Phase 4: 285 en 41 suites, 0,494 s** — sin cambio, porque la
      corrección es toda de vista.

      **`TEST/Core/BocThemeTests.swift` no se ha tocado**, comprobado con `git diff --stat main --`
      sobre ese fichero: sale vacío. Es la señal de que esta feature cambió el **uso** de la escala
      y no la escala.
- [X] T037 Puerta 3 · Pruebas de interfaz → **40 pruebas en 313 s**, cero fallos. Eran **34 en
      252,2 s**: **+6 pruebas y +61 s**. Las seis: cuatro de `HomeStickyHeaderUITests`, el apilado
      de la fila de la fecha y la conservación de la posición de lectura. Con `-testPlan`, nunca
      con `-only-testing` sobre el target de interfaz. **Tras la Phase 4: 42 pruebas en 322 s** —
      **+2**, las dos de regresión de la compactación continua.

      Y **las seis que desplazan se han ejecutado además en el iPhone SE**, en verde (T034).
- [X] T038 Puerta 4 · Sin avisos nuevos → **1 aviso**, el mismo que en T001: el preexistente de
      `appintentsmetadataprocessor` («No AppIntents.framework dependency found»), que es de Apple y
      ajeno al código. **Cero avisos del compilador**, y **cero nuevos**. **Tras la Phase 4: 1, el
      mismo.**

---

## Phase 4: Corrección — que la cabecera siga al dedo

**Purpose**: FR-012 no se cumplía. La cabecera fija se implementó como un **conmutador de dos
estados** y el propietario la rechazó al verla: «cuando el título se recoge no se siente ni suave ni
fluido, da como unos saltos… la funcionalidad es correcta pero visualmente queda raro».

**Tenía razón, y la cuenta lo explica**: la cabecera encogía **50,5 puntos de golpe** cuando el dedo
había recorrido **24**, y como vive fuera del área que se desplaza, arrastraba el listado con ella
—medido, **74,3 puntos de movimiento cuando la cabecera solo liberaba 49,3**—.

Es un defecto contra un requisito de esta feature, sobre una rama **sin integrar**: se arregla aquí,
no en una feature nueva.

- [X] T039 **FR-012, D-418** `APP/UI/Home/Component/BulletinHeaderView.swift`: `isCompact: Bool`
      pasa a **`collapse: CGFloat`** en 0…1, más un cierre `onCollapsibleHeight` que publica hacia
      arriba cuánto alto puede liberar. El relleno vertical se interpola de `spacing.lg` a
      `spacing.sm`; la fecha se repliega con alto y opacidad `×(1−collapse)` y **solo se retira del
      árbol al llegar a 1**, cuando ya es invisible — así la transición es continua y
      `home_header_date` sigue desapareciendo de verdad, que es lo que tres pruebas afirman.
- [X] T040 **D-410 corregida** mismo fichero: **se retira el cambio de `lineLimit` de 2 a 1**. Un
      recuento de líneas no se interpola, igual que no se interpola un cuerpo de fuente: salta. Era
      una de las cuatro causas del defecto, y la decisión que lo autorizaba afirmaba lo contrario.
- [X] T041 **D-411 retirada** mismo fichero: fuera `.animation(.easeInOut, value:)`. Con un valor
      continuo, una animación implícita hace que la cabecera **vaya por detrás del dedo**.
- [X] T042 Mismo fichero: el alto que se libera **se mide** con `onGeometryChange(for: CGFloat)`
      —disponible desde **iOS 16.0**, comprobado en la interfaz del SDK—, y se mide **la fila
      entera**, con su separación superior dentro. Medir solo el texto y forzarle ese alto después
      de haberle puesto la separación **la recorta**: la cabecera perdía ocho puntos —99 en vez de
      107— nada más aparecer. Lo destapó la instrumentación, no la revisión.
- [X] T043 **FR-012, FR-022, D-418** `APP/UI/Home/HomeContentView.swift`: fuera el booleano y los
      dos umbrales; entra `collapse` continua, con la distancia de colapso **igual** al alto que la
      cabecera libera —que es lo que hace que encoja al ritmo del dedo— y la asignación envuelta en
      `withTransaction(Transaction(animation: nil))`.
- [X] T044 **FR-022, D-418** mismo fichero: **el separador compensador** al principio del contenido
      del `ScrollView`, de alto `altoQueLibera × collapse`. Es la mitad que faltaba: sin él el
      contenido se mueve más rápido que el dedo **por construcción**, encoja como encoja la
      cabecera. Va **dentro del contenido** y no como relleno del contenedor, que dejaría una franja
      de fondo de hasta cincuenta puntos bajo el divisor.
- [X] T045 Mismo fichero: **se retira la histéresis y no se sustituye por nada**. Con el separador,
      contenido y contenedor crecen lo mismo, el desplazamiento máximo no cambia y la realimentación
      que obligaba a la banda se cancela sola. Un parche que desaparece al corregir la causa.
- [X] T046 Mismo fichero y `BulletinHeaderView`: vistas previas de la cabecera a **0, 0,5 y 1**, y
      cabeceras de fichero al día. El fotograma de en medio es justo el que con dos estados no
      existía.
- [X] T047 **FR-019** `UITEST/Home/HomeStickyHeaderUITests.swift`:
      `testTheHeaderTakesIntermediateSizesWhileScrolling` — la cabecera mide **82,0** a medio
      recorrido, entre 107,0 y 57,7, y a mitad de camino **la fecha sigue ahí, replegándose**.
      Imposible de pasar con dos estados. Necesita el escenario `offline`, que es el único con lista
      larga: con `today` son tres publicaciones y el listado toca fondo antes de tiempo.
- [X] T048 **FR-022** mismo fichero: `testTheListingMovesExactlyWhatTheHeaderGivesBack` — lo que el
      listado se mueve y lo que la cabecera libera tienen que ser **la misma cifra**. Con un
      arrastre **sin inercia** —sostenido antes de soltar—, porque si no se mide la deceleración.
- [X] T049 **Las dos en rojo antes del arreglo**, comprobado restaurando el mecanismo anterior:
      `testTheHeaderTakesIntermediateSizesWhileScrolling` falla porque a medio camino la fecha ya ha
      desaparecido de golpe, y `testTheListingMovesExactlyWhatTheHeaderGivesBack` falla con
      **«74,33 no es igual a 49,33 ±1,5»**, que es literalmente la cifra del defecto. Es lo que la
      constitución exige de toda corrección.
- [X] T050 Documentos: `spec.md` —FR-010 y FR-012 reescritos, **FR-022 nuevo**, FR-019 y SC-002
      ampliados—; `research.md` —**D-408 sustituida**, D-410 corregida, **D-411 retirada**, **D-418
      nueva**—; `plan.md` —la desviación de los umbrales retirada—; los contratos —el recorrido en
      vez de dos columnas—; `docs/diseno/especificaciones-diseno.md` §14.6; y el paso 10 del
      quickstart.

**Checkpoint**: ✅ la cabecera acompaña al gesto, medido y no sentido.

- **285 pruebas sin interfaz en 41 suites, 0,495 s** — sin cambio: la corrección es toda de vista.
- **42 pruebas de interfaz, 322 s, cero fallos** — eran 40. Las dos nuevas son las de arriba.
- **Las ocho que desplazan, también en verde en el iPhone SE.**
- **La cifra que resume la corrección**: el listado se movía 74,3 puntos cuando la cabecera liberaba
  49,3; ahora se mueve **49,3**.

---

## Dependencies & Execution Order

### Entre fases

- **Setup (1)**: sin dependencias, y **bloquea de verdad**: T001 y T002 dejan de poder medirse en
  cuanto se toca el primer fichero.
- **US1 (2)**: depende de Setup. Es la feature entera.
- **Cierre (3)**: depende de US1.

### Dentro de la historia

- **La tarjeta (T003…T009) y la cabecera (T010…T012) son independientes entre sí.** T010 lleva `[P]`
  por eso. El resto de cada bloque toca el mismo fichero y va en orden.
- **El desplazamiento (T013…T017) depende de la cabecera**: T016 escribe el booleano que T010
  consume.
- **Las pruebas de interfaz (T018…T022) dependen de todo lo anterior**, y T022 depende además de
  T002.
- T004 depende de T003; T005 de T004; T006 de T003.
- La prueba de una pieza va **con** la pieza. Ninguna tarea se cierra con su prueba en rojo, y
  **prohibido** `.disabled`.

### Paralelismo real

Poco, y es honesto decirlo: tres ficheros de producción no dan para repartir.

```bash
# Phase 2, los dos bloques independientes:
T003…T009 (PublicationCard.swift)   ·   T010…T012 (BulletinHeaderView.swift)

# Phase 2, las pruebas de interfaz, tres ficheros distintos:
T018 (HomeStickyHeaderUITests)  ·  T019+T020 (AccessibilityUITests)  ·  T021 (HomeBackgroundUITests)

# Phase 3, los documentos que no comparten fichero:
T028 (contratos de la 003)   ·   T029 (CLAUDE.md)
```

Las cinco enmiendas del documento de diseño (T023…T027) **no** se paralelizan: son el mismo fichero.

---

## Implementation Strategy

### MVP primero

1. Phase 1 completa. **No se toca un fichero antes de tener las cifras y el árbol de antes.**
2. T003…T009: la tarjeta. **Parar y mirarla** —paso 7 del quickstart— antes de seguir. La mitad de
   la feature ya está demostrable y no depende de nada de lo que viene.
3. T010…T017: la cabecera y el desplazamiento.
4. T018…T022: las pruebas de interfaz, y el árbol comparado.

### Riesgos anotados

- **Los dos sitios donde esta feature se rompe en silencio** son T008 y T016, y los dos están en el
  quickstart porque ninguna prueba los alcanza: un `Spacer()` sin `minLength` hace que la fila no
  apile nunca, y un solo umbral da un salto visible con el listado apenas desplazable.
- **El punto más frágil es T013**: quince funciones de prueba usan `home_content` como puerta de
  entrada, y si algo se descoloca en el árbol se descolocan todas a la vez. Por eso T002 existe.
- **T005 es la tarea que más se salta la gente** y es la que hace que FR-018 valga algo. Una prueba
  que no puede fallar no protege nada.
- **No hay punto de corte**: la feature no se puede partir en dos entregas, porque la tarjeta con
  jerarquía dentro de una pantalla que se desplaza entera sigue perdiendo de vista qué se está
  mirando. Es pequeña; se entrega entera.

### Integración

Cuando las cuatro puertas estén en verde, la feature está **terminada**, no integrada. El merge
`--no-ff` sobre `main` lo pide el propietario, y la rama **se conserva**.

---

## Notes

- `[P]` = ficheros distintos y sin dependencias entre sí. En esta feature hay **cinco** —T010, T018,
  T021, T028 y T029—, y ni una más.
- **No hay fase *Foundational***, y no es un olvido: no hay nada que desbloquear. Los tres ficheros
  de producción existen desde la 003 y no se crea ninguno.
- **No se añade ni una cadena al catálogo, ni un color, ni un espaciado, ni un peldaño a la escala.**
  Si alguna tarea acaba necesitando uno, es señal de que se ha entendido mal: se para y se revisa el
  plan.
- Las cifras de las puertas se escriben en T035…T038, y las de partida en T001. **Un «pasa» no
  vale**: es lo único que después permite saber si se ejecutaron.
- `AppContainer`, `HomeViewModel`, `HomeUiState`, `HomeView`, `MainView` y los dos planes de prueba
  **no se tocan**. Si una tarea los abre, algo se ha desviado del plan.
