# Quickstart — Feature 015: Buscar con solo filtros

Cómo se comprueba que esta feature hace lo que dice. Dos partes: las cuatro puertas automáticas y el
recorrido manual, que aquí importa porque dos de las cosas que se corrigen —el destello y el recuento
de analítica— son cuestión de **cuándo** ocurre algo, y eso se ve mejor con la aplicación delante.

---

## 0. Preparación

Java no está en el `PATH`; se usa el JBR de Android Studio:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

Antes de la tanda instrumentada, y **solo** para ella:

```bash
adb shell settings put secure navigation_mode 0   # tres botones; con gestos algunas medidas dan cero
export ANDROID_SERIAL=emulator-5554               # un solo destino aunque haya un móvil enchufado
```

---

## 1. Iterar: el subconjunto que esta feature toca

```bash
./gradlew :app:testDebugUnitTest --tests "*Search*"
```

Cubre `SearchQueryTest`, `SearchPublicationsUseCaseTest`, `SearchRepositoryImplTest`,
`PublicationSearchDaoTest`, `SearchViewModelTest` y `SearchFlowIntegrationTest`. Tarda un par de
minutos porque los dos últimos son Robolectric.

**Las dos pruebas que tienen que estar en rojo antes del cambio y en verde después**, para cumplir la
regla de regresión de la constitución:

```bash
./gradlew :app:testDebugUnitTest --tests "*SearchViewModelTest*applying a filter with nothing typed*"
./gradlew :app:testDebugUnitTest --tests "*SearchViewModelTest*reported with the count the store answered*"
```

La primera falla hoy porque `isRunnable` no mira los filtros. La segunda falla hoy porque el evento se
dispara con el resultado viejo y la huella bloquea el real; **si se escribe sin `advanceUntilIdle()`
antes de teclear, pasa hoy y no prueba nada**: la carrera necesita que `results` haya emitido una vez.

---

## 2. Las cuatro puertas, en orden

```bash
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
./gradlew :app:connectedDebugAndroidTest
./gradlew :app:lintDebug
```

Informes: `app/build/reports/tests/testDebugUnitTest/index.html` y
`app/build/reports/lint-results-debug.html`.

**La tanda instrumentada tarda unas dos o tres horas**, no trece minutos; está medido y anotado en
`CLAUDE.md`. Lánzala en segundo plano. Para la única clase instrumentada que esta feature toca:

```bash
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.jrblanco.boccantabria.ui.search.SearchContentTest
```

---

## 3. Lo que las pruebas automáticas cubren

| Qué | Dónde | Tipo |
|---|---|---|
| Un filtro solo basta; una letra sola no; el orden no cuenta | `SearchQueryTest` | unitaria |
| Con filtros y sin texto se llama al almacén con el mismo tope | `SearchPublicationsUseCaseTest` | unitaria |
| Sin texto el patrón es `%%` y los filtros viajan | `SearchRepositoryImplTest` | unitaria |
| Sin texto un filtro devuelve todas sus filas, también las de `search_text` vacío | `PublicationSearchDaoTest` | Robolectric |
| Aplicar un filtro sin texto muestra resultados (**regresión**) | `SearchViewModelTest` | unitaria |
| Borrar el texto con filtro mantiene la lista; quitar el último filtro vuelve al inicial | `SearchViewModelTest` | unitaria |
| Restaurar con filtros y sin texto busca solo | `SearchViewModelTest` | unitaria |
| El estado vacío no aparece antes de la respuesta | `SearchViewModelTest` | unitaria |
| El evento lleva el recuento contestado (**regresión**), una vez por respuesta, con vocabulario cerrado | `SearchViewModelTest` | unitaria |
| Sección sola y rango solo sobre el grafo real con Room en memoria; rango vacío → `Empty` | `SearchFlowIntegrationTest` | Robolectric |
| El estado inicial menciona el filtro | `SearchContentTest` | instrumentada |

Lo que **no** cubren y se mira a mano: el tiempo real hasta ver la lista (SC-001), y que en un
dispositivo no se perciba el destello (SC-005).

---

## 4. Recorrido manual

Con la aplicación instalada (`./gradlew :app:installDebug`) y una sincronización hecha, para que haya
archivo.

1. **Un filtro solo.** Buscar → «Filtrar resultados» → sección «Disposiciones generales» → «Aplicar
   filtros», **sin escribir nada**. Se espera: la etiqueta de la sección, el recuento, la lista, y si
   hay más de 300 el aviso «Hay más de 300 publicaciones. Acota la búsqueda…». Lo que **no** debe verse
   en ningún momento: «No hemos encontrado publicaciones». Cronometra desde «Aplicar»: menos de un
   segundo (SC-001).
2. **Un rango.** Añade «desde» y «hasta» con dos fechas distintas. Se espera: la lista se recorta a
   las publicaciones con fecha dentro del rango. Con «desde» igual a «hasta»: las de ese día. Solo
   «desde»: de ese día en adelante.
3. **El texto acota.** Con la sección puesta, escribe **una** letra. Se espera: la lista se acota
   (SC-003). Escribe más: sigue acotando. Borra el texto con el aspa: vuelve la lista de la sección,
   sin pasar por el inicial ni por el vacío.

   Si tecleas con `adb`, **los espacios van como `%s`**: `adb shell input text 'plan%sgeneral'`. Con
   espacios sueltos corta en el primero y parece un defecto de la aplicación.
4. **Quitar la última etiqueta.** Con el campo vacío, quita la etiqueta de la sección. Se espera: la
   pantalla vuelve al estado inicial, cuyo cuerpo dice ahora «Escribe al menos dos letras **o aplica
   un filtro** y verás las publicaciones que coincidan». Puede que la lista tarde un cuarto de segundo
   en irse: es el `debounce`, y es lo esperado.
5. **Sin filtros, una letra.** Escribe una sola letra sin filtros. Se espera: estado inicial, como
   siempre (SC-004). Escribe la segunda: resultados.
6. **Un rango vacío.** Aplica «desde» y «hasta» en un fin de semana en el que no se publicó nada. Se
   espera: «No hemos encontrado publicaciones», **después** de un instante, no antes.
7. **Muerte del proceso.** Con una sección puesta y el campo vacío, mata el proceso y vuelve:

   ```bash
   adb shell am kill com.jrblanco.boccantabria
   # reabrir desde el lanzador, ir a Buscar
   ```

   Se espera: la etiqueta está y la lista de la sección se muestra sola, sin tocar nada (SC-007).

8. **Todas las etiquetas a la vista (US6).** Filtros: «desde» y «hasta» el mismo día, una sección y un
   organismo → aplicar. Se espera: las tres etiquetas **y** «Limpiar todo» en el volcado sin desplazar
   nada, en dos líneas si hace falta, y la de sección con el nombre corto («Sección: Disposiciones»).
   Pulsar «Limpiar todo» → estado inicial (SC-011).
9. **La hoja no vuelve abierta (US6).** Con una sección aplicada, abrir la hoja de filtros, Inicio,
   `am kill`, reabrir. Se espera: la hoja **no** está; la etiqueta de la sección y su lista sí
   (SC-012). Antes de esta enmienda la hoja volvía abierta y con el borrador en blanco.

### 4 bis. La analítica, si se quiere ver

Los eventos de Firebase se pueden mirar en el dispositivo con el modo de depuración estándar:

```bash
adb shell setprop debug.firebase.analytics.app com.jrblanco.boccantabria
adb logcat -s FA FA-SVC
```

Aplica una sección sin texto y busca `boc_search`. Se espera un solo evento con `has_filters=true`,
`has_text=false` y `results=100+` (o el tramo que corresponda), **no** uno con `results=0` seguido de
nada (SC-006). Ningún valor debe parecerse a una fecha, un organismo ni un texto escrito (SC-008). Para
salir del modo de depuración:

```bash
adb shell setprop debug.firebase.analytics.app .none.
```

---

## 5. Cierre

- `CLAUDE.md` actualizado en el párrafo «Buscar existe desde la feature 006».
- Las cuatro puertas en verde.
- Commit en español con prefijo `feat(015):` cuando el propietario lo pida; la rama
  `015-buscar-solo-filtros` **se conserva** tras el merge, como todas.
