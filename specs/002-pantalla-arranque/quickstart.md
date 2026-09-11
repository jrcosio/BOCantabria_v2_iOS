# Quickstart: cómo se verifica esta feature

Diez pasos. Los cuatro primeros son las puertas de calidad y lo que las sostiene; del cinco al
nueve es lo que ninguna prueba automática puede ver; el diez queda pendiente de la consola y **no
bloquea**.

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
APP='com.jrblanco.BOCantabria'
```

---

## 1. Las cuatro puertas de calidad

No hay CI, por la constitución 1.1.0. Se ejecutan aquí y **el resultado se anota con cifras en
`tasks.md`** —«74 pruebas en 0,12 s»—, nunca con un «pasa».

```bash
# 1 · Construcción
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios -destination "$DEST" -quiet build

# 2 · Pruebas sin interfaz: unitarias, integración y reglas de arquitectura
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios -destination "$DEST" \
  -only-testing:BOCantabria-iosTests -quiet test

# 3 · Pruebas de interfaz
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios -destination "$DEST" \
  -testPlan UITests -quiet test

# 4 · Sin avisos nuevos
xcodebuild -project BOCantabria-ios.xcodeproj -scheme BOCantabria-ios -destination "$DEST" \
  build 2>&1 | grep -c "warning:"
```

---

## 2. Que las reglas de arquitectura siguen mordiendo

Una regla que no puede fallar no protege nada. Tres violaciones a mano, y las tres **deben** poner
en rojo el paso 1 del bloque anterior:

```bash
# a) La regla de capas (regla 2): que Domain nombre un tipo de Data
#    Añade a Domain/Model/AppConfig.swift una línea que mencione RemoteConfigValues. DEBE fallar.

# b) La regla del aspecto (regla 7): un color construido a mano
#    Pon un Color(red:green:blue:) en UI/Splash/SplashContentView.swift. DEBE fallar.

# c) La regla del fichero de prueba (regla 9): borra BOCantabria-iosTests/Domain/AppVersionTests.swift
#    DEBE fallar con «AppVersion no tiene AppVersionTests».

git checkout -- .   # y las tres DEBEN volver a pasar
```

---

## 3. Que arranca sin ningún secreto (SC-010)

Es la promesa que la feature 001 hizo con la telemetría y que esta extiende a la configuración
remota.

```bash
mv BOCantabria-ios/GoogleService-Info.plist /tmp/GoogleService-Info.plist.bak
xcodebuild ... -quiet build && xcodebuild ... -only-testing:BOCantabria-iosTests -quiet test
```

La construcción y las pruebas **deben seguir en verde**, y la aplicación debe abrirse en el
simulador, mostrar la portada y **llegar al contenido principal** —no a la pantalla de error—,
porque sin fuente de configuración se arranca con los valores por defecto (FR-014).

```bash
mv /tmp/GoogleService-Info.plist.bak BOCantabria-ios/GoogleService-Info.plist
```

---

## 4. Que no hay destello ni salto del escudo (FR-002)

El paso que justifica media feature, y el único modo de verlo es fotograma a fotograma. A ojo, un
destello de 80 ms se recuerda como «va rápido».

```bash
xcrun simctl terminate booted "$APP" 2>/dev/null
xcrun simctl io booted recordVideo --codec h264 /tmp/arranque.mov &   # Ctrl-C para parar
xcrun simctl launch booted "$APP"
```

Revisa los primeros fotogramas del vídeo. **Debe cumplirse todo esto:**

- Ningún fotograma blanco entre el icono y el azul institucional.
- El escudo aparece en el **primer** fotograma azul, no después.
- El escudo **no se mueve ni cambia de tamaño** cuando aparecen `BOC` y el resto del texto. Es lo
  que verifica la geometría de `ic_launch_emblem` (research.md D-203), que ningún compilador puede
  comprobar.
- **No hay barra de estado** en ningún fotograma de la portada, ni en el lanzamiento (FR-022).
- Al llegar al contenido principal, la barra de estado **vuelve**.

---

## 5. Los cuatro estados, uno a uno

Los escenarios de arranque se pasan como argumento de lanzamiento (research.md D-212):

```bash
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=ready
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=slow
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=offline
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=updateRequired
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=maintenance
```

| Escenario | Esperado |
|---|---|
| `ready` | Pasa sola al contenido principal, sin tocar nada (FR-004) |
| `slow` | Indicador de progreso visible, y a los 8 s el mensaje de error con sus **dos** salidas (FR-006) |
| `offline` | Mensaje de error, «Reintentar» y «Continuar sin conexión». Continuar lleva al contenido principal (FR-010) |
| `updateRequired` | «Actualiza la aplicación», y **ninguna** acción que lleve al contenido principal (FR-012) |
| `maintenance` | El mensaje de mantenimiento publicado, y tampoco salida (FR-013) |

**Prueba a colarte**: en `updateRequired` y en `maintenance`, intenta llegar al contenido principal
por cualquier vía —tocar, deslizar, mandar a segundo plano y volver—. Si lo consigues, la puerta no
cierra y la feature no está terminada.

**El retroceso** (FR-007): con `ready`, ya en el contenido principal, desliza desde el borde
izquierdo. No debe volver a la portada. La prueba automática lo afirma; esto confirma el gesto real.

---

## 6. El tiempo (SC-001 y SC-002)

Se mide, no se estima, y **la cifra se anota en `tasks.md`**.

```bash
xcrun simctl terminate booted "$APP"
xcrun simctl io booted recordVideo --codec h264 /tmp/tiempo.mov &
xcrun simctl launch booted "$APP"
# parar la grabación al ver el contenido principal
ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/tiempo.mov
```

- **SC-001**: del toque al contenido principal, **menos de 3 s**. Referencia: la feature 001 midió
  815 ms de arranque en este mismo simulador, y esta feature añade el mínimo de 1,2 s.
- **SC-002**: la portada visible **al menos 1 s** y sin parpadear. En el vídeo se cuenta: a 60
  fotogramas por segundo son sesenta fotogramas azules como mínimo.

Si SC-001 se pasara de 3 s, el sospechoso es que el mínimo se haya implementado **en serie** con el
trabajo en vez de en paralelo (research.md D-210). La prueba con reloj controlable lo distingue;
esta medición solo lo delata.

---

## 7. Sin conexión de verdad (SC-003)

El escenario `offline` prueba el camino; esto prueba que el camino es el que ocurre de verdad. El
simulador usa la red del ordenador, así que **se apaga la wifi del Mac**:

```bash
networksetup -setairportpower en0 off
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP"
```

Esperado: mensaje de error con sus dos salidas, y el contenido principal alcanzable **en dos toques
como máximo**. Con la wifi de vuelta, «Reintentar» debe completar el arranque sin reiniciar la
aplicación.

```bash
networksetup -setairportpower en0 on
```

---

## 8. La identidad visual (SC-008 y SC-009)

```bash
# a) Comparación con la imagen de referencia
xcrun simctl launch booted "$APP" -boc-startup-scenario=slow
xcrun simctl io booted screenshot /tmp/portada.png
open /tmp/portada.png docs/diseno/pantalla-arranque-referencia.png
```

Deben coincidir en proporciones del escudo, jerarquía de `BOC`, las dos líneas de la denominación,
la línea divisoria y **los dos colores de la autoría**. El texto de autoría es el de la
especificación, **no** el de la imagen, que está desactualizada.

```bash
# b) El tema del sistema no altera nada (SC-009)
xcrun simctl ui booted appearance light && xcrun simctl launch booted "$APP" -boc-startup-scenario=slow
xcrun simctl io booted screenshot /tmp/claro.png
xcrun simctl ui booted appearance dark  && xcrun simctl launch booted "$APP" -boc-startup-scenario=slow
xcrun simctl io booted screenshot /tmp/oscuro.png
cmp /tmp/claro.png /tmp/oscuro.png && echo "IDÉNTICAS ✓"
```

```bash
# c) Texto al 200 % (SC-008)
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
xcrun simctl terminate booted "$APP"; xcrun simctl launch booted "$APP" -boc-startup-scenario=slow
```

Esperado: la jerarquía se conserva y **ningún texto queda recortado**. Repetir en los estados de
error y de bloqueo, que son los que llevan más texto.

```bash
xcrun simctl ui booted content_size medium
```

---

## 9. El registro del dispositivo (FR-018)

La pantalla no dice códigos, a propósito. El registro es el único sitio donde se distingue qué pasó.

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.jrblanco.BOCantabria"'
```

Con cada escenario de fallo debe aparecer **una** línea que diga la fase y el motivo exacto. Y **no
debe aparecer**: ninguna credencial, ningún mensaje del servicio, ningún dato personal.

---

## 10. La configuración remota (diferido, no bloquea)

El parámetro `min_supported_version_ios` **todavía no existe** en la consola de Firebase, y por eso
la aplicación arranca con los valores por defecto, que es exactamente lo que FR-014 exige. Cuando el
propietario lo dé de alta en el proyecto `bocantabria-6e90f`:

| Publicar | Esperado |
|---|---|
| `min_supported_version_ios` = `"0.0.0"` (o nada) | Arranque normal. **Nunca** bloquea |
| `min_supported_version_ios` por encima de la instalada, p. ej. `"9.0.0"` | «Actualiza la aplicación», sin salida |
| `min_supported_version_ios` = `"latest"` o cualquier texto ilegible | Arranque normal. Un valor que no se entiende **no** deja a nadie fuera (FR-015) |
| `maintenance_message` con texto | Se muestra ese texto, sin salida |
| `maintenance_message` vacío o con espacios | Arranque normal |

`min_supported_version_code`, el parámetro de Android, **no se toca**: sigue siendo suyo y esta
aplicación no lo lee.

> Al probarlo, recuerda que el cliente de configuración remota cachea durante horas. Para que un
> cambio de la consola se vea al momento hay que bajar el intervalo mínimo de obtención en
> desarrollo, y **volver a subirlo** antes de dar la feature por terminada.

---

## Condición de aceptación

Los pasos 1 a 9 en verde. El 10 queda anotado como pendiente de la consola y no bloquea la
integración, igual que ocurrió en la feature equivalente de Android.
