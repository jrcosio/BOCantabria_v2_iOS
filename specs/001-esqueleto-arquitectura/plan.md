# Implementation Plan: Esqueleto de arquitectura de la aplicación

**Branch**: `001-esqueleto-arquitectura` | **Date**: 2026-09-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-esqueleto-arquitectura/spec.md`

## Summary

Levantar el esqueleto sobre el que se apoyan las catorce features siguientes: las tres capas con
su regla de dependencias, el composition root, el sistema de diseño, la telemetría tras
abstracción y las pruebas que fallan cuando alguien rompe cualquiera de esas cosas.

El enfoque técnico es una **rodaja vertical completa con orígenes en memoria**: una pantalla que
recorre `View → ViewModel → UseCase → Repository → fuentes`, con la pareja local/remota de verdad
para que la política de respaldo sea la que hereden las features reales. Esa rodaja es
deliberadamente trivial y se sustituye en la feature del boletín; lo que se queda es la forma.

## Technical Context

**Language/Version**: Swift 6.0 (modo de lenguaje 6, concurrencia estricta, aislamiento por
defecto en el actor principal), Xcode 26.6

**Primary Dependencies**: SwiftUI · FirebaseAnalytics, FirebaseCrashlytics y FirebaseRemoteConfig
12.19.1 (ya enlazadas). **Esta feature no añade ninguna dependencia nueva.** GRDB 7.11.1 está
enlazada desde el arranque pero **no se usa aquí**: los orígenes son en memoria.

**Storage**: N/A en esta feature. La persistencia se decide en la primera feature de negocio que
la necesite; la constitución ya fija que será GRDB.

**Testing**: Swift Testing (`import Testing`) para unitarias e integración; XCUITest para
interfaz. Dos planes de prueba ya creados: `TestPlans/UnitTests.xctestplan` y
`TestPlans/UITests.xctestplan`.

**Target Platform**: iOS 18.0 o superior, solo iPhone, solo orientación vertical, apariencia clara
fijada.

**Project Type**: aplicación móvil. Un único target, separación por carpetas.

**Performance Goals**: pantalla inicial visible en menos de 2 s (SC-001); batería sin interfaz en
menos de 2 min (SC-003).

**Constraints**: la aplicación se construye, arranca y pasa las pruebas **sin ningún secreto en el
puesto** (SC-008). Ni el fichero de configuración de Firebase ni la credencial de IA están
versionados.

**Scale/Scope**: 1 pantalla. Estimación: ~40 ficheros de producción y ~16 de prueba.

## Constitution Check

*GATE: comprobado antes de la investigación y vuelto a comprobar tras el diseño.*

| Principio | Estado | Cómo se cumple |
|---|---|---|
| **I. SDD obligatorio** | ✅ | Esta feature recorre el ciclo completo. La configuración previa —esquema compartido, planes de prueba y fase de símbolos— fue por la exención de configuración y quedó en su propio commit |
| **II. Arquitectura limpia** | ✅ | `Domain` sin SwiftUI, UIKit, GRDB, Firebase ni PDFKit; `Data` implementa sus protocolos; `UI` solo habla con casos de uso. Hecho cumplir **automáticamente** (D-102), no por convención |
| **III. MVVM** | ✅ | `HomeView` + `HomeViewModel` + `HomeUiState`. El modelo de pantalla es `@MainActor @Observable` con `private(set) var state`; el estado es un `enum` inmutable; `HomeContentView` es tonta y sin estado |
| **IV. Composition root** | ✅ | Todo el grafo en `Core/DI/AppContainer`, por inicializador y detrás de protocolos. Sin `@Environment` para casos de uso ni repositorios. Verificado por prueba (FR-023) |
| **V. Testing exigente** | ✅ | Las tres capas de la pirámide más las reglas de arquitectura. Cada requisito con su prueba, y la regla 6 exige fichero de prueba para todo tipo de dominio y todo modelo de pantalla |
| **VI. Observabilidad desacoplada** | ✅ | Firebase solo en `Data/Telemetry`, tras `AnalyticsTracker` y `CrashReporter`. El filtro de datos personales vive en el modelo del evento, probado sin tocar el SDK |
| **Restricciones tecnológicas** | ✅ | Sin Storyboards, XIB ni UIKit. Sin Combine, sin `DispatchQueue` suelta. Sin dependencias nuevas. Tema único claro. Código en inglés, documentación en español |

**Sin violaciones que justificar.** La sección de complejidad queda vacía a propósito.

## Project Structure

### Documentation (this feature)

```text
specs/001-esqueleto-arquitectura/
├── plan.md              # Este fichero
├── research.md          # Decisiones D-101 … D-110
├── data-model.md        # Entidades, estados y transiciones
├── quickstart.md        # Cómo verificar la feature
├── contracts/
│   └── internal-contracts.md
├── checklists/
│   └── requirements.md
├── spec.md
└── tasks.md             # Lo genera /speckit-tasks
```

### Source Code (repository root)

```text
BOCantabria-ios/
├── BOCantabriaApp.swift          Punto de entrada: construye el AppContainer
├── Core/
│   ├── DI/AppContainer.swift
│   ├── Telemetry/                AnalyticsEvent, AnalyticsTracker, CrashReporter
│   ├── UI/Theme/                 BocColors, BocTypography, BocSpacing, BocShape,
│   │                             BocElevation, BocTheme
│   ├── UI/Component/             LoadingIndicator, ErrorMessage, EmptyMessage
│   └── Util/                     Clock, AppInfo
├── Domain/
│   ├── Model/                    AppResult, DomainError, ContentItem
│   ├── Repository/               ContentRepository
│   └── UseCase/                  GetContentItemsUseCase
├── Data/
│   ├── Repository/               ContentRepositoryImpl
│   ├── Source/Local/             ContentLocalDataSource, InMemory…, ContentItemRecord
│   ├── Source/Remote/            ContentRemoteDataSource, Stub…, ContentItemDTO
│   └── Telemetry/                FirebaseAnalyticsTracker, FirebaseCrashReporter,
│                                 FirebaseBootstrap
└── UI/
    ├── Home/                     HomeView, HomeViewModel, HomeUiState, HomeContentView
    └── Navigation/               Route, RootView

BOCantabria-iosTests/
├── Architecture/                 ArchitectureRulesTests, SourceTree
├── Core/                         AnalyticsEventTests
├── Domain/                       GetContentItemsUseCaseTests
├── Data/                         ContentRepositoryImplTests, telemetría
├── UI/                           HomeViewModelTests
├── Integration/                  AppContainerTests, ContentFlowIntegrationTests
├── Fakes/                        dobles compartidos
└── Fixtures/                     muestras del servicio (ya presentes)

BOCantabria-iosUITests/
└── Home/                         HomeStatesUITests, HomeBackgroundUITests
```

**Structure Decision**: un único target de aplicación con separación por carpetas, igual que el
proyecto Android usó un único módulo Gradle. Se descartó un paquete Swift local por capa
(D-103): daría separación impuesta por el compilador, pero a cambio de multiplicar los targets de
prueba, complicar las vistas previas y hacer que cada feature futura tenga que decidir en qué
paquete cae cada fichero. La separación se hace cumplir con la prueba de reglas, que es lo que el
proyecto Android hacía con Konsist y funcionó durante quince features.

## Complexity Tracking

No hay desviaciones respecto a la constitución. Esta feature **no añade ninguna dependencia
nueva**, no introduce capas extra y no usa ningún patrón no contemplado.
