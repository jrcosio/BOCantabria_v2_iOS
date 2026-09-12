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

- [ ] T001 Medir y anotar aquí mismo las **cifras de las cuatro puertas ANTES del cambio**, sobre la
      rama `004-tarjeta-y-cabecera` sin tocar: construcción, pruebas sin interfaz (número, suites y
      tiempo), pruebas de interfaz (número y tiempo) y recuento de avisos. Al cerrar la 003 eran
      **30,21 s · 275 pruebas en 40 suites en 0,471 s · 34 pruebas de interfaz en 246,3 s · 1 aviso
      ajeno**; si alguna no coincide, **eso ya es información** y se escribe. Es lo que hace que el
      delta de T036 y T037 signifique algo.
- [ ] T002 Volcar el **árbol de accesibilidad de Inicio antes del cambio** y guardarlo en
      `/tmp/boc-004-tree-antes.txt`: se pone un `print(app.debugDescription)` temporal en
      `UITEST/Home/HomeStatesUITests.swift`, se ejecuta esa sola prueba con
      `-boc-data-scenario=today` y se retira el `print`. Es **contra esto** contra lo que se compara
      en T022, y es el riesgo real de la feature: mover el `ScrollView` cambia de sitio cuatro
      contenedores y **quince funciones de prueba usan `home_content` como puerta de entrada**
      (**D-405**).

**Checkpoint**: las cifras de partida y el árbol de antes, anotados. Sin esto, el final de la
feature no se puede demostrar, solo afirmar.

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

- [ ] T003 [US1] **D-403** `APP/Core/UI/Component/PublicationCard.swift`: declarar el tipo anidado
      `PublicationCard.Typography` con `section`, `organisation`, `title`, `date`, y las dos
      colecciones `hierarchy` —los tres primeros, en orden de peso creciente— y `all`. Son
      propiedades **calculadas** que devuelven tokens de `BocTheme.typography`, no valores nuevos.
      Es lo que hace afirmable FR-018: la tarjeta está combinada en un solo elemento de
      accesibilidad, así que sus cuatro textos **no existen en el árbol** y ninguna prueba de
      interfaz puede medirlos.
- [ ] T004 [US1] **FR-018, FR-008, SC-001** `TEST/Core/PublicationCardTypographyTests.swift`: la
      prueba, con cuatro aserciones —los cuatro tamaños son **distintos dos a dos**;
      `section.size < organisation.size < title.size`; `date.size >= 12`, que es el suelo del §6.3;
      y **los cuatro pertenecen a `BocTheme.typography.all`**, con lo que «no se introduce un tamaño
      nuevo» deja de ser una intención—. Va junto a `BocThemeTests.swift` porque habla de la escala.
- [ ] T005 [US1] **Comprobar que la prueba muerde**, que es el paso 5 del quickstart: provocar a
      mano, sobre `APP/Core/UI/Component/PublicationCard.swift`, las cuatro violaciones —igualar `organisation` y `title`; intercambiar `section` y
      `title`; poner `date` en `labelSmall`; escribir un `BocTextStyle(size: 18, …)` a mano— y ver
      cada una en rojo antes de revertirla. **Una prueba que no puede fallar no protege nada.**
- [ ] T006 [US1] **FR-001, FR-003, D-401** `APP/Core/UI/Component/PublicationCard.swift`: consumir
      los cuatro peldaños en el `body` — sección de `labelSmall` a `Typography.section` (15),
      organismo de `labelMedium`/`textSecondary` a `Typography.organisation` (16) **en
      `textPrimary`**, título de `titleMedium` a `Typography.title` (20) **sin tocar el color**, y
      fecha de `bodySmall` a `Typography.date` (14). El organismo pierde el `semibold` al subir a
      `bodyLarge`, y es deliberado: cuerpo, caja y peso a la vez pesarían más que el título.
- [ ] T007 [US1] **FR-002, D-402** mismo fichero: el organismo se pinta con `.textCase(.uppercase)`
      —**nunca** `issuer.uppercased()`, que cambiaría el dato— y declara
      `.accessibilityLabel(Text(issuer))` con el texto **original**. Es lo que hace que lo que se
      oye no dependa de cómo se pinta: hay organismos de setenta caracteres y hay siglas. Se
      mantiene `lineLimit(2)`.
- [ ] T008 [US1] **FR-004, FR-005, D-404** mismo fichero: fundir la fila de la fecha con la de las
      acciones en un `ViewThatFits(in: .horizontal)` de dos candidatos —la fila, con la fecha al
      inicio y las dos acciones al final; y la pila—. **El primer candidato lleva
      `Spacer(minLength: BocTheme.spacing.sm)` y NO `Spacer()`**: un espaciador sin longitud mínima
      tiene un ideal minúsculo, con lo que la fila «cabe» siempre y **no apila nunca**. Eso compila,
      no rompe ninguna prueba y **no lo caza nada**: se comprueba en el paso 8 del quickstart (T031).
- [ ] T009 [US1] **FR-007** mismo fichero: añadir las vistas previas que hoy no tiene —«Con
      organismo largo» y **«Sin organismo»**—. La segunda es la que demuestra el caso límite de que
      el campo es opcional y que su línea **se omite**, sin dejar hueco. Hoy eso no se puede mirar
      sin arrancar la aplicación y buscar una publicación que lo cumpla.

### La cabecera editorial

- [ ] T010 [P] [US1] **FR-010, FR-011, D-410**
      `APP/UI/Home/Component/BulletinHeaderView.swift`: añadir `var isCompact: Bool = false`.
      Compacta, oculta la fecha rotulada —con ella desaparece `home_header_date`, que es lo que la
      prueba afirma—, baja el relleno vertical de `spacing.lg` a `spacing.sm` y el rótulo de dos
      líneas a una. **La denominación NO cambia de peldaño y el recuento no se toca**: SwiftUI no
      interpola tamaños de fuente, los resuelve con un fundido, y FR-012 pide lo contrario. El valor
      por defecto es `false` para que las tres llamadas existentes no cambien. `[P]` porque es un
      fichero distinto del de la tarjeta y no depende de ella.
- [ ] T011 [US1] **FR-012, D-411** mismo fichero: declarar
      `.animation(.easeInOut(duration: 0.2), value: isCompact)` **en la cabecera**, no en quien
      cambia el valor. Así la animación es una propiedad de la cabecera y no una copia de la
      duración que alguien tenga que mantener; y además no anima el primer valor que el `ScrollView`
      publica al aparecer, que puede no ser cero.
- [ ] T012 [US1] Mismo fichero: **dos vistas previas nuevas**, una por estado —«Boletín del día,
      compacta» y la que ya hay, expandida—, para que la versión compacta sea revisable sin arrancar
      la aplicación. Las tres existentes no se tocan.

### El desplazamiento de Inicio

- [ ] T013 [US1] **FR-009, FR-015, D-405** `APP/UI/Home/HomeContentView.swift`: sacar la cabecera,
      las filas de chips y el aviso del `ScrollView` y dejarlos como hermanos dentro del
      `VStack(spacing: 0)`; el `ScrollView` pasa a envolver **solo** `listing`, con el `refreshable`
      dentro. Las tres piezas condicionales siguen siendo ramas `if` del mismo `VStack`, de modo que
      **la posición del `ScrollView` entre sus hermanos no cambia** al aparecer o desaparecer la
      segunda fila —si cambiara, SwiftUI lo recrearía y se perdería la posición de lectura (FR-016)—.
- [ ] T014 [US1] **FR-013, D-406** mismo fichero: la zona fija lleva
      `.background(BocTheme.colors.surface)` y un rectángulo de un punto con
      `BocTheme.colors.divider` superpuesto a su borde inferior. **No un `Divider()`**: ése pinta el
      color de separador del sistema y no el token del proyecto. Los dos colores ya existen, así que
      **la regla 7 no tiene nada nuevo que cazar**.
- [ ] T015 [US1] **FR-015, D-407** mismo fichero: añadir
      `.scrollBounceBehavior(.always, axes: .vertical)` al `ScrollView` del listado. Hasta ahora el
      contenedor envolvía la pantalla entera y siempre rebotaba; con el listado solo, en los estados
      **vacío** y **de error** el contenido cabe, y sin rebote **no hay gesto de actualizar** justo
      donde reintentar es lo único que se puede hacer. No rompe ninguna prueba existente: se ve
      usando la aplicación.
- [ ] T016 [US1] **FR-010, FR-012, D-408, D-409** mismo fichero: `@State private var isHeaderCompact`
      y `.onScrollGeometryChange(for: Bool.self)` sobre el `ScrollView` del listado. Se publica **un
      booleano, no el desplazamiento** —el cierre se evalúa en cada fotograma y SwiftUI solo entrega
      cuando el valor cambia—, y con **dos umbrales, no uno**: compacta por encima de **24** puntos
      y expande por debajo de **8**. Con un solo umbral, compactar agranda el contenedor, el sistema
      recorta el desplazamiento y la cabecera vuelve a crecer: **un salto visible** con el listado
      apenas desplazable. Las dos cifras van como constantes con nombre y comentario, no como tokens
      del tema: son un umbral de gesto, no un espaciado. El umbral es positivo a propósito, porque
      `refreshable` hace negativo el desplazamiento al tirar.
- [ ] T017 [US1] **D-409** mismo fichero: corregir la **cabecera del fichero**, que hoy dice «The
      stateless rendering of the initial screen» y «No conoce el modelo de pantalla. Recibe estado y
      emite eventos». La segunda mitad sigue siendo cierta; la primera deja de serlo. Se explica que
      el único estado propio es efímero, describe dónde está el dedo y tiene el precedente exacto
      del panel lateral (D-319). **Una promesa escrita que deja de ser cierta es peor que no haberla
      escrito.**

### Las pruebas de interfaz

- [ ] T018 [P] [US1] **FR-019, SC-002, SC-003** `UITEST/Home/HomeStickyHeaderUITests.swift`, nuevo:
      con `-boc-data-scenario=today`, desplazar el listado y afirmar que `home_header` **sigue
      existiendo**, que `home_header_date` **ha dejado de existir**, que `home_header_count` sigue,
      y que `home_section_chips` sigue alcanzable; volver arriba y afirmar que `home_header_date`
      reaparece. Y una segunda prueba: tocar un chip **sin haber subido antes** y comprobar que la
      lista cambia (SC-003).
- [ ] T019 [US1] **D-412** `UITEST/Home/AccessibilityUITests.swift`,
      `testTheIssuerIsNotPaintedTwice`: contar «Consejería de Salud» **sin distinguir mayúsculas**.
      Es lo que la prueba quería decir desde el principio —«el organismo se pinta una vez»— y es más
      fuerte que antes, porque ahora también cazaría que se pintara una vez en cada caja. **No se
      silencia y no se debilita.**
- [ ] T020 [US1] **D-412** mismo fichero,
      `testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes`: la aserción que compara la etiqueta
      combinada al 100 % y al 200 % **por igualdad** deja de valer, porque al apilarse la fila
      cambia el orden en que `.combine` concatena. Se sustituye por lo que de verdad significa: que
      el organismo, el título y la fecha **siguen contenidos** en la etiqueta a los dos tamaños. La
      aserción sobre la **altura** no se toca: es la que cazó que `Font.system(size:)` no escalaba.
- [ ] T021 [P] [US1] **FR-016, D-413** `UITEST/Home/HomeBackgroundUITests.swift`: desplazar el
      listado, **guardar el origen vertical de `home_content`**, hacer el ciclo de segundo plano y
      afirmar que ese origen no ha cambiado y que la cabecera **sigue compacta**. Se mide sobre el
      listado y no sobre la enésima tarjeta porque es un `LazyVStack` y la que se estaba mirando
      puede no estar realizada al volver. Las dos aserciones que ya había —que el listado existe y
      que no ha vuelto el esqueleto— se conservan.
- [ ] T022 [US1] **D-405** Volcar otra vez el árbol de accesibilidad y **compararlo con el de
      T002**: que `home_menu`, `home_search` y `home_info` no se hayan convertido en `home_root`
      —sería el identificador propagándose por falta de `.contain`—; que `home_header`,
      `home_header_date` y `home_header_count` sigan siendo tres elementos; que dentro de
      `home_section_chips` se sigan encontrando los `chip_*` uno a uno; y que `home_content` cuelgue
      ahora del `ScrollView` interior. Es el paso 6 del quickstart, y así se encontraron las tres
      caras de la trampa en la 003.

**Checkpoint**: la pantalla hace las dos cosas que se pedían y las **34 + 2** pruebas de interfaz
están en verde. La feature es demostrable aquí; lo que queda es dejar constancia.

---

## Phase 3: Cierre y puertas

**Purpose**: que los documentos digan lo que el código hace, y que las cuatro puertas queden
anotadas **con cifras**.

### Los documentos

Las cinco enmiendas caen en el **mismo fichero**, así que van en orden y **ninguna lleva `[P]`**.
Todas se firman **«feature 004 (iOS)»**: el §18.2 ya tiene una enmienda firmada «feature 004» que es
la de Android, y sin el paréntesis las dos serían indistinguibles (**D-414**).

- [ ] T023 **FR-020, D-414** `DOC/` §6.3: «Reservar mayúsculas para categorías cortas» gana su
      excepción —el organismo emisor de la tarjeta— con el tope de dos líneas y el porqué: hay
      organismos de setenta y dos caracteres. Dejarlo sin escribir convertiría la regla en una
      contradicción silenciosa.
- [ ] T024 **FR-020, D-401, D-402, D-404** `DOC/` §12.1: los cuatro peldaños nuevos —Organismo pasa
      a `BodyLarge` y `TextPrimary`, Título a `TitleLarge`, Metadatos a `BodyMedium`—, el organismo
      **en mayúsculas** y la fecha compartiendo fila con las acciones, con el apilado cuando no cabe.
- [ ] T025 **FR-020, FR-006, D-414** `DOC/` §12.1: **añadir la etiqueta de sección**, que el
      apartado no menciona en ningún sitio. **Es una omisión, no un cambio**: la tarjeta la pinta
      desde la 003 por exigencia de FR-040 —el color agrupa nueve secciones en cinco, así que por sí
      solo no identifica nada— y el documento nunca la recogió. Se descubrió al inventariar qué
      contradecía este cambio.
- [ ] T026 **FR-020, D-405** `DOC/` §14.6: «La cabecera editorial sale de la pantalla de forma
      natural» pasa a «se mantiene y se compacta», con su motivo. Los otros tres puntos del apartado
      **no cambian**: la barra superior fija y los filtros con fondo sólido y línea inferior ya
      estaban autorizados, y ahora se ejercen.
- [ ] T027 **FR-020, D-414** `DOC/` §18.2 y §18.3: una nota que **no decide nada**. El §18.2 dice
      que la cabecera del detalle «se desplaza con el contenido» y el §18.3 fija su secuencia visual
      como sección → **título** → **organismo**; con esta feature, Inicio fija su cabecera y pone el
      organismo **antes** del título. Son **dos** divergencias entre dos pantallas que tienen que
      hablar el mismo idioma, y se deciden en la **005**, que es la del detalle.
- [ ] T028 [P] **D-415** `specs/003-boletin-del-dia/contracts/internal-contracts.md`: corregir las
      **dos** firmas que ya no coincidían con el código antes de esta feature —
      `PublicationCard(publication:sectionName:colorGroup:onShare:onSave:)` →
      `PublicationCard(publication:onShare:onSave:)`, y `…onOpenDrawer…` → `…onOpenSections…` en
      `HomeContentView`—. **La spec de la 003 NO se toca**: está cerrada e integrada, y reescribirla
      convertiría su historia en algo que nunca ocurrió.
- [ ] T029 [P] `CLAUDE.md`: la tabla de orden de portado gana la fila de la **004** con origen
      «— (nativa)» y las demás corren un número, con el detalle en la **005**. La tabla ya estaba
      desacoplada de la numeración de Android desde que la 013 se absorbió, así que esto no rompe
      ninguna correspondencia: la hace explícita.

### El recorrido a mano

Es donde viven las tres cosas que **ninguna prueba de esta casa puede ver**.

- [ ] T030 Quickstart **paso 7**: la tarjeta con contenido real. Los cuatro datos se distinguen por
      tamaño; el organismo en mayúsculas encima del título; el título **no** es azul; la fecha y los
      dos iconos en la misma línea. Y a mano: una publicación **sin organismo** —que no deja hueco—
      y una con organismo largo —que se corta a dos líneas, y lo que se recorta es el organismo, no
      el título—.
- [ ] T031 Quickstart **paso 8**: con el texto al 200 %, **la fila de la fecha se ha apilado**. Es
      lo único que demuestra que `ViewThatFits` está eligiendo de verdad y no quedándose siempre con
      el primer candidato (**D-404**, T008). Y con **VoiceOver encendido**: la tarjeta se recorre de
      un solo gesto y el organismo se oye **en su caja original**, no deletreado (**D-402**). Aquí
      se comprueba además, desde Ajustes y con la aplicación en segundo plano, la mitad de FR-016
      que ninguna prueba de interfaz alcanza: cambiar el tamaño de letra **relanza la aplicación**.
- [ ] T032 Quickstart **paso 9**: deslizar para actualizar en los **cuatro** escenarios —`today`,
      `empty`, `failing`, `offline`—. En `empty` y en `failing` es donde se rompería sin T015.
- [ ] T033 Quickstart **paso 10**: la cabecera se queda, encoge y vuelve; los chips se alcanzan sin
      subir; con una sección con subsecciones sigue habiendo tarjetas desplazables; sin conexión el
      aviso sigue a la vista. **Y la histéresis**: con un listado apenas más alto que la pantalla, la
      cabecera **no parpadea** entre sus dos tamaños (**D-408**, T016).
- [ ] T034 **SC-005** Quickstart **paso 11**: crear el simulador del **iPhone SE (3.ª generación)**
      —375 × 667, el teléfono más pequeño que soporta iOS 18 y que **no viene creado**— con
      `xcrun simctl create`, y comprobar que con la sección que más filas de filtros añade y la
      cabecera compactada **queda al menos una tarjeta completa visible**. Es el caso que justificó
      que la cabecera encoja en vez de quedarse fija y entera.

### Las cuatro puertas

**SC-007.** No hay CI, por la constitución 1.1.0: se ejecutan aquí y **el resultado se anota con
cifras y con su delta respecto a T001**. Un «pasa» no vale.

- [ ] T035 Puerta 1 · Construcción: `xcodebuild ... -quiet build` sobre datos derivados nuevos →
      _(anotar segundos y errores)_
- [ ] T036 Puerta 2 · Pruebas sin interfaz: `-only-testing:BOCantabria-iosTests` → _(anotar pruebas,
      suites, tiempo **y delta** respecto a T001)_. Y comprobar que
      **`TEST/Core/BocThemeTests.swift` no se ha tocado**: `git diff --stat main --` sobre ese
      fichero debe salir vacío. Es la señal de que esta feature cambió el uso de la escala y no la
      escala.
- [ ] T037 Puerta 3 · Pruebas de interfaz: `-testPlan UITests` → _(anotar pruebas, tiempo **y
      delta**)_. Con `-testPlan`, **nunca** con `-only-testing` sobre el target de interfaz.
- [ ] T038 Puerta 4 · Sin avisos nuevos: `grep -c "warning:"` → _(anotar el recuento)_. El único
      admisible es el preexistente de `appintentsmetadataprocessor`, que es de Apple y ajeno al
      código.

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
