# Investigación: la tarjeta con jerarquía y la cabecera fija (iOS)

Esta feature es la primera del proyecto que **no porta nada**. Las tres anteriores tenían una
feature de Android enfrente con diecisiete, doce y diecisiete decisiones técnicas que revisar una a
una; aquí no hay ninguna, porque el problema se vio mirando la pantalla que la 003 dejó funcionando
con publicaciones reales delante. No hay saldo de portado que hacer.

Lo que sí hay es un **saldo de superficie**: tres ficheros de producción, ninguno nuevo, ninguno
retirado. Cuando el cambio es tan pequeño la tentación es no escribir el porqué, y es justo cuando
más falta hace: dentro de un año, «los cuatro tamaños de la tarjeta» parecerá una elección estética
y nadie recordará que la mitad de ellos existe para que el ojo pueda descartar un anuncio sin
leerlo.

**Tres decisiones las tomó el propietario** antes de planificar y aquí se recogen, no se reabren: el
título se queda en `textPrimary`, la cabecera se queda fija **pero se compacta**, y el aviso de
falta de conexión va con la zona fija.

**Lo que sigue está verificado, no recordado.** Las tres API de SwiftUI que la feature estrena se
comprobaron en la interfaz del SDK instalado —`iPhoneSimulator26.5.sdk`—, con su anotación de
disponibilidad delante; los tamaños de los peldaños, contra `BocTypography.swift`; los
identificadores y las aserciones que se rompen, contra los ficheros de prueba que los contienen.

---

## D-401 · Qué peldaño usa cada dato, sin tocar la escala de catorce

**Decisión**: los cuatro datos de la tarjeta cambian de peldaño dentro de la escala tipográfica que
ya existe.

| Dato | Ahora | Pasa a | Por qué |
|---|---|---|---|
| Sección | `labelSmall` 11 / semibold | **`titleSmall` 15 / semibold** | Es lo primero que se mira para descartar, y a 11 puntos era un pie de página |
| Organismo | `labelMedium` 12 / semibold, `textSecondary` | **`bodyLarge` 16 / regular, `textPrimary`** | Quién publica es la mitad de la decisión de leer o no. Sube de tamaño **y** de color: en `textSecondary` seguiría pareciendo un metadato |
| Título | `titleMedium` 17 / semibold | **`titleLarge` 20 / semibold** | Es el dato, y tiene que ganar. El color **no se toca**: sigue en `textPrimary` |
| Fecha | `bodySmall` 12 / regular | **`bodyMedium` 14 / regular** | Se leía con esfuerzo, y el §6.3 del documento de diseño ya pedía no bajar de 12 |

**Lo que esto conserva, y es el motivo de hacerlo así**: `BocThemeTests` afirma que la escala tiene
**catorce** estilos y comprueba tres tamaños concretos. Esa prueba **tiene que seguir en verde sin
que nadie la edite**, y es la señal de que esta feature cambió el uso y no la norma. Si para agrandar
un título hubiera que inventar un peldaño, la escala dejaría de ser una escala y pasaría a ser una
lista de casos.

**Por qué el organismo pierde el `semibold`**: sube a 16 y va en mayúsculas. Los tres efectos juntos
—cuerpo, caja y peso— darían un bloque más pesado que el título, y el título es el dato. `bodyLarge`
es regular, y eso es exactamente lo que hace que las mayúsculas no griten.

**Alternativas descartadas**:
- **Subir solo el título y dejar los demás.** Es lo que pedía la lectura literal de la captura, pero
  no resuelve el problema: con la sección y el organismo pegados al mismo cuerpo, el ojo sigue sin
  saber por dónde empezar. La jerarquía es **relativa**; un solo dato grande no la crea.
- **Añadir un peldaño intermedio a la escala** —un 18 entre `titleMedium` y `titleLarge`—. Rompe la
  transcripción del §6.2 que la cabecera de `BocTypography.swift` promete, y estropea la única
  prueba que hoy protege la escala.

**Qué lo demuestra**: `PublicationCardTypographyTests` (D-403).

---

## D-402 · Las mayúsculas son de presentación, y el lector de pantalla no las oye

**Decisión**: el organismo se pinta con **`.textCase(.uppercase)`** y **declara su propia etiqueta de
accesibilidad con el texto original**, tal como está guardado.

**Motivo de lo primero**: transformar la cadena cambiaría el dato en el punto de uso. Lo guardado
seguiría en su caja original, pero cualquiera que copiara ese `Text` a otra pantalla se llevaría la
transformación con él. Compartir manda el título y el enlace, y la búsqueda —que llega en su
feature— compara contra `search_text`, que se normaliza al escribir: las dos siguen viendo el texto
original **porque el original nunca se tocó**.

**Motivo de lo segundo, y es el que no es obvio**: una caja alta es una decisión visual, y lo que un
lector de pantalla dice no debería depender de ella. Hay organismos de setenta caracteres y hay
organismos que son siglas; leer setenta caracteres en mayúsculas es, en el mejor caso, idéntico, y
en el peor, deletreado. Declarando la etiqueta con el texto original, **lo que se oye deja de
depender de cómo se pinta**, que es la misma línea que la spec traza en sus suposiciones.

**Efecto colateral que hay que anticipar**: la tarjeta se combina en un solo elemento
(`.accessibilityElement(children: .combine)`), y `.combine` construye su etiqueta a partir de las
etiquetas de los hijos. Con la etiqueta explícita puesta, la etiqueta combinada de la tarjeta
**conserva la caja original** y no cambia por este motivo. Aun así la prueba que la mira pasa a
comparar sin distinguir mayúsculas (D-412): la comparación es correcta bajo cualquiera de las dos
resoluciones, y afirmar lo que la prueba quería decir es mejor que afirmar lo que hoy resulta que
pasa.

**Alternativas descartadas**:
- **`issuer.uppercased()` en la vista.** Cambia el dato, y además rompe la etiqueta del lector de
  pantalla sin que nada lo diga.
- **Guardar el organismo ya en mayúsculas.** Es la versión peor de la anterior: contamina la base,
  obliga a una migración y deja la búsqueda comparando contra un texto que ya no es el del boletín.

**Qué lo demuestra**: `testTheIssuerIsNotPaintedTwice`, ampliada, y el paso 8 del quickstart con
VoiceOver encendido —porque lo que se oye no lo puede comprobar ninguna prueba de esta casa—.

---

## D-403 · Los cuatro peldaños se nombran en un solo sitio, y por eso FR-018 puede probarse

**Decisión**: la tarjeta declara sus cuatro estilos en un tipo anidado y los consume de ahí.

```swift
extension PublicationCard {
    /// Los cuatro peldaños de la tarjeta, en un sitio, para poder afirmarlos (FR-018).
    enum Typography {
        static var section: BocTextStyle { BocTheme.typography.titleSmall }
        static var organisation: BocTextStyle { BocTheme.typography.bodyLarge }
        static var title: BocTextStyle { BocTheme.typography.titleLarge }
        static var date: BocTextStyle { BocTheme.typography.bodyMedium }
        /// En orden de peso creciente: sección, organismo, título.
        static var hierarchy: [BocTextStyle] { [section, organisation, title] }
        static var all: [BocTextStyle] { [section, organisation, title, date] }
    }
}
```

> **Corregida al implementar, y la corrección importa más que la decisión.** Esta decisión se
> escribió afirmando que, por estar la tarjeta declarada `.accessibilityElement(children: .combine)`,
> **sus cuatro textos no existen en el árbol de accesibilidad** y por eso ninguna prueba de interfaz
> puede medirlos. **Es falso.** El volcado del árbol lo enseña: `.combine` cambia la *etiqueta* del
> contenedor, pero los `StaticText` hijos siguen ahí con su marco. Se podían medir. La decisión se
> mantiene porque sus otros dos motivos son buenos; el que se había escrito, no lo era.

**El hecho que lo obliga**, ya corregido: **la altura de un texto no mide su peldaño, mide su número
de líneas**. La sección, el organismo y la fecha ocupan una línea, así que su alto sigue al cuerpo;
el título ocupa tres o cuatro, así que su alto no es comparable con los otros tres. Una prueba de
interfaz que compare las cuatro alturas afirmaría algo que no significa lo que parece. Y hay dos
cosas más que desde la interfaz **no se ven de ninguna manera**: el **orden** —dos peldaños
adyacentes se diferencian en uno o dos puntos, y afirmarlo sobre alturas medidas sería frágil entre
versiones del sistema— y la **pertenencia a la escala**, que es FR-008 y no tiene traza visual
ninguna.

Las cifras del volcado lo cierran. Antes de esta feature: sección 12,7 puntos de alto, organismo
11,7, fecha 12,7 — **la sección y la fecha medían exactamente lo mismo**, que es el problema que
FR-001 describe—. Después: 16,3, 17,3 y 15,0. La diferencia entre dos de ellos es de un punto: una
aserción sobre eso sería una aserción sobre el renderizador.

**Lo que la prueba unitaria comprueba, y es más de lo que pedía el requisito**: que los cuatro
tamaños son **distintos dos a dos**; que `section < organisation < title`, que es el orden de peso
declarado; que la fecha **no baja de 12**, que es lo que el §6.3 prohíbe; que **los cuatro
pertenecen a `BocTheme.typography.all`**, con lo que FR-008 —«no se introduce un tamaño nuevo»— pasa
de ser una intención a ser una aserción; y que el organismo es **regular** y el título **semibold**,
para que subir de cuerpo y de caja no acabe tapando al título.

**Las cinco muerden.** Comprobado provocando cada violación a mano: igualar dos tokens pone en rojo
dos pruebas a la vez, intercambiar la sección y el título rompe el orden, bajar la fecha a
`labelSmall` rompe el suelo del §6.3, y escribir `BocTextStyle(size: 18, …)` a mano rompe la
pertenencia a la escala.

**Alternativas descartadas**:
- **Escribir los tokens en línea en el `body`**, como hasta ahora. Funciona y no se puede probar:
  igualar cuatro tokens es un cambio de una línea que nadie ve en una revisión, y FR-018 existe
  precisamente para eso.
- **Analizar el fuente con `SourceTree`**, que el proyecto ya usa para las reglas de arquitectura.
  Una regla textual diría que el fichero nombra cuatro tokens distintos, no que sean cuatro tamaños
  distintos ni que estén en el orden correcto. Es la herramienta pobre usada donde hay una rica.
- **Medir las cuatro alturas en una prueba de interfaz**, que resulta que sí se puede. Mide el
  número de líneas, no el peldaño; no ve el orden ni la pertenencia a la escala; y cuesta un
  simulador. La unitaria comprueba más, en cuatro milésimas.

---

## D-404 · Una sola fila para la fecha y las acciones, con `ViewThatFits` — y la trampa del `Spacer`

**Decisión**: la fecha y las dos acciones comparten fila, envueltas en
`ViewThatFits(in: .horizontal)` con dos candidatos: la fila, y la pila.

```swift
ViewThatFits(in: .horizontal) {
    HStack { date; Spacer(minLength: BocTheme.spacing.sm); actions }   // la fila
    VStack(alignment: .leading) { date; HStack { Spacer(minLength: 0); actions } }  // la pila
}
```

**Motivo**: el §31.3 del documento de diseño pide «apilar botones cuando sea necesario» y el §31.2
exige «separación suficiente entre acciones próximas». Con el texto al 200 %, «27 de agosto de 2026»
en `bodyMedium` más dos áreas táctiles de 48 puntos no caben en el ancho de una tarjeta: o se pisan,
o la fecha se recorta. Las dos salidas están prohibidas por FR-005.

**La trampa, y es la razón de que este apartado exista**: `ViewThatFits` mide el **tamaño ideal** de
cada candidato. Un `Spacer()` con `minLength` sin fijar tiene un ideal minúsculo, así que el primer
candidato «cabe» prácticamente siempre y el segundo no se elige nunca. Con
`Spacer(minLength: BocTheme.spacing.sm)` el ideal de la fila pasa a ser *fecha + 12 + acciones*, que
es una medida verdadera y es exactamente la que hay que comparar contra el ancho disponible. Sin
esto, la feature compilaría, no rompería ninguna prueba y **nunca apilaría**: el fallo se vería solo
poniendo el texto al 200 % y mirando.

**Alternativas descartadas**:
- **`if dynamicTypeSize >= .accessibility1 { … }`.** Decide por una talla de letra en vez de por el
  ancho que de verdad hay, así que se equivoca con un organismo corto en un teléfono grande y con
  uno largo en uno pequeño. `ViewThatFits` mide; un umbral de talla adivina.
- **Un `Layout` propio.** Es la respuesta correcta a un problema que aquí no existe: dos candidatos
  y un eje no justifican escribir un protocolo de disposición.
- **Dejar la fecha en su fila, como hasta ahora.** Es lo que el propietario pidió cambiar, y además
  deja media fila vacía debajo de un dato de doce puntos.

**Qué lo demuestra**, y aquí también hubo que corregirse: esta decisión se escribió diciendo que
una prueba solo puede afirmar que la tarjeta **crece**, no **qué candidato se eligió**, y que el
apilado había que verlo a mano. **Se puede afirmar.** La diferencia entre los dos candidatos es
grande e inequívoca en la geometría: compartiendo fila, el texto de la fecha y el botón de compartir
**se solapan verticalmente**; apilados, el botón queda estrictamente debajo. Medido:

| | Fecha | Compartir | |
|---|---|---|---|
| 100 % | y 451,2 – 466,2 | y 434,7 – 482,7 | se solapan → **fila** |
| 200 % | y 930,0 – 975,0 | y 979,0 – 1027,0 | no se solapan → **apilada** |

Lo comprueba `testTheDateSharesItsRowWithTheActionsAndStacksWhenItDoesNotFit`, y por eso la fecha
gana el identificador `publication_date`: es el único añadido al contrato de identificadores de esta
feature. Se mantiene además el paso 8 del quickstart, porque **una prueba geométrica dice que se
apiló, no dice que se lea bien**.

---

## D-405 · El desplazamiento se muda: de un `ScrollView` que lo envuelve todo a uno que envuelve el listado

**Decisión**: `HomeContentView` pasa a ser un `VStack(spacing: 0)` con la zona fija arriba y un
`ScrollView` que contiene **solo** el listado, con el `refreshable` puesto ahí.

**Motivo**: es literalmente lo que se pide. Lo que hay que decidir no es eso, sino **qué se lleva la
zona fija**, y son cuatro cosas: la barra superior, la cabecera editorial, las una o dos filas de
filtros y el aviso de falta de conexión. El aviso va con ellas por decisión del propietario y con un
motivo que se sostiene solo: habla de toda la pantalla —de que lo que se lee es lo último
descargado—, así que perderlo de vista al desplazar haría creer que se está leyendo lo de hoy.

**Lo que esto no rompe, y hay que comprobar que sigue sin romper**: la identidad estructural del
`ScrollView`. Las tres piezas condicionales de la zona fija —la cabecera opcional, la segunda fila
de filtros y el aviso— son ramas `if` dentro del mismo `VStack`, así que SwiftUI las resuelve cada
una en su propio contenido condicional y **la posición del `ScrollView` entre sus hermanos no
cambia** cuando aparecen o desaparecen. Si cambiara, SwiftUI recrearía el contenedor y la posición
de lectura se perdería al elegir una sección con subsecciones, que es justo lo que FR-016 prohíbe.
Se razona aquí y **se comprueba ejecutando** (D-413).

**El efecto en el árbol de accesibilidad, que es donde esta feature tiene su riesgo real**: los
identificadores no cambian de nombre, pero **cambian de sitio**. `home_content` deja de colgar del
`ScrollView` exterior y pasa a colgar del interior; `home_header`, `home_section_chips`,
`home_subsection_chips` y `home_offline_banner` dejan de estar dentro de un `ScrollView` y pasan a
estar dentro de un `VStack`. **Quince funciones de prueba de interfaz, repartidas en seis ficheros,
usan `home_content` como puerta de entrada.** El proyecto ya tiene documentadas las tres caras de
esta trampa —el identificador que se propaga a los hijos, el contenedor con hijos ocultos que no
entra en el árbol, y los dos contenedores declarados que no se anidan—, así que el paso 6 del
quickstart vuelca el árbol con `app.debugDescription` y lo compara, que es como se encontraron las
tres en la 003.

**Alternativas descartadas**:
- **`Section(header:)` con `pinnedViews: [.sectionHeaders]`** dentro del `ScrollView` que ya había.
  Es la forma idiomática de fijar una cabecera, y aquí es la equivocada por dos motivos: la cabecera
  se quedaría pegada al borde superior **desplazándose antes**, con el salto que eso da, y la
  cabecera fijada seguiría siendo contenido del `ScrollView`, de modo que compactarla cambiaría la
  altura del contenido y realimentaría al propio desplazamiento. Fuera del `ScrollView` no hay
  realimentación posible: compactar cambia el alto del contenedor, no el del contenido.
- **`safeAreaInset(edge: .top)`.** Consigue el mismo efecto visual metiendo la zona fija en el área
  segura del `ScrollView`, y a cambio mete su alto en `contentInsets`, de modo que el
  desplazamiento que hay que comparar contra el umbral **deja de empezar en cero** y hay que restarle
  el inset. Es una operación más en el camino que se ejecuta al desplazar, para no ganar nada.

---

## D-406 · La zona fija lleva fondo `surface` y un divisor propio, no un `Divider()`

**Decisión**: `.background(BocTheme.colors.surface)` sobre la zona fija y un rectángulo de un punto
con `BocTheme.colors.divider` superpuesto a su borde inferior.

**Motivo**: el §14.6 del documento de diseño lo pide desde el principio —«los filtros pueden fijarse
bajo la barra superior con fondo sólido y una línea inferior»—, y no es adorno: hoy las filas de
chips no declaran fondo, así que se ven sobre el `background` general; en cuanto dejen de
desplazarse, las tarjetas pasarían por debajo de unos chips transparentes y se leerían las dos cosas
a la vez. La barra superior ya usa `surface`, así que la zona fija queda de un solo color de arriba
abajo.

**Por qué no `Divider()`**: pinta el color de separador **del sistema**, no el token del proyecto.
Sería el mismo gris en una aplicación que declara su propia paleta y fija su apariencia, y el
proyecto tiene `colors.divider` para esto exactamente.

**Lo que no cambia**: la regla 7 caza la **construcción** de un color fuera de `Core/UI/Theme`, y
aquí no se construye ninguno: los dos se consumen de `BocTheme.colors`. La regla 8 seguiría intacta
aunque alguien quisiera «ajustar el contraste», porque leer el tema del sistema es precisamente lo
que caza.

---

## D-407 · `.scrollBounceBehavior(.always)`, o deslizar para actualizar deja de funcionar en dos estados

**Decisión**: el `ScrollView` del listado declara `.scrollBounceBehavior(.always, axes: .vertical)`.

**El hecho que lo obliga**: hasta hoy el `ScrollView` envolvía la pantalla entera, y la pantalla
entera —cabecera editorial incluida— siempre era más alta que la ventana, así que el rebote existía
siempre y el gesto de deslizar hacia abajo funcionaba en los cuatro estados. A partir de este cambio
el `ScrollView` contiene **solo el listado**, y hay dos estados en los que el listado no llena la
pantalla: el vacío y el de error. Con el comportamiento por defecto, un contenido que cabe no rebota,
y **si no rebota no hay gesto**: FR-015 se rompería exactamente en los dos estados donde volver a
intentarlo es lo único que se puede hacer.

**Por qué se escribe aquí y no se descubre luego**: es un fallo que no rompe ninguna compilación y
ninguna prueba existente, porque ninguna prueba de interfaz tira del listado hacia abajo. Se vería
usando la aplicación sin conexión, que es cuando menos gracia hace.

**Alternativas descartadas**:
- **Dar al contenido una altura mínima igual a la del contenedor.** Consigue el rebote a costa de un
  `GeometryReader` y de una altura calculada, y deja el estado vacío centrado en una caja invisible.
- **Poner el `refreshable` en otro sitio.** No hay otro sitio: el gesto pertenece al listado, que es
  lo que se actualiza.

**Qué lo demuestra**: el paso 9 del quickstart, con el escenario `empty` y con el `failing`.

> **Se intentó automatizarlo al implementar, y no se puede. Las dos vías, para que nadie repita la
> hora.**
>
> 1. **Buscar el indicador de actualización** tras el arrastre. No queda en el árbol: la
>    actualización del escenario `empty` termina antes de que la prueba mire, y el indicador de
>    `refreshable` no se expone como `activityIndicators` de forma fiable.
> 2. **Sostener el arrastre y medir el desplazamiento del contenido**, con
>    `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`. **XCUITest devuelve el marco
>    en reposo, no el transitorio**: el texto no se movía ni un punto. Lo que cierra el diagnóstico
>    es el experimento de control — la misma medición sobre el escenario `today`, donde el rebote
>    existe con total seguridad, da también «299,0 no es mayor que 299,0». Falla la medición, no el
>    rebote.
>
> El intento se **retiró** en lugar de dejar una prueba floja o falsa. Queda como comprobación
> manual, y esta nota es lo que impide que se vuelva a intentar sin saberlo.

---

## D-408 · `onScrollGeometryChange` publica un booleano con histéresis, no el desplazamiento

**Decisión**: el `ScrollView` del listado declara

```swift
.onScrollGeometryChange(for: Bool.self) { geometry in
    // Un booleano, no la cifra. Y con dos umbrales, no con uno.
    geometry.contentOffset.y > (isHeaderCompact ? expandBelow : compactAbove)
} action: { _, isCompact in
    isHeaderCompact = isCompact
}
```

**Disponibilidad, comprobada y no recordada**: `onScrollGeometryChange(for:of:action:)` está
declarada `@available(iOS 18.0, …)` en la interfaz del SDK instalado, igual que `ScrollGeometry`.
El objetivo de despliegue del proyecto es **iOS 18.0**, así que no hace falta ni una comprobación de
disponibilidad ni un camino de compatibilidad. Es el primer sitio del proyecto donde el suelo de
iOS 18 se aprovecha en lugar de solo respetarse.

**Por qué un booleano y no la cifra**: el cierre de transformación se evalúa en cada cambio de
geometría, es decir, en cada fotograma de desplazamiento. Si lo que se publica es el desplazamiento,
la cabecera se invalida sesenta veces por segundo para decir lo mismo. Publicando el resultado de la
comparación, SwiftUI solo entrega cuando el valor **cambia** —el tipo es `Equatable` por exigencia de
la firma—, y la cabecera se redibuja dos veces por recorrido en lugar de mil.

**Por qué dos umbrales y no uno**, que es la parte que no se ve sin pensarla: la cabecera está
**fuera** del `ScrollView`, así que compactarla no cambia el contenido, pero sí **agranda el
contenedor**. Con un listado apenas más alto que la pantalla, agrandar el contenedor reduce el
desplazamiento máximo, el sistema recorta el desplazamiento actual, el valor cae por debajo del
umbral y la cabecera vuelve a crecer. La secuencia **termina** —al crecer, el desplazamiento
recortado no vuelve a subir solo—, así que no es un bucle infinito; es un salto visible, y FR-012
pide justo lo contrario. Con una banda entre los dos umbrales, el retorno no puede alcanzar el de
bajada y el salto no ocurre.

**Los dos umbrales**: se compacta al pasar de **24 puntos** y se vuelve a expandir al bajar de **8**.
Las dos cifras van como constantes con nombre dentro de la vista, con su comentario, y **no** como
tokens del tema: no son espaciados ni tamaños del sistema de diseño, son un umbral de gesto, y el
documento de diseño no los declara ni debería. Está declarado en *Complexity Tracking* del plan.

**Por qué el umbral es positivo, y no cero**: `refreshable` hace que el desplazamiento se vuelva
negativo al tirar hacia abajo. Con un umbral en cero, tirar para actualizar tocaría el límite y la
cabecera parpadearía en mitad del gesto.

**Un detalle del tipo que conviene tener presente**: `ScrollGeometry` expone `contentOffset` y
`contentInsets` por separado, y el desplazamiento **no empieza en cero** cuando hay inset superior.
Aquí no lo hay —la zona fija es un hermano del `ScrollView`, no un inset suyo (D-405)—, así que
`contentOffset.y` empieza en cero. Si algún día la zona fija pasara a `safeAreaInset`, esta
comparación habría que corregirla sumando `contentInsets.top`, y por eso se escribe.

**Alternativas descartadas**:
- **`GeometryReader` con una `PreferenceKey`**, que es como se hacía antes de iOS 18. Funciona,
  publica una cifra en cada fotograma y obliga a escribir la clave, el reductor y el
  `onPreferenceChange`. Es tres veces más código para hacer peor lo mismo.
- **`ScrollPhase` con `onScrollPhaseChange`.** Dice si el dedo se mueve, no dónde está el contenido.
  Compactaría al empezar a desplazar aunque el desplazamiento fuera de dos puntos, y no sabría
  volver al llegar arriba.
- **Un solo umbral.** Es el salto descrito arriba, y se ve.

**Qué lo demuestra**: `HomeStickyHeaderUITests`, y el paso 7 del quickstart con un listado de dos o
tres publicaciones, que es donde la banda de histéresis se gana el sueldo.

---

## D-409 · El booleano es `@State` de la vista, no del modelo de pantalla

**Decisión**: `isHeaderCompact` es `@State private` de `HomeContentView`. `HomeUiState` no cambia y
`HomeViewModel` no se entera.

**Motivo**: es exactamente el mismo caso que el abierto/cerrado del panel lateral (D-319 de la 003),
y por las mismas tres razones: **es efímero** —no sobrevive a nada y no debe—, **nadie más lo
consulta** y **el modelo de pantalla no podría decidirlo**, porque depende de una geometría que solo
el `ScrollView` conoce. Subirlo al estado de la pantalla obligaría además a que cada cruce de umbral
fuera y volviera del modelo, que es trabajo en el actor principal a cambio de nada.

**Lo que hay que aceptar y decir**: `HomeContentView` deja de ser literalmente «sin estado», y su
propia cabecera lo afirma hoy. **La cabecera se corrige en el mismo cambio**; una promesa escrita que
deja de ser cierta es peor que no haberla escrito. El principio III de la constitución pide vistas
reutilizables sin estado, y esta desviación va declarada en *Complexity Tracking*.

**Lo que esto conserva**: la vista sigue siendo previsualizable y sigue sin conocer el modelo de
pantalla. El estado compacto tiene valor inicial definido y solo lo escribe el desplazamiento, así
que las tres vistas previas existentes siguen compilando sin cambiar una línea.

**Alternativas descartadas**:
- **`@Binding` desde `HomeView`.** El estado sube un nivel para que lo siga escribiendo la misma
  vista, y las vistas previas ganan un `.constant(false)` que no dice nada.
- **En `HomeUiState`.** Convierte una posición de dedo en estado de pantalla y obliga al modelo a
  publicar por algo que no puede comprobar. Además haría fallar la igualdad de `HomeUiState` en
  pruebas que hoy comparan estados enteros.

---

## D-410 · Qué repliega la cabecera compacta, y qué no

**Decisión**: `BulletinHeaderView` gana `var isCompact: Bool = false`. Compacta:

- **oculta la fecha rotulada** —con ella desaparece `home_header_date`, que es lo que la prueba
  afirma—;
- **reduce el relleno vertical** de `lg` (24) a `sm` (12);
- **baja el tope del rótulo** de dos líneas a una.

Y **no** cambia: la denominación sigue en `headlineLarge`, el distintivo del recuento sigue igual, y
el fondo sigue siendo `primary`.

**Motivo de lo que se va**: FR-011 exige conservar la denominación y el recuento, que son la
respuesta a «qué estoy viendo» y «cuánto hay». La fecha rotulada es el único elemento que puede irse
sin dejar la cabecera muda, y es además el más alto de los tres: una línea de texto más su
separación.

**Motivo de lo que se queda, y es el que cuesta más**: la tentación es bajar también la denominación
de `headlineLarge` a `headlineSmall`, que ahorraría otros ocho puntos. Se descarta porque **SwiftUI
no interpola tamaños de fuente**: un cambio de cuerpo se resuelve con un fundido, no con un
crecimiento, y FR-012 pide una transición gradual sin saltos. Ocultar una línea y reducir un relleno
sí anima limpiamente, porque las dos cosas son alturas.

**El valor por defecto es `false`**, y eso importa: la cabecera se usa hoy en tres vistas previas y
en una prueba, y ninguna tiene que cambiar. Se añaden dos vistas previas nuevas, una por estado, que
es lo que hace revisable la versión compacta sin arrancar la aplicación.

---

## D-411 · La transición se declara en la cabecera, no en el punto donde se cambia el valor

**Decisión**: `BulletinHeaderView` declara `.animation(.easeInOut(duration: 0.2), value: isCompact)`.
El `action:` del observador se limita a asignar el booleano.

**Motivo**: envolver la asignación en `withAnimation` ataría la animación al sitio donde hoy se
escribe el valor. Declarada en la cabecera, la animación es una propiedad de la cabecera: quien sea
que la compacte mañana —otra pantalla, otro gesto— la anima igual, y no hay una segunda copia de la
duración que alguien tenga que recordar mantener.

**Y hay un motivo de comportamiento**: con `withAnimation` en el observador, la animación arrancaría
también en el primer valor que el `ScrollView` publica al aparecer, que puede no ser cero. Declarada
con `value:`, solo anima los cambios posteriores al primer dibujado.

---

## D-412 · Las dos pruebas que se ponen rojas se arreglan diciendo lo que querían decir

**Decisión**: ninguna se desactiva, ninguna se comenta y ninguna se debilita.

**`testTheIssuerIsNotPaintedTwice`** cuenta cuántas veces aparece «Consejería de Salud» en la
etiqueta combinada de la tarjeta, y lo hace con una comparación **exacta**. Lo que la prueba quiere
decir es «el organismo se pinta una vez», y eso no depende de la caja: pasa a contar sin distinguir
mayúsculas. Es más fuerte que antes, porque ahora también cazaría el caso en que se pintara una vez
en cada caja.

**`testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes`** compara la altura de la tarjeta al 100 % y
al 200 % y, además, **compara la etiqueta combinada entre las dos**. Mover la fecha de fila cambia
el **orden** de los fragmentos que `.combine` concatena, y al 200 % la fila se apila, así que el
orden puede diferir entre los dos tamaños. La aserción de igualdad literal deja de comprobar lo que
quería —«no se ha recortado nada»— y pasa a comprobar el orden de una concatenación. Se sustituye
por lo que de verdad significa: que el organismo, el título y la fecha **siguen contenidos** en la
etiqueta a los dos tamaños, comparando por contención y no por igualdad.

**Por qué se escribe en el plan y no se descubre al ejecutar**: porque el reflejo, con la build en
rojo y la feature terminada, es relajar la aserción hasta que pase. Decidido en frío, la salida es
la contraria: la aserción se hace **más precisa**, no más laxa.

---

## D-413 · La posición de lectura se mide sobre el listado, no sobre la enésima tarjeta

**Decisión**: `HomeBackgroundUITests` pasa a desplazar el listado, guardar el origen vertical del
elemento `home_content`, hacer el ciclo de segundo plano y afirmar que **ese origen no ha cambiado**;
y de paso, que la cabecera sigue compacta.

**Motivo**: hoy la prueba solo comprueba que el listado sigue existiendo y que no ha vuelto el
esqueleto, que es lo que hacía falta cuando la pregunta era «¿se recarga?». Ahora la pregunta es
«¿se pierde el sitio?», y para eso hace falta medir. Medir sobre una tarjeta concreta no vale: el
listado es un `LazyVStack` y la tarjeta que se estaba mirando puede no estar realizada al volver.
**El marco del propio listado sí es un proxy exacto**: su origen vertical se vuelve negativo
conforme se desplaza, y no depende de qué celdas estén vivas.

**Qué cubre esto que antes no se cubría**: FR-016, y el riesgo concreto de D-405 —que SwiftUI recree
el `ScrollView` al cambiar el contenedor y la posición se pierda—.

**Lo que sigue sin cubrirse, y se dice**: FR-016 menciona también el cambio del tamaño de letra del
sistema. Cambiarlo desde una prueba de interfaz **relanza la aplicación**, así que no hay forma de
observar la conservación de la posición a través de ese cambio; se comprueba a mano en el paso 8 del
quickstart. Se escribe para que nadie deduzca una cobertura que no hay.

---

## D-414 · El documento de diseño se enmienda en cinco sitios, y uno de ellos es una omisión

**Decisión**: cinco enmiendas fechadas y firmadas en `docs/diseno/especificaciones-diseno.md`, con el
formato de bloque de cita que el documento ya usa.

| Apartado | Qué cambia | Por qué |
|---|---|---|
| **§6.3** | «Reservar mayúsculas para categorías cortas» gana su excepción: el organismo emisor de la tarjeta, con el tope de dos líneas | Hay organismos de setenta caracteres. Dejarlo sin escribir convertiría la regla en una contradicción silenciosa, que es la peor clase |
| **§12.1** | Los cuatro peldaños nuevos, el organismo en mayúsculas y en `TextPrimary`, y la fecha compartiendo fila con las acciones | Es el apartado que la feature contradice punto por punto. Sin enmendarlo, el documento y el código dirían cosas distintas |
| **§12.1** | **Se añade la etiqueta de sección**, que el apartado no menciona en ningún sitio | **Es una omisión, no un cambio.** La tarjeta la pinta desde la 003 por exigencia de FR-040 —el color agrupa nueve secciones en cinco, así que por sí solo no identifica nada—, y el documento nunca la recogió. Se descubrió al inventariar qué contradecía este cambio |
| **§14.6** | «La cabecera editorial sale de la pantalla de forma natural» pasa a «se mantiene y se compacta» | Es la frase que esta feature invierte. Los otros tres puntos del apartado **no cambian**: la barra superior fija y los filtros fijados con fondo sólido y línea inferior ya estaban autorizados, y ahora se ejercen |
| **§18.2 y §18.3** | Una nota, **sin decidir nada** | El §18.2 dice que la cabecera del detalle «se desplaza con el contenido» y el §18.3 fija su secuencia visual como sección → **título** → **organismo**. Con esta feature, Inicio fija su cabecera y pone el organismo **antes** del título. Son dos divergencias entre dos pantallas que tienen que hablar el mismo idioma, y **se deciden en la 005**, que es la del detalle. Anotarlas aquí es lo que impide que se descubran allí como una sorpresa |

**Por qué se enmienda el documento y no se deja el código divergiendo**: `CLAUDE.md` lo pide —«si
cambias algo acordado, actualiza también el documento»— y FR-020 lo exige. Un documento de diseño que
describe una pantalla que ya no existe deja de ser la fuente de verdad y pasa a ser un estorbo que
hay que ignorar cada vez.

**Cuidado con la numeración al escribir la firma**: el §18.2 ya lleva una enmienda firmada «feature
004» que es la **004 de Android** —el detalle—, y la 004 de este proyecto es esta. Las enmiendas
nuevas se firman **«feature 004 (iOS)»** para que las dos se distingan, y la nota del §18.2 dice
expresamente a qué feature de iOS traslada la decisión.

---

## D-415 · Se corrigen dos firmas de los contratos de la 003, y la 003 no se reescribe

**Decisión**: en `specs/003-boletin-del-dia/contracts/internal-contracts.md`, **dos** firmas
declaradas pasan a ser las que el código tiene, y que esta feature no cambia:

```swift
// Declarado                                                    // Lo que hay
PublicationCard(publication:sectionName:colorGroup:onShare:onSave:)
PublicationCard(publication:onShare:onSave:)

HomeContentView(state:onRefresh:onRetry:onSelect:onOpenDrawer:onSearch:onInfo:onShare:onSave:)
HomeContentView(state:onRefresh:onRetry:onSelect:onOpenSections:onSearch:onInfo:onShare:onSave:)
```

**La segunda se encontró al escribir esta misma investigación**, buscando qué firmas tocaba esta
feature. La primera se conocía; la segunda no, y aparecieron las dos porque se miró. Es el argumento
de que un contrato escrito y no comprobado envejece: **nada en el proyecto compara estas firmas con
el código**, y no se propone montarlo —serían siete líneas de análisis de texto para vigilar un
documento que se lee tres veces al año—; lo que se propone es mirarlo cada vez que una feature toque
una de estas vistas, que es lo que se acaba de hacer.

**Motivo**: **ninguna de las dos coincidía antes de esta feature**. Al implementar la 003 se vio que pasar el
nombre de la sección y el grupo de color desde fuera obligaba a cada una de las tres pantallas que
usan la tarjeta a resolver el catálogo por su cuenta, y a que las tres pudieran resolverlo distinto;
la tarjeta pasó a derivarlos por dentro de `publication.mostSpecificSectionCode`. La de
`HomeContentView` es más simple: el parámetro se llamó `onOpenDrawer` en el contrato y
`onOpenSections` en el código, porque el panel se llama «panel de secciones» en la interfaz y
«drawer» en la arquitectura. Los dos documentos se quedaron atrás. Se corrigen aquí porque es aquí
donde se ha mirado.

**Qué NO se hace, y es la parte importante**: la especificación de la 003 **no se toca**. Está
cerrada e integrada, y reescribir la especificación de una feature terminada convertiría su historia
en algo que nunca ocurrió. Lo que se corrige es un contrato que describe el código de hoy y que
estaba **mal**; lo que se sustituye —FR-039— se declara sustituido desde la spec de la 004, sin
tocar el texto de la 003. Son dos cosas distintas y conviene no confundirlas.

**Y en el mismo cambio, `CLAUDE.md`**: la tabla de orden de portado gana la fila de la 004 con
origen «— (nativa)» y las demás corren un número, de modo que el detalle pasa a la **005**. La tabla
ya estaba desacoplada de la numeración de Android desde que la 013 se absorbió en la 003, así que
esto no rompe ninguna correspondencia: la hace explícita.

---

## D-416 · El organismo se pintaba dos veces, y la prueba que lo vigilaba estaba verde por accidente

> **Decisión tomada durante la implementación**, no al planificar. Se escribe aquí, con las demás,
> porque el sitio de una decisión es el documento de decisiones y no el mensaje de un commit.

**Decisión**: `Publication` gana `titleWithoutIssuer`, y la tarjeta pinta eso. El recorte es
**exacto y sin distinguir mayúsculas**, sobre el texto anterior a los primeros dos puntos; un
prefijo que solo se parezca se deja intacto.

**Cómo apareció**: el paso T002 de las tareas manda volcar el árbol de accesibilidad **antes** de
tocar nada, para poder compararlo después. En ese volcado, la etiqueta de la primera tarjeta era

> `Sección Oposiciones, Consejería de Salud, CONSEJERÍA DE SALUD: Convocatoria de
> concurso-oposición para el acceso a plazas de Enfermería., 27 de agosto de 2026`

**El organismo, dos veces.** El BOC lo publica en la ruta de clasificación —de donde la regla 10 del
normalizador saca `issuer`— y otra vez al principio del título, en mayúsculas y seguido de dos
puntos. La tarjeta pintaba los dos desde la 003.

**Por qué nadie lo había visto**: existe una prueba llamada, literalmente,
`testTheIssuerIsNotPaintedTwice`. Comparaba **distinguiendo mayúsculas**, así que «Consejería de
Salud» y «CONSEJERÍA DE SALUD» no coincidían, el recuento daba uno y la prueba estaba en verde. Es
el caso de manual de una prueba que pasa por el motivo equivocado. Y el plan de esta feature ya
proponía corregir esa comparación —D-412— **creyendo que era un retoque de redacción**; resultó ser
la prueba de regresión de un defecto real.

**Por qué se arregla aquí y no se aplaza**: porque esta feature lo empeora. Con el organismo a
dieciséis puntos, en `textPrimary` y en caja alta, la tarjeta quedaría con **dos líneas seguidas
diciendo lo mismo**, una de ellas la más grande de la tarjeta. FR-001 —que los cuatro datos se
distingan para poder descartar sin leer— quedaría derrotado por la propia feature que lo pide.

**Y porque el propietario lo había pedido.** Su petición original dice, literalmente: «Junto debajo
que tienes el nombre de la entidad que hace la publicación en más grande y en mayúsculas. **Y debajo
sin el nombre de la entidad el título de la publicación.**» La especificación leyó ese «sin» como
«bajo» y escribió FR-002 —«situarse entre la etiqueta de sección y el título»—, que es la otra
lectura posible del mismo texto con erratas. Las dos son gramaticalmente posibles; solo una produce
una tarjeta legible, y es la que él escribió. La especificación gana **FR-021**.

**Dónde vive la regla**: en `Domain/Model/Publication.swift`, como propiedad calculada junto a
`mostSpecificSectionCode`. No en la vista, por tres razones: se prueba en cuatro milésimas en vez de
en un simulador; la pantalla de detalle de la 005 la va a necesitar igual; y es una lectura derivada
del dato, del mismo género que la que ya vive ahí.

**Alternativas descartadas**:
- **Ocultar la línea del organismo cuando el título ya lo lleva.** Deja el organismo solo dentro del
  título, a veinte puntos y mezclado con el asunto, que es justo la exploración por barrido que esta
  feature vino a hacer posible.
- **Recortar por parecido** —prefijo que empiece por el organismo—. «FRATERNIDAD MUPRESPA MATEPSS Nº
  275» empieza por «Fraternidad Muprespa», y recortarlo dejaría el título sin el número de la
  entidad, que es parte de su identificación oficial. **Ante la duda, el título entero.**
- **Normalizar al guardar**, quitando el prefijo en el normalizador. Cambia el dato: la búsqueda
  dejaría de encontrar por el organismo escrito en el título y compartir mandaría un asunto
  distinto del que el boletín publica. Es presentación, y se queda en presentación.

**Qué lo demuestra**: cinco pruebas unitarias en `PublicationTests` —el caso normal, el parecido, el
título sin dos puntos, el título que es solo el organismo y el caso sin organismo— y
`testTheIssuerIsNotPaintedTwice`, que **falla con «(2) is not equal to (1)» si se revierte el
arreglo**. Comprobado ejecutando, que es lo que la constitución pide de toda corrección.

---

## D-417 · Dos predicciones del plan eran falsas, y las dos se corrigen hacia arriba

**Lo que se decide**: cuando una predicción del plan no se cumple, se corrige el plan y **no** se
ajusta el código para que la predicción parezca cierta. Las dos de esta feature se corrigen dejando
las pruebas **más** fuertes, no menos.

**Primera: la etiqueta combinada no cambia de orden al apilarse la fila.** D-412 daba por hecho que
`testTheCardGrowsInsteadOfTruncatingAtLargeTextSizes` se rompería, porque `.combine` concatena los
fragmentos en orden y la fecha cambiaba de sitio. No se rompe: **las dos acciones son botones**,
elementos propios del árbol de accesibilidad, y nunca formaron parte de esa etiqueta —el volcado lo
enseña—; la fecha es el último texto tanto en fila como apilada. La aserción de igualdad **se queda
como estaba**: debilitarla a una contención la habría hecho más floja a cambio de nada. Lo único que
cambia es un comentario que dice por qué la predicción falló.

**Segunda: los textos de la tarjeta sí están en el árbol.** Está corregido arriba, en D-403.

**Por qué las dos merecen quedar escritas**: las dos venían de razonar sobre el árbol de
accesibilidad **de memoria** en vez de volcarlo. El proyecto ya tiene tres trampas documentadas de
esa misma familia, y las tres se encontraron volcando. La lección se repite: **sobre el árbol de
accesibilidad no se razona, se mira**. Por eso T002 existe, y por eso ha pagado el viaje dos veces
en una feature de tres ficheros.
