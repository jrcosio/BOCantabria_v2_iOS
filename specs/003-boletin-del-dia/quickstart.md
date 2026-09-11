# Quickstart: cómo se verifica esta feature

Quince pasos. Los cuatro primeros son las puertas de calidad, que son obligatorias. Del 5 al 12 se
recorre la aplicación comprobando lo que ninguna prueba de esta casa puede ver. El 13 atraviesa la
frontera con el servicio real, y **es requisito, no cortesía** (FR-088). El 14 vuelve a medir el
arranque y el 15 pone al día los documentos.

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
`tasks.md`** —«258 pruebas en 0,31 s»—, nunca con un «pasa»: es lo único que después permite saber si
se ejecutó.

## Paso 2 — Puerta 2 · Pruebas sin interfaz

```bash
xcodebuild ... -only-testing:BOCantabria-iosTests -quiet test
```

Se anota el número de pruebas, el de suites, el tiempo **y el delta** respecto a las 116 con las que
se empieza la feature.

## Paso 3 — Puerta 3 · Pruebas de interfaz

```bash
xcodebuild ... -testPlan UITests -quiet test
```

Con `-testPlan`, **nunca** con `-only-testing` sobre el target de interfaz: el esquema usa planes de
prueba y el plan por defecto solo lleva el target unitario.

## Paso 4 — Puerta 4 · Sin avisos nuevos

```bash
xcodebuild ... -derivedDataPath "$DD" build 2>&1 | grep -c "warning:"
```

El único aviso admisible es el preexistente de `appintentsmetadataprocessor`, que es de Apple y ajeno
al código.

---

## Paso 5 — Las reglas nuevas muerden

**Una regla que no puede fallar es una regla que no protege nada.** Se provoca cada violación a mano,
se comprueba el rojo y se revierte:

| Regla | Violación que hay que provocar | Debe fallar |
|---|---|---|
| 6 ampliada | `import GRDB` en un fichero de `UI/` | Sí |
| 10 | Nombrar `DatabaseQueue` en `UI/Home/HomeViewModel.swift` **sin importar nada** | Sí — y es la que demuestra por qué la 6 no basta |
| 11 | Un `Date()` en `Data/Repository/PublicationRepositoryImpl.swift` | Sí |
| 12 | Un `Task.detached { }` en cualquier sitio | Sí |
| 24 (ejecución) | Añadir un borrado sobre `publications` en una consulta | Sí, y **también** si se escribe con un método de registro en vez de con SQL |

La última fila es la importante: es la que demuestra que D-324 no es un adorno sobre la regla textual.

## Paso 6 — Instalación limpia con conexión (US1, SC-002)

```bash
xcrun simctl uninstall booted "$APP"
xcodebuild ... -quiet build && xcrun simctl install booted "$DD/Build/Products/Debug-iphonesimulator/BOCantabria-ios.app"
xcrun simctl launch booted "$APP"
```

- Portada, después marcadores de carga, después publicaciones reales.
- La cabecera dice **«Edición del …»** con la fecha de la última edición y el recuento de anuncios.
- **Menos de 15 segundos** desde el toque hasta ver el boletín. Se cronometra.
- Ni un mensaje de error, aunque alguna fuente falle.

## Paso 7 — Lo guardado se ve al instante y sin conexión (US2, SC-001, SC-003)

Cerrar, activar el modo avión del simulador, volver a abrir.

- El mismo contenido, **de inmediato** —menos de 1 segundo desde que la pantalla aparece—, sin esperar
  ninguna descarga.
- Aviso de falta de conexión **que no tapa el contenido**.
- Deslizar hacia abajo: indicador discreto, el contenido **permanece visible**, y al terminar sin
  novedades no aparece ningún error.

## Paso 8 — La caché no se resincroniza sin motivo (FR-023)

Cerrar y volver a abrir antes de treinta minutos. En el registro **no** debe aparecer una
sincronización nueva:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.jrblanco.BOCantabria"'
```

Las líneas dicen fase, número de fuentes, bytes y motivo del fallo. **Ni un título, ni un organismo.**

## Paso 9 — Las dos filas de chips (US3, FR-045 … FR-056)

- Primer chip: dice **«Boletín de hoy»**, no «Todo».
- Tocar «Personal» (sección 2): la lista pasa a la sección completa **y** aparece la segunda fila, en
  un solo toque.
- Elegir «2.2»: la segunda fila la marca **y la 2 sigue marcada arriba**.
- Tocar «Disposiciones» (sección 1, sin subsecciones): la segunda fila **desaparece**, sin dejar hueco
  ni dar un salto brusco.
- Volver al primer chip: la segunda fila desaparece y vuelve el boletín del día.

## Paso 10 — El panel de secciones (US3, FR-057 … FR-068, SC-008)

- Se abre **solo** con el icono de menú. Comprobar además que **deslizar desde el borde no lo abre**,
  que es la decisión de D-319 y no un descuido.
- Cabecera con escudo, «BOC Cantabria» y la flecha **al final de la fila**.
- **No hay campo de filtro.**
- Nueve secciones con su número y su nombre; las cuatro con subsecciones se despliegan y se contraen.
- Se cierra deslizando, tocando fuera y con la flecha. La flecha **no navega** y **no cambia la
  selección**.
- Cualquier subsección se alcanza en **tres toques como máximo**.
- Con el panel desplegado del todo, se puede recorrer entero.

## Paso 11 — Las anomalías conocidas del servicio (FR-009, SC-007)

| Qué se elige | Qué tiene que verse |
|---|---|
| 8.1 Subastas | Estado **vacío con mensaje propio**. Ningún error |
| 4.3 Seguridad Social | Nueve publicaciones con fecha de 2021 y el rótulo «Última publicación: …» |
| 8.2 y 9 | Publicaciones de 2024, sin aviso ninguno |

El rótulo es justo lo que evita que una fecha de hace dos años se lea como un fallo.

## Paso 12 — Ninguna acción deja sin respuesta, y nada se recorta (US4, SC-009, SC-010)

- Los tres destinos de la barra inferior llevan a alguna parte; Buscar y Guardados dicen
  «Próximamente» con el aspecto de la aplicación.
- La lupa avisa; el icono de información está y no hace nada; compartir abre la hoja del sistema con
  el enlace; guardar avisa; **tocar el cuerpo de la tarjeta no navega**.
- El gesto de volver desde Inicio no hace reaparecer la portada.
- Con el tamaño de letra del sistema al **200 %**: las tarjetas crecen y **no se recorta** el
  organismo, el título ni la fecha. Y al cambiarlo, **no se pierde la posición de lectura**.
- Y las tres trampas que en Android solo aparecieron en el dispositivo: que el organismo no salga
  **dos veces** en la tarjeta, que no haya un hueco de área segura sobre el escudo, y que el panel no
  tenga un tinte que no es suyo.

## Paso 13 — La frontera real, atravesada de verdad (FR-088, SC-013)

**Es requisito.** Todas las pruebas de esta casa usan dobles en el límite con el servicio, y los
defectos que de verdad rompieron el Android estaban justo al otro lado. Con conexión y la base
vacía, se sincroniza y se anotan las cifras:

| Medida | Referencia de Android, 29-ago-2026 |
|---|---|
| Fuentes que respondieron | 19 de 19 |
| Publicaciones recibidas | 1.709 |
| Aceptadas / rechazadas | 1.709 / 0 |
| Sin identificador en el enlace | 0 |
| Clasificación que no corresponde a su fuente | 0 |
| Con orden anómalo de componentes | **8, las ocho del feed 4.3** |
| Identificadores repetidos entre fuentes | 0 |
| Fuente vacía | 8.1, respuesta válida |

Si alguna de esas cifras sale muy distinta, **el analizador o el normalizador tienen un defecto**, no
el servicio. Y si la 4.3 o la 8.1 producen un mensaje de error o descartan una publicación válida, hay
un defecto seguro.

Para inspeccionar la base:

```bash
DB=$(xcrun simctl get_app_container booted "$APP" data)/Library/Application\ Support/boc.db
sqlite3 "$DB" "SELECT COUNT(*) FROM publications;"
sqlite3 "$DB" "SELECT MAX(publication_date), COUNT(*) FROM publications
               WHERE publication_date = (SELECT MAX(publication_date) FROM publications);"
sqlite3 "$DB" "SELECT section_code, COUNT(*) FROM publications GROUP BY section_code ORDER BY 1;"
sqlite3 "$DB" "SELECT COUNT(*) FROM publications WHERE warnings LIKE '%categoryOrderUnreliable%';"
sqlite3 "$DB" "SELECT COUNT(*) FROM publications WHERE document_url NOT LIKE 'https://%';"
```

**Hay que copiar los tres ficheros**, no solo el primero: `boc.db`, `boc.db-wal` y `boc.db-shm`.
Copiar solo la base deja fuera el diario y da un recuento corto. Es un error de medición que ya se
cometió una vez.

Y una comprobación que cierra el paso 5 desde el otro lado: tras cinco sincronizaciones seguidas, el
recuento de `publications` **no puede bajar** y no puede haber claves repetidas (SC-004, SC-005).

## Paso 14 — El arranque se vuelve a medir (D-329)

Esta feature mete abrir un fichero y migrarlo en el camino del arranque. La cifra se **mide** con
`XCTApplicationLaunchMetric`, cinco tomas, y se anota junto a los 815 ms anteriores. El objetivo sigue
siendo menos de 2 s.

## Paso 15 — Los documentos, al día

- **`docs/diseno/especificaciones-diseno.md`**: anotar las desviaciones propias de iOS con su fecha y
  su motivo —tres destinos mientras no existan los avisos, y la tarjeta de alertas del panel en
  suspenso—, y corregir los apartados **32** y **36**, que siguen transcribiendo el microcopy y el
  checklist que las enmiendas de 14.4 y 16 dejaron sin efecto.
- **`CLAUDE.md`**: retirar la 013 del orden de portado explicando por qué se absorbe, y añadir las
  trampas nuevas —el aislamiento por defecto, el delegado débil, el texto troceado, el booleano del
  analizador, el panel siempre montado, la cadena SQL invisible para el motor de reglas—.
- **`README.md`**: su tabla de estado se quedó en la 001. Se pone al día con las cifras de esta
  feature.

---

## Condición de aceptación

La feature está **terminada** cuando los quince pasos están hechos, las cuatro puertas en verde con
sus cifras escritas en `tasks.md`, y las cifras del paso 13 anotadas.

**Terminada no es integrada.** El `git merge --no-ff` sobre `main` lo pide el propietario, y la rama
se conserva.
