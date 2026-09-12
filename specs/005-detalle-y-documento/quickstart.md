# Quickstart: Del titular al documento oficial

**Feature**: `005-detalle-y-documento` | **Fase**: 1 | **Fecha**: 12 de septiembre de 2026

Cómo se valida esta feature de extremo a extremo. **No es la lista de tareas** —esa es `tasks.md`—:
es lo que hay que ejecutar y mirar para saber si está bien.

**Los pasos marcados 👁 no los cubre ninguna prueba automática.** Están aquí porque la alternativa es
que nadie los haga.

---

## Requisitos previos

```bash
# El simulador de referencia
xcrun simctl boot "iPhone 17 Pro"

# El teléfono más pequeño soportado NO viene creado
xcrun simctl create "iPhone SE (3rd generation)" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation

# Datos derivados FUERA del repositorio
DD=/tmp/boc-dd005
```

Sin `GoogleService-Info.plist` y sin `Config/Secrets.xcconfig` la aplicación **arranca igual** y las
pruebas pasan. Esta feature no lo cambia.

---

## 1 · Las cuatro puertas

```bash
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath $DD -quiet build

xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath $DD \
  -only-testing:BOCantabria-iosTests -quiet test

xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath $DD \
  -testPlan UITests -quiet test

# 4.ª puerta: el recuento de avisos se mide SIN -quiet, porque con él no se imprimen
xcodebuild ... build 2>&1 | grep -c "warning:"
```

Las cifras se anotan en `tasks.md`. **Un «pasa» no vale.**

---

## 2 · La regla 14, provocada a mano 👁

Es el paso que hace que la regla valga algo.

```bash
# 1. Meter la violación
echo "import PDFKit" >> BOCantabria-ios/UI/Detail/PublicationDetailContentView.swift

# 2. Ejecutar SOLO la prueba de reglas
xcodebuild ... -only-testing:BOCantabria-iosTests/ArchitectureRulesTests -quiet test
#    ↳ DEBE fallar, nombrando el fichero y la carpeta permitida

# 3. Quitarla y volver a ejecutar
```

**Repetir con la otra mitad**: en vez del `import`, escribir `let x: PDFDocument? = nil` en un fichero
de `UI/Detail/`. Las dos mitades tienen que poner rojo por separado: la de importaciones caza el
marco, la de referencias caza el tipo que se cuela por una firma.

---

## 3 · El árbol de accesibilidad, antes y después 👁

**Este es el riesgo número uno de la feature** y se mitiga comparando, no confiando.

```bash
# ANTES de tocar la tarjeta: poner un print(app.debugDescription) temporal en
# UITEST/Home/HomeStatesUITests.swift, ejecutar esa sola prueba con -boc-data-scenario=today,
# guardar la salida y retirar el print.
#   → /tmp/boc-005-tree-antes.txt

# DESPUÉS del cambio, lo mismo:
#   → /tmp/boc-005-tree-despues.txt

diff /tmp/boc-005-tree-antes.txt /tmp/boc-005-tree-despues.txt
```

**Lo que NO puede cambiar**: `publication_card_<n>` sigue siendo un elemento combinado con la misma
etiqueta; `publication_share` y `publication_save` siguen siendo elementos propios con su marco;
`publication_date` sigue teniendo marco propio. Lo único que debe aparecer de nuevo es el rasgo de
botón sobre la tarjeta.

Si la diferencia es mayor que eso, el mecanismo elegido no es el de **D-519** y hay que volver a él.

---

## 4 · El recorrido feliz 👁

```bash
xcrun simctl launch booted com.jrblanco.BOCantabria -boc-data-scenario=documentReady
```

1. Tocar una tarjeta → se abre el detalle **de esa** publicación.
2. La cabecera dice, **en este orden**: sección, título, organismo, fecha, distintivo.
3. **No hay barra de pestañas abajo**: hay barra de acciones, y no la tapa el indicador de inicio.
4. Desplazar: **la cabecera se va y las pestañas se quedan** pegadas bajo la barra superior.
5. Mirar el borde de las pestañas mientras pasa contenido por debajo: **fondo opaco y divisor**. Si se
   transparenta, falta lo de FR-012.
6. La pestaña Documento muestra la ficha y, debajo, **la primera página**.
7. «Abrir PDF oficial» → visor. Ampliar con dos dedos y desplazar.
8. **Intentar reducir todo lo posible**: el documento **no** puede encogerse a nada. Si se puede, el
   factor mínimo se fijó antes de asignar el documento (D-515).
9. Retroceder dos veces → el boletín, **en la misma posición y con la misma sección**.
10. Volver a entrar → el documento aparece **de inmediato**.

---

## 5 · Los desenlaces que fallan 👁

Un escenario por cada uno. En los cuatro, lo que **no** puede pasar es quedarse cargando.

```bash
xcrun simctl launch booted com.jrblanco.BOCantabria -boc-data-scenario=documentRejected
xcrun simctl launch booted com.jrblanco.BOCantabria -boc-data-scenario=documentTooLarge
xcrun simctl launch booted com.jrblanco.BOCantabria -boc-data-scenario=documentUnavailable
```

- **Rechazado**: mensaje comprensible + reintentar. **Y nada del contenido devuelto se pinta.**
- **Demasiado grande**: se detiene e informa. La memoria del proceso no se dispara.
- **Sin conexión**: explica que hace falta conexión + reintentar.
- **Salir a mitad de descarga**: volver a entrar y comprobar que el documento está **«no descargado»**,
  no «descargando» y **no en error**.

Y el que no tiene escenario, porque hay que provocarlo:

```bash
# Llenar el disco del simulador, o poner el directorio de documentos en solo lectura
chmod 555 "$(xcrun simctl get_app_container booted com.jrblanco.BOCantabria data)/Library/Caches/documents"
```
→ error con reintento, **nunca** cargando para siempre. Es STAB-002 visto desde fuera.

---

## 6 · La copia dañada 👁

Es STAB-001, y en la aplicación de origen **cerraba la aplicación**.

```bash
APP=$(xcrun simctl get_app_container booted com.jrblanco.BOCantabria data)
DOCS="$APP/Library/Caches/documents"

ls "$DOCS"                         # abrir antes una publicación para que haya algo

# (a) lateral vacío
: > "$DOCS"/<huella>.sha256
# (b) lateral truncado
printf 'abc' > "$DOCS"/<huella>.sha256
# (c) lateral ausente
rm "$DOCS"/<huella>.sha256
```

En los tres casos: **el documento se abre con normalidad y la aplicación no se cierra.** Y en el
registro consta el incidente **sin** el título, la dirección ni la clave.

---

## 7 · Compartir 👁

Los tres sitios, porque FR-038 dice que se comportan igual:

1. Desde la **tarjeta** del boletín, 2. desde el **detalle**, 3. desde el **visor**.

- Con el documento en caché → sale **el documento**, y el nombre del adjunto es legible
  (`2026-6695.pdf`), **no** la huella de sesenta y cuatro caracteres.
- Sin caché y con conexión → la hoja se abre al instante y, al elegir destino, el sistema enseña su
  indicador mientras se prepara.
- **En modo avión y sin caché** → se ofrece **el enlace**, con su explicación a la vista.
- Mandarse uno a sí mismo por AirDrop y **abrir el fichero recibido**: tiene que abrirse.

---

## 8 · Tamaño de letra al 200 % 👁

```bash
xcrun simctl launch booted com.jrblanco.BOCantabria \
  -boc-data-scenario=documentReady \
  -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL
```

- El **título completo** se lee, sin recortar y sin puntos suspensivos.
- Los dos botones de la barra de acciones **se apilan** en vez de solaparse o encogerse.
- Las acciones conservan su área táctil.

---

## 9 · El teléfono pequeño 👁

```bash
xcrun simctl boot "iPhone SE (3rd generation)"
```

- La barra de acciones **no tapa contenido** y queda por encima del área reservada.
- Sigue habiendo contenido legible y desplazable con un título de ciento treinta caracteres.
- Los gestos de desplazamiento en las pruebas se hacen con **coordenadas de la ventana**, no sobre el
  elemento: el marco que XCUITest da a un contenedor de desplazamiento es el de su **contenido**.

---

## 10 · Las cifras, medidas y no estimadas

```bash
# SC-002 y SC-003, con el hito nuevo
xcodebuild ... -testPlan UITests -only-testing:BOCantabria-iosUITests/PerformanceUITests -quiet test
```

**No cronometrar con `waitForExistence`**: el sondeo del árbol tiene granularidad de aproximadamente un
segundo y mediría el instrumento (D-525). Anotar en `tasks.md`:

| Criterio | Objetivo | Medido |
|---|---|---|
| SC-002 · documento en caché | < 1 s | |
| SC-003 · documento nuevo | < 10 s | |
| Descarga de 25 MB | dentro de SC-003 | |

**La última fila decide D-502**: si la iteración byte a byte no aguanta, se cambia a descarga nativa a
disco. Con la cifra delante, no por intuición.

---

## 11 · Atravesar la frontera de verdad, una vez 👁

Es la conclusión escrita en `CLAUDE.md`: lo que las pruebas de esta casa no pueden ver.

```bash
xcrun simctl launch booted com.jrblanco.BOCantabria          # sin escenario: la aplicación de verdad
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.jrblanco.BOCantabria"'
```

Abrir una publicación **real**, con el registro delante. Comprobar que las líneas dicen la fase, el
tamaño y el motivo, **y que no dicen ni el título, ni la dirección, ni la clave**.

---

## 12 · El documento de diseño 👁

Antes de dar la feature por terminada, las dos notas del 12 de septiembre que dicen «se decide en la
005» —apartados **18.2** y **18.3**— tienen que estar **sustituidas por la decisión y su motivo**. Una
nota que sigue preguntando algo que ya se respondió es peor que no tenerla.

Y el apartado **36**, cuya lista de comprobación del detalle todavía dice «tres pestañas».
