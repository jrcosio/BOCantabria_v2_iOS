# Quickstart: cómo se verifica esta feature

Doce pasos. Los cuatro primeros son las puertas de calidad, que son obligatorias. El 5 comprueba que
la prueba nueva muerde y el 6 que el árbol de accesibilidad no se ha descolocado, que es el riesgo
real de mover el `ScrollView`. Del 7 al 11 **se mira la pantalla**, que es donde se vio el problema
y donde viven las tres cosas que ninguna prueba de esta casa puede ver. El 12 deja los documentos al
día.

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
APP=com.jrblanco.BOCantabria
DD=/tmp/boc-dd            # datos derivados fuera del repositorio
```

---

## Paso 1 — Puerta 1 · Construcción

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" -quiet build
```

No hay CI, por la constitución 1.1.0. Se ejecuta aquí y **el resultado se anota con cifras en
`tasks.md`** —«30,21 s sobre datos derivados limpios»—, nunca con un «pasa».

## Paso 2 — Puerta 2 · Pruebas sin interfaz

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" \
  -only-testing:BOCantabria-iosTests -quiet test
```

Se anota el número de pruebas, el de suites, el tiempo **y el delta** respecto a las **275 en 40
suites** con las que se empieza la feature. La que se añade es
`PublicationCardTypographyTests`.

**`BocThemeTests` tiene que seguir en verde sin haberse tocado**, y eso es parte de la
comprobación: es la señal de que esta feature cambió el uso de la escala y no la escala.

```bash
git diff --stat main -- BOCantabria-iosTests/Core/BocThemeTests.swift   # debe salir vacío
```

## Paso 3 — Puerta 3 · Pruebas de interfaz

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" -testPlan UITests -quiet test
```

Con `-testPlan`, **nunca** con `-only-testing` sobre el target de interfaz. Se parte de **34
pruebas**; esta feature añade `HomeStickyHeaderUITests` y modifica dos.

**Las quince funciones que usan `home_content` como puerta de entrada son las que hay que mirar
primero si algo se pone rojo**, porque se descolocarían todas a la vez:

```bash
grep -rln "home_content" BOCantabria-iosUITests
```

## Paso 4 — Puerta 4 · Sin avisos nuevos

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" build 2>&1 | grep -c "warning:"
```

El único aviso admisible es el preexistente de `appintentsmetadataprocessor`, que es de Apple y
ajeno al código.

---

## Paso 5 — La prueba de la jerarquía muerde

**Una prueba que no puede fallar no protege nada.** Se provoca cada violación a mano, se comprueba
el rojo y se revierte. Es lo único que impide que dentro de un año alguien «unifique» los tokens de
la tarjeta y la deje como estaba.

| Violación que hay que provocar en `PublicationCard.Typography` | Debe fallar |
|---|---|
| Poner `organisation` y `title` en el mismo token | Sí — «distintos dos a dos» |
| Intercambiar `section` y `title` | Sí — el orden de peso |
| Poner `date` en `labelSmall` (11) | Sí — el §6.3 prohíbe bajar de 12 |
| Escribir `BocTextStyle(size: 18, lineHeight: 24, weight: .semibold)` a mano | Sí — **FR-008**: no pertenece a `BocTheme.typography.all` |

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" \
  -only-testing:BOCantabria-iosTests/PublicationCardTypographyTests -quiet test
```

## Paso 6 — El árbol de accesibilidad no se ha descolocado

Es el paso con más riesgo de la feature y el que se hace **volcando el árbol**, no leyendo el
código: así se encontraron las tres caras de la trampa en la 003. Se pone un punto de interrupción
—o un `print`— en cualquier prueba de interfaz y se mira:

```swift
print(app.debugDescription)
```

Lo que hay que ver, y en este orden:

- `home_root` contiene la barra superior, la zona fija y el listado.
- `home_menu`, `home_search` y `home_info` **siguen llamándose así** y no se han convertido en
  `home_root`: sería el identificador propagándose por falta de `.contain`.
- `home_header`, `home_header_date` y `home_header_count` siguen siendo tres elementos distintos.
- `home_section_chips` está, y **dentro** se siguen encontrando `chip_today`, `chip_1`… uno a uno.
- `home_content` está, ahora colgando del `ScrollView` interior.
- Y **no hay dos contenedores declarados anidados**: si uno desaparece, es eso.

## Paso 7 — La tarjeta, mirada con contenido real

```bash
xcrun simctl uninstall booted "$APP"
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination "$DEST" -derivedDataPath "$DD" -quiet build
xcrun simctl install booted "$DD/Build/Products/Debug-iphonesimulator/BOCantabria-ios.app"
xcrun simctl launch booted "$APP" -boc-data-scenario=today -AppleLanguages '(es)' -AppleLocale es_ES
```

- Los cuatro datos se distinguen **por tamaño**, y el ojo encuentra el título sin buscarlo.
- El organismo va **en mayúsculas**, encima del título, en color de texto principal.
- El título **no** es azul: es `TextPrimary`. Si se ve azulado, es efecto del tamaño, que es
  justamente lo que se acordó con el propietario.
- La fecha y los dos iconos están **en la misma línea**, la fecha al inicio y los iconos al final.
- Se busca a mano una publicación **sin organismo** —el campo es opcional— y se comprueba que no
  deja hueco donde iría el nombre.
- Se busca un organismo largo —«Consejería de Fomento, Vivienda, Ordenación del Territorio y Medio
  Ambiente», setenta y dos caracteres— y se comprueba que se corta **a dos líneas** y que lo que se
  recorta es el organismo, no el título.

## Paso 8 — El texto al 200 %, y lo que se oye

```bash
xcrun simctl launch booted "$APP" -boc-data-scenario=today \
  -AppleLanguages '(es)' -AppleLocale es_ES \
  -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL
```

- **La fila de la fecha se ha apilado.** Es lo único que demuestra que `ViewThatFits` está
  eligiendo de verdad: si sigue en una sola línea con el texto al 200 %, el primer candidato lleva
  un `Spacer()` sin `minLength` y **nunca** va a apilar (research.md D-404). Ninguna prueba
  automática ve esto.
- Las dos acciones conservan sus 48 puntos de área táctil y no se pisan.
- No se recorta ni el organismo, ni el título, ni la fecha.

Y con **VoiceOver encendido** (Ajustes → Accesibilidad → VoiceOver, o el atajo de tres toques):

- La tarjeta se recorre **de un solo gesto**, no de cuatro: el `.combine` sigue puesto.
- El organismo se **oye en su caja original**, no deletreado ni en mayúsculas (D-402). Es lo que no
  puede comprobar ninguna prueba de esta casa.

**Y lo que aquí no se cubre, dicho en voz alta**: FR-016 pide conservar la posición de lectura
también al cambiar el tamaño de letra del sistema. Cambiarlo **relanza la aplicación**, así que no
hay forma de observarlo desde una prueba de interfaz; se comprueba aquí, a mano, desde Ajustes con
la aplicación en segundo plano.

## Paso 9 — Deslizar para actualizar sigue vivo en los cuatro estados

El listado ya no envuelve la pantalla entera, y en dos de los cuatro estados **no llena la
ventana**. Si el rebote no está forzado, el gesto desaparece justo donde volver a intentarlo es lo
único que se puede hacer (D-407).

```bash
for s in today empty failing offline; do
  echo "— escenario $s"
  xcrun simctl launch booted "$APP" -boc-data-scenario=$s \
    -AppleLanguages '(es)' -AppleLocale es_ES
  sleep 6
  xcrun simctl terminate booted "$APP"
done
```

En los cuatro: se tira del listado hacia abajo y **aparece el indicador de actualización**. En
`empty` y en `failing` es donde se rompería.

## Paso 10 — La cabecera se queda, encoge y vuelve

Con el escenario `today`, que trae contenido de sobra:

- Se desplaza el listado: la cabecera azul, la barra superior y la fila de chips **siguen ahí**.
- La cabecera **ha encogido**: la fecha rotulada ya no está; la denominación y el distintivo del
  recuento sí (FR-011).
- La transición es **gradual**, sin salto (FR-012).
- Se vuelve arriba del todo: la fecha rotulada **reaparece**.
- Se toca un chip de sección **sin haber subido antes**: cambia la lista (SC-003).
- Se elige una sección con subsecciones —la 2, la 4, la 7 o la 8—: aparece la segunda fila dentro de
  la zona fija, el listado se encoge y **sigue habiendo tarjetas desplazables** (FR-017).
- Sin conexión, se desplaza: el aviso **sigue a la vista** (FR-014).
- **Y donde se gana el sueldo la histéresis**: con un listado apenas más alto que la pantalla —vale
  una sección poco poblada—, se desplaza despacio hasta el final y se comprueba que la cabecera **no
  parpadea** entre sus dos tamaños (D-408).

## Paso 11 — El teléfono más pequeño que la aplicación soporta (SC-005)

El objetivo de despliegue es iOS 18.0, así que el teléfono más pequeño soportado es el **iPhone SE
(3.ª generación)**: 375 × 667 puntos. No viene creado por defecto:

```bash
xcrun simctl create "iPhone SE (3rd generation)" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -derivedDataPath "$DD" -quiet build
```

Con la sección que **más filas de filtros añade** —una de las que tienen subsecciones—, y la
cabecera compactada, **tiene que quedar al menos una tarjeta completa visible**. Es el caso que
justificó que la cabecera encoja en vez de quedarse fija y entera: fija y entera se come unos
cuatrocientos de los seiscientos sesenta y siete puntos de alto.

## Paso 12 — Los documentos al día (FR-020)

- `docs/diseno/especificaciones-diseno.md`, **cinco enmiendas fechadas y firmadas «feature 004
  (iOS)»** —§6.3, §12.1 dos veces, §14.6 y la nota de §18.2/§18.3—. La firma lleva «(iOS)» porque el
  §18.2 ya tiene una enmienda firmada «feature 004» que es la de Android (D-414).
- `specs/003-boletin-del-dia/contracts/internal-contracts.md`, **las dos firmas corregidas**:
  `PublicationCard` y `HomeContentView` (D-415). **La spec de la 003 no se toca.**
- `CLAUDE.md`, la tabla de orden de portado: la 004 nueva con origen «— (nativa)» y las demás
  corridas un número, con el detalle en la **005**.
- `tasks.md` de esta feature, con **las cifras** de las cuatro puertas. Nunca un «pasa».

```bash
git diff --stat main -- docs/ CLAUDE.md specs/003-boletin-del-dia/
```
