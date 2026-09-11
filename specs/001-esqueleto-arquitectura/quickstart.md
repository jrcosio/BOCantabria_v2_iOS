# Quickstart: cómo se verifica esta feature

Los comandos suponen el simulador de referencia. Añade siempre `-quiet`: la salida completa de
`xcodebuild` son decenas de miles de líneas y el error real se pierde dentro.

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## 1. Las cuatro puertas de calidad

```bash
# 1 · Construcción
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -quiet build

# 2 · Pruebas sin interfaz: unitarias, integración y reglas de arquitectura
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -testPlan UnitTests -quiet test

# 3 · Pruebas de interfaz
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -testPlan UITests -quiet test

# 4 · Sin avisos nuevos
xcodebuild -scheme BOCantabria-ios -destination "$DEST" build 2>&1 | grep -c "warning:"
```

La feature está lista cuando las cuatro terminan en verde **y** pasan las tres comprobaciones que
no salen de un comando, que son las de abajo.

---

## 2. Que las reglas de arquitectura muerden

Una comprobación que nunca ha fallado no ha demostrado nada. Hay que verla en rojo:

```bash
# a) La regla de capas
echo 'import SwiftUI' >> BOCantabria-ios/Domain/Model/ContentItem.swift
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -testPlan UnitTests -quiet test   # DEBE fallar
git checkout -- BOCantabria-ios/Domain/Model/ContentItem.swift
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -testPlan UnitTests -quiet test   # DEBE pasar

# b) La regla del aspecto
#    Añade un Color literal a una vista fuera de Core/UI/Theme y repite. DEBE fallar.

# c) La regla del fichero de prueba
#    Crea un tipo de dominio nuevo sin su fichero de prueba y repite. DEBE fallar.
```

Las tres tienen además su propia prueba automática —una regla que no puede fallar es una regla que
no protege nada—, pero el recorrido a mano es el que demuestra que el ciclo rojo→verde funciona de
punta a punta.

---

## 3. Que arranca sin ningún secreto

Es SC-008, y es la comprobación que más fácil se rompe sin enterarse, porque en el puesto de
desarrollo los ficheros están.

```bash
mv BOCantabria-ios/GoogleService-Info.plist /tmp/
mv Config/Secrets.xcconfig /tmp/

xcodebuild -scheme BOCantabria-ios -destination "$DEST" -quiet build          # DEBE pasar
xcodebuild -scheme BOCantabria-ios -destination "$DEST" -testPlan UnitTests -quiet test  # DEBE pasar
# Y la aplicación DEBE abrirse en el simulador y mostrar la pantalla inicial.

mv /tmp/GoogleService-Info.plist BOCantabria-ios/
mv /tmp/Secrets.xcconfig Config/
```

---

## 4. Los cuatro estados, a mano

Las pruebas de interfaz los cubren, pero conviene verlos una vez:

1. **Cargando** — se ve al abrir, mientras corre la latencia simulada del origen.
2. **Contenido** — la lista de elementos.
3. **Sin contenido** — haz que el origen remoto devuelva lista vacía. Debe leerse un mensaje
   propio, **no** un error.
4. **Error y reintento** — haz que el origen remoto falle y que el local esté vacío. Debe verse el
   mensaje con su acción; al pulsarla y responder el origen, debe verse el contenido.
5. **Vuelta de segundo plano** — con contenido en pantalla, manda la aplicación al fondo y
   recupérala. El contenido sigue ahí y **no** reaparece el indicador de carga.

---

## 5. El tiempo de arranque (SC-001)

Se mide, no se estima. Con la aplicación instalada en el simulador:

```bash
xcrun simctl launch --console-pty booted com.jrblanco.BOCantabria
```

El objetivo es **menos de 2 segundos** hasta que la pantalla inicial es visible. Si se quiere una
cifra fina, el instrumento de arranque de Instruments da el desglose; para la puerta basta con que
no haya duda.

---

## 6. La telemetría (SC-006, diferido)

No es puerta de aceptación: el proveedor tarda en mostrar los datos.

```bash
# Eventos en tiempo real durante el desarrollo
xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "com.jrblanco.BOCantabria"'
```

Y después, en la consola del proveedor: el evento de pantalla vista en su panel de depuración, y
la traza de un cierre inesperado en el suyo. **Comprobar también que ningún parámetro personal ha
viajado**, que es lo que FR-020 protege y lo que la prueba de `AnalyticsEvent` ya afirma del lado
de acá de la frontera.
