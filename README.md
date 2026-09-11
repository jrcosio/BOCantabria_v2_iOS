<div align="center">

# BOCantabria iOS

**Aplicación iOS nativa para el Boletín Oficial de Cantabria**

[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2018-0071E3?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![GRDB](https://img.shields.io/badge/GRDB-7.11-003B57?logo=sqlite&logoColor=white)](https://github.com/groue/GRDB.swift)
[![Licencia](https://img.shields.io/badge/licencia-MIT-black)](LICENSE)

*Arquitectura limpia · MVVM · Composition root · Firebase · Spec-Driven Development*

</div>

---

## Qué es esto

Puerto a **iOS nativo** de la aplicación del **Boletín Oficial de Cantabria**, cuya versión
Android —Kotlin y Jetpack Compose, quince features y una suite que protege la arquitectura—
está terminada en [`BOCantabria_v2`](https://github.com/jrcosio/BOCantabria_v2).

El proyecto se distingue por **cómo** se construye: aquí no se escribe código de producto sin
una especificación aprobada. Toda funcionalidad recorre el ciclo de
[GitHub Spec Kit](https://github.com/github/spec-kit) antes de tocar una sola línea, y la
arquitectura no es una convención que se respeta por buena voluntad: **está protegida por
pruebas que fallan si alguien la rompe.**

> [!IMPORTANT]
> Las normas vinculantes del proyecto viven en
> [`.specify/memory/constitution.md`](.specify/memory/constitution.md).
> La guía operativa del día a día está en [`CLAUDE.md`](CLAUDE.md).

> [!NOTE]
> **Portar no exime del ciclo.** Los requisitos funcionales del Android se reutilizan —son de
> producto, no de plataforma— y están íntegros en
> [`docs/referencia-android/specs/`](docs/referencia-android/specs/). El diseño técnico se
> escribe para iOS: las decisiones no se heredan.

---

## Estado

| | |
|---|---|
| **Versión** | 1.0.0 |
| **Fase** | Esqueleto de arquitectura: capas, contenedor, sistema de diseño, telemetría y reglas |
| **Plataforma** | iOS 18.0 o superior, solo iPhone |
| **Orientación** | Solo vertical |
| **Tema** | Solo claro, sin seguir el ajuste del sistema |
| **Recursos** | Los 51 iconos y el escudo, convertidos desde los vectores de Android |
| **Pruebas** | 58 sin interfaz en 0,1 s · 6 de interfaz en 28 s |
| **Arranque** | 815 ms medidos *(objetivo: < 2 s)* |

---

## Puesta en marcha

### Requisitos

- **Xcode 26** o superior
- Un simulador o dispositivo con **iOS 18** o superior

### Arrancar

```bash
git clone https://github.com/jrcosio/BOCantabria_v2_iOS.git
cd BOCantabria_v2_iOS

# La credencial del servicio de IA no se versiona. Sin ella la build sigue en verde
# y la aplicación muestra la IA como «no configurada».
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig

open BOCantabria-ios.xcodeproj
```

**Firebase.** El `GoogleService-Info.plist` **no está en el repositorio**. Descárgalo de la
consola de Firebase —proyecto `bocantabria-6e90f`, aplicación iOS `com.jrblanco.BOCantabria`—
y colócalo en `BOCantabria-ios/`.

> [!NOTE]
> Sin ese fichero la aplicación **arranca igual** y la telemetría queda en no operación, que es
> la misma promesa que con la credencial de IA: sin secretos, la build y las pruebas siguen en
> verde. Y ten presente que sacarlo del repositorio no convierte la clave en secreta —viaja
> dentro de cualquier build distribuida—: la mitigación de verdad es restringirla en Google
> Cloud a la app iOS y a las APIs que se usan.

### Comandos

| Qué hace | Comando |
|---|---|
| Compilar | `xcodebuild -scheme BOCantabria-ios -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build` |
| Pruebas unitarias y de integración | `xcodebuild ... -only-testing:BOCantabria-iosTests -quiet test` |
| Pruebas de interfaz | `xcodebuild ... -only-testing:BOCantabria-iosUITests -quiet test` |
| Resolver paquetes | `xcodebuild -resolvePackageDependencies` |

> [!TIP]
> Añade siempre `-quiet`. La salida completa de `xcodebuild` son decenas de miles de líneas y
> el error real se pierde dentro.

---

## Cómo se trabaja aquí

Toda feature recorre el ciclo completo. **Sin `tasks.md` aprobado no se escribe código de
producto.**

| Comando | Para qué | Produce |
|---|---|---|
| `/speckit-specify` | Arranque de toda feature | Rama `NNN-slug` + `specs/NNN-slug/spec.md` |
| `/speckit-clarify` | Resolver ambigüedades *(opcional)* | Actualiza `spec.md` |
| `/speckit-plan` | Diseño técnico y decisiones | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| `/speckit-tasks` | Descomposición ejecutable | `tasks.md` |
| `/speckit-analyze` | Coherencia entre artefactos *(opcional)* | Informe de huecos |
| `/speckit-implement` | Ejecutar las tareas | Código y pruebas |

**Exentos del ciclo:** configuración del proyecto Xcode, subidas de versión, erratas y
documentación.

---

## Arquitectura

Arquitectura limpia por capas con MVVM. **Las dependencias apuntan siempre hacia dentro.**

```
UI  →  Domain  ←  Data
```

**Las reglas, en una frase cada una:**

- `Domain` es **Swift puro**: cero SwiftUI, cero UIKit, cero GRDB, cero Firebase, cero PDFKit,
  cero referencias a `Data` o `UI`. Se puede probar sin simulador.
- `Data` implementa lo que `Domain` declara. Sus DTOs y registros **no cruzan** a `UI`: se
  traducen a modelos de dominio.
- `UI` habla **solo** con casos de uso. Un `ViewModel` nunca importa nada de `Data`.
- Los SDK de Firebase se tocan **únicamente** desde `Data/Telemetry`, detrás de las
  abstracciones `AnalyticsTracker` y `CrashReporter`.

### Stack

| Área | Elección | Por qué |
|---|---|---|
| **UI** | SwiftUI | Sin Storyboards ni pantallas en UIKit. La única excepción acotada es PDFKit |
| **Presentación** | MVVM con `@Observable` | Estado inmutable: los estados imposibles no compilan |
| **Inyección** | Composition root propio | Grafo en un sitio y por inicializador: un cableado incompleto **no compila** |
| **Asincronía** | `async/await` y actores | Cancelación real, sin el agujero de una E/S bloqueante |
| **Telemetría** | Firebase Analytics + Crashlytics | Siempre tras abstracción propia, sustituible en pruebas |
| **Configuración** | Firebase Remote Config | Versión mínima soportada y avisos de mantenimiento |
| **Persistencia** | [GRDB](https://github.com/groue/GRDB.swift) | SQL crudo, migraciones versionadas y `ValueObservation`. **Nunca borra** una publicación |
| **Red** | `URLSession` | Diecinueve GET de XML crudo: no hay API tipada que convertir |
| **XML** | `XMLParser` | `XMLDocument` no existe en iOS |
| **Visor de PDF** | PDFKit | El nativo de Apple, encerrado tras una vista propia |

---

## Pruebas

**Ninguna tarea se da por terminada sin su prueba en verde.** Está prohibido desactivar,
ignorar o comentar una prueba para que pase la build.

| Tipo | Dónde | Qué protege |
|---|---|---|
| **Unitarias** | `BOCantabria-iosTests` | Casos de uso, repositorios y modelos de pantalla |
| **Integración** | `BOCantabria-iosTests` | Que el grafo se construye y que las capas están enchufadas |
| **Arquitectura** | `BOCantabria-iosTests` | Que nadie rompe la regla de dependencias |
| **Interfaz** | `BOCantabria-iosUITests` | Render, navegación y estados de pantalla |

---

## Documentación

| Documento | Contenido |
|---|---|
| [`.specify/memory/constitution.md`](.specify/memory/constitution.md) | **La norma.** Principios vinculantes del proyecto |
| [`CLAUDE.md`](CLAUDE.md) | **La guía operativa.** Comandos, convenciones y trampas conocidas |
| [`docs/diseno/`](docs/diseno/) | Especificaciones visuales. Fuente de verdad de la interfaz |
| [`docs/referencia-android/`](docs/referencia-android/) | Las quince features del Android, íntegras. **Referencia, no norma** |
| [`specs/`](specs/) | Una carpeta por feature: qué, por qué, cómo y en qué pasos |

Si enmiendas la constitución, actualiza `CLAUDE.md` en el mismo cambio.

---

<div align="center">

Hecho por [J. Ramón Blanco](https://github.com/jrcosio) · Licencia [MIT](LICENSE)

</div>
