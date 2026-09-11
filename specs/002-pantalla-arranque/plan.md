# Implementation Plan: Pantalla de arranque y comprobación previa

**Branch**: `002-pantalla-arranque` | **Date**: 2026-09-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-pantalla-arranque/spec.md`

## Summary

Poner delante de todo la portada institucional y la comprobación que decide si se puede entrar:
conexión, configuración remota y versión soportada. Cuatro estados mutuamente excluyentes
—preparando, listo, error recuperable y acceso bloqueado— y, en cada uno, exactamente las salidas
que le corresponden.

El enfoque técnico son **tres piezas y un conmutador**: un caso de uso que orquesta las tres
comprobaciones y decide la precedencia, dos repositorios que le dan los datos, y una raíz que
muestra la portada **o** el contenido principal en lugar de apilarlos. La portada nunca entra en la
pila de navegación, así que el requisito de que el retroceso no vuelva a ella deja de ser algo que
haya que recordar hacer.

La feature hereda la 001 completa y **no rehace nada de ella**: el sistema de diseño, el contenedor,
la telemetría tras abstracción, el aspecto único claro, la orientación vertical y las nueve reglas
ya están. Lo que aquí se toca de ese esqueleto son tres cosas, las tres justificadas abajo en
*Complexity Tracking*.

## Technical Context

**Language/Version**: Swift 6.0 (modo de lenguaje 6, concurrencia estricta, aislamiento por defecto
`nonisolated`), Xcode 26.6

**Primary Dependencies**: SwiftUI · FirebaseAnalytics, FirebaseCrashlytics y **FirebaseRemoteConfig**
12.19.1. **Esta feature no añade ninguna dependencia nueva**: las tres están enlazadas desde el
arranque del proyecto y `FirebaseRemoteConfig` se usa aquí por primera vez. Del sistema se usa
`Network` (`NWPathMonitor`), que no es una dependencia externa.

**Storage**: N/A. Esta feature no persiste nada. GRDB sigue enlazada y sin usar; la persistencia se
decide en la feature del boletín.

**Testing**: Swift Testing para unitarias e integración; XCUITest para interfaz. Los dos planes de
prueba existentes sirven sin cambios.

**Target Platform**: iOS 18.0 o superior, solo iPhone, solo vertical, apariencia clara fijada.

**Project Type**: aplicación móvil. Un único target, separación por carpetas.

**Performance Goals**: contenido principal en menos de 3 s desde el icono (SC-001); portada visible
al menos 1 s y sin parpadeo (SC-002); ninguna espera indefinida, salida ofrecida en menos de 10 s
(SC-004).

**Constraints**: la aplicación se construye, arranca **hasta el contenido principal** y pasa las
pruebas en un puesto **sin ningún secreto** (SC-010). Ningún valor por defecto puede bloquear la
primera versión publicada (SC-006).

**Scale/Scope**: 1 pantalla nueva. Estimación: ~19 ficheros de producción nuevos, ~10 modificados y
~10 de prueba nuevos.

## Constitution Check

*GATE: comprobado antes de la investigación y vuelto a comprobar tras el diseño.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| **I. SDD obligatorio** | ✅ | La feature recorre el ciclo completo en su rama. Los requisitos se reutilizan de la 002 de Android; las trece decisiones técnicas de aquella se revisaron una a una y **seis se descartaron por ser mecanismo de plataforma** (research.md, cabecera) |
| **II. Arquitectura limpia** | ✅ | `AppConfig`, `AppVersion`, `StartupStatus`, los dos protocolos de repositorio y el caso de uso son Swift puro. `RemoteConfigValues` se traduce y no cruza a `UI`. La conectividad se modela como repositorio para que `Domain` no vea la plataforma (D-205). Lo comprueban las reglas 1 a 3, que también miran las **referencias por nombre** |
| **III. MVVM** | ✅ | `SplashView` + `SplashViewModel` + `SplashUiState`, con `SplashContentView` tonta y previsualizable. El modelo es `@MainActor @Observable` con `private(set) var state`; el estado es un enumerado inmutable y `blocked` es un caso propio, no una bandera (D-207 del Android, conservada) |
| **IV. Composition root** | ✅ | Todo lo nuevo se cablea en `AppContainer`, por inicializador y detrás de protocolos de `Domain`. Sin `@Environment`. Los parámetros nuevos llevan valor por defecto para no romper las llamadas existentes de `AppContainerTests` |
| **V. Testing exigente** | ✅ | Las tres capas de la pirámide. El tiempo mínimo y el límite de espera se verifican con **reloj controlable**, sin esperas reales, que es lo que exige el principio de determinismo — y para eso hace falta un doble nuevo (D-211) |
| **VI. Observabilidad desacoplada** | ✅ | `FirebaseRemoteConfig` solo se toca desde `Data/Source/Remote`, en un fichero que lleva el nombre del proveedor. La telemetría sigue tras `AnalyticsTracker` y `CrashReporter`. Ningún dato personal: ni el mensaje del servicio ni la credencial salen en analítica, en trazas ni en el registro |
| **Restricciones tecnológicas** | ✅ | Sin Storyboards —el lanzamiento del sistema se configura con el diccionario del `Info.plist` (D-202)—, sin XIB, sin UIKit para pantallas. Sin Combine ni `DispatchQueue` suelta: `async/await` y un `actor` para el monitor de red. Sin dependencias nuevas. Tema único claro, y la regla que lo protege **queda intacta** (D-213) |

**Tres desviaciones, las tres declaradas** en *Complexity Tracking*. Ninguna toca un principio.

## Project Structure

### Documentation (this feature)

```text
specs/002-pantalla-arranque/
├── plan.md              # Este fichero
├── research.md          # Decisiones D-201 … D-214
├── data-model.md        # Entidades, precedencia y transiciones
├── quickstart.md        # Diez pasos de verificación
├── contracts/
│   └── internal-contracts.md
├── checklists/
│   └── requirements.md
├── spec.md              # FR-022 enmendado en este mismo cambio
└── tasks.md             # Lo genera /speckit-tasks
```

### Source Code (repository root)

```text
BOCantabria-ios/
├── Core/
│   ├── DI/AppContainer.swift                         MODIFICADO  fábrica y cableado nuevos
│   ├── UI/Strings.swift                              MODIFICADO  enum Splash
│   ├── UI/Theme/BocTypography.swift                  MODIFICADO  tracking almacenado + grupo splash
│   ├── Util/AppInfo.swift                            NUEVO       lee la versión del paquete
│   ├── Util/StartupScenario.swift                    NUEVO       la costura de las pruebas
│   └── Util/LaunchConfiguration.swift                MODIFICADO  segundo argumento
├── Domain/
│   ├── Model/AppConfig.swift                         NUEVO
│   ├── Model/AppVersion.swift                        NUEVO
│   ├── Model/StartupStatus.swift                     NUEVO
│   ├── Repository/AppConfigRepository.swift          NUEVO
│   ├── Repository/ConnectivityRepository.swift       NUEVO
│   └── UseCase/PrepareStartupUseCase.swift           NUEVO
├── Data/
│   ├── Repository/AppConfigRepositoryImpl.swift      NUEVO
│   ├── Repository/ConnectivityRepositoryImpl.swift   NUEVO
│   ├── Source/Local/ConnectivityDataSource.swift     NUEVO       protocolo + actor sobre NWPathMonitor
│   ├── Source/Remote/RemoteConfigDataSource.swift    NUEVO       protocolo + RemoteConfigValues
│   ├── Source/Remote/FirebaseRemoteConfigDataSource.swift  NUEVO ÚNICO sitio que toca el SDK
│   ├── Source/Remote/UnavailableRemoteConfigDataSource.swift NUEVO
│   └── Telemetry/TelemetryBundle.swift               MODIFICADO  resuelve también la config remota
├── UI/
│   ├── Splash/SplashView.swift                       NUEVO
│   ├── Splash/SplashViewModel.swift                  NUEVO
│   ├── Splash/SplashUiState.swift                    NUEVO
│   ├── Splash/SplashContentView.swift                NUEVO
│   └── Navigation/RootView.swift                     MODIFICADO  conmutador, sin tocar Route
├── Localizable.xcstrings                             MODIFICADO  trece cadenas splash_*
└── Assets.xcassets/Icons/ic_launch_emblem.imageset/  NUEVO       escudo del lanzamiento

Config/Info.plist                                     MODIFICADO  UILaunchScreen · UIStatusBarHidden
BOCantabria-ios.xcodeproj/project.pbxproj             MODIFICADO  UILaunchScreen_Generation = NO

BOCantabria-iosTests/
├── Architecture/ArchitectureRulesTests.swift         MODIFICADO  StartupStatus a la lista de exentos
├── Core/AppInfoTests.swift                           NUEVO
├── Core/LaunchScreenContractTests.swift              NUEVO       lee el Info.plist compilado
├── Domain/AppVersionTests.swift                      NUEVO       parseo, orden y valores ilegibles
├── Domain/AppConfigTests.swift                       NUEVO
├── Domain/PrepareStartupUseCaseTests.swift           NUEVO       las cuatro filas de la precedencia
├── Data/AppConfigRepositoryImplTests.swift           NUEVO
├── Data/ConnectivityRepositoryImplTests.swift        NUEVO
├── UI/SplashViewModelTests.swift                     NUEVO
├── Integration/StartupFlowIntegrationTests.swift     NUEVO
├── Integration/AppContainerTests.swift               MODIFICADO  resuelve la fábrica nueva
└── Fakes/Fakes.swift                                 MODIFICADO  ManualClock y tres dobles más

BOCantabria-iosUITests/
└── Splash/SplashStatesUITests.swift · SplashNavigationUITests.swift  NUEVO
```

**Structure Decision**: las piezas nuevas caen en las carpetas que ya existen, sin inventar ninguna,
salvo `UI/Splash/`, que es la carpeta de la pantalla y sigue la convención de `UI/Home/`. El
proyecto usa grupos sincronizados con el sistema de ficheros, así que **crear un `.swift` en disco
basta**: el `project.pbxproj` solo se toca para el ajuste del lanzamiento.

Dos ubicaciones que merecen explicación:

- **`AppInfo` va en `Core/Util`, no en `Domain`.** `AppVersion` es un modelo de dominio y tiene que
  seguir siendo Swift puro; quien lee el paquete es transversal. Es la diferencia entre el dato y
  quien lo trae (D-206).
- **La conectividad es una fuente *local*.** No viaja por la red: es información que el dispositivo
  provee, igual que lo era en Android.

## Complexity Tracking

Tres desviaciones. Ninguna añade una capa, un patrón nuevo ni una dependencia.

| Desviación | Por qué hace falta | Alternativa más simple, y por qué se rechaza |
|---|---|---|
| **Ampliar la costura de `LaunchConfiguration`** con `-boc-startup-scenario=`, cuando su propia cabecera dice «se sustituye, no se amplía» | FR-028 exige pruebas de interfaz de los cuatro estados. Una prueba de interfaz corre en otro proceso y **no puede sustituir nada por dentro**; el único mecanismo de esta plataforma son los argumentos de lanzamiento. Sin la costura, tres de los cuatro estados quedan verificados solo a mano, y son justo los que nadie mira hasta que fallan | Verificar a mano los tres estados: convierte en manual una puerta que la constitución exige automática, y se degrada en la primera semana con prisa. Una compilación aparte para pruebas: duplica la configuración y hace que lo que se prueba no sea lo que se publica |
| **`BocTextStyle.tracking` deja de ser una constante cero** y se añade un grupo `splash` fuera de la escala de catorce | El apartado 13.2 del documento de diseño declara tres tamaños y un espaciado entre letras que el apartado 6.2 no contempla. La convención del proyecto prohíbe escribirlos como literales en la vista, así que su sitio es el tema | Mapear al token más cercano: pierde el peso y el espaciado que el documento declara expresamente, y SC-009 exige que la portada sea indistinguible de la referencia. Meterlos en la escala de catorce: la cabecera de ese fichero dice que es la transcripción del apartado 6.2, y dejaría de serlo |
| **`StartupStatus` entra en `domainTypesWithoutBehaviour`**, la lista de exentos de la regla 9, cuyo comentario pide mantenerla corta | Es un enumerado de tres casos sin comportamiento: lo único que se podría afirmar de él es que el compilador funciona. Su semántica se prueba donde vive, en `PrepareStartupUseCaseTests` | Escribirle un fichero de prueba trivial: satisface la regla sin comprobar nada, que es peor que la exención, porque la exención al menos se ve en la lista |

**Lo que NO se desvía, y conviene dejar escrito**: la regla 8 —la que impide que la apariencia
dependa del ajuste claro/oscuro del sistema— **queda intacta**. Cumplir FR-022 en su redacción
original habría exigido exceptuarla para la carpeta de la portada; la decisión del propietario de
ocultar la barra de estado (D-213) evita abrir ese agujero y además se ajusta mejor a la imagen de
referencia, que no tiene barra.
