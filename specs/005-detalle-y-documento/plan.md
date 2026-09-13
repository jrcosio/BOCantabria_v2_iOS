# Implementation Plan: Del titular al documento oficial

**Branch**: `005-detalle-y-documento` | **Date**: 12 de septiembre de 2026 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-detalle-y-documento/spec.md`

## Summary

Cerrar el recorrido que las cuatro features anteriores dejaron a medias: **del titular al documento**.
Pulsar una tarjeta lleva a una pantalla que presenta lo que la aplicación sabe del anuncio, y desde
ahí el documento oficial se abre **dentro de la aplicación**.

Dos cosas la definen, y son inseparables. Una es el visor, que aquí **es del sistema** —y ésa es la
diferencia de plataforma más grande del port: en la aplicación de origen el visor costó una subida de
versión mínima y una dependencia en fase beta; aquí no cuesta ninguna de las dos, y la constitución no
se enmienda—. La otra es **la desconfianza**: el enlace del anuncio devuelve un documento, pero un
servicio público sin compromiso de disponibilidad puede responder un día con una página de error y
código 200, y una aplicación que consulta un boletín oficial no puede presentar eso como oficial. De
ahí que la validación —esquema, host, tipo declarado, **los bytes que realmente llegan** y el tamaño
mientras llega— sea la mitad del trabajo.

El enfoque técnico tiene tres pilares y ninguno es nuevo en el proyecto:

1. **El descargador es hermano del de feeds.** `HttpFeedDownloader` ya resuelve la guarda de esquema y
   host antes de conectar, la revalidación del destino final tras redirecciones y el conteo mientras
   llega. Lo que cambia es a dónde va lo que llega —a disco, en trozos, con la huella al vuelo— y que
   **no reintenta solo**: 25 MB reintentados tres veces son 75 MB de los datos de la persona (D-502,
   D-504).
2. **El estado del documento vive en un `actor` y se observa, no se devuelve.** Es lo que hace que tres
   pantallas vean lo mismo y que ninguna se quede cargando. Y aquí el sistema de tipos hace un regalo:
   tipando el trabajo en vuelo como `Task<…, Never>`, **la clase de bug que la auditoría de origen
   encontró no puede existir** —quien espera no tiene por dónde heredar la cancelación del que lo
   inició—. Comprobado en el SDK, no recordado (**D-507**).
3. **Nada de PDFKit sale de `UI/PDF/`**, y no por disciplina: sus tipos no son `Sendable`, así que
   guardar uno en un estado de pantalla **no compila**; y una regla de arquitectura nueva —la 14— lo
   comprueba sobre el árbol de fuentes (D-513, D-521).

Las dos funciones de IA y la de guardar quedan dichas y con su sitio hecho, sin fingir que funcionan.

**Y una cosa que no pidió el propietario y entra igual**: el armazón construye hoy el modelo de
pantalla de Inicio dentro de su redibujado, y ese nacimiento registra una visita de analítica. No se
ve en pantalla; se ve en el panel del proveedor. **Esta feature lo empeoraría**, porque la pila de
navegación del detalle añade estado al armazón y entonces cada entrada y cada retroceso redibujan.
Arreglar después algo que hemos empeorado a sabiendas sale más caro (FR-051, D-523).

## Technical Context

**Language/Version**: Swift 6.0 (modo de lenguaje 6, concurrencia estricta, aislamiento por defecto
`nonisolated`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`), Xcode 26.6, compilador 6.3.3

**Primary Dependencies**: **ninguna nueva.** GRDB 7.11.1 y Firebase 12.19.1 siguen siendo las dos
únicas familias de terceros. Del sistema se usan tres marcos que el proyecto no había necesitado:
**PDFKit** —acotado a `UI/PDF/` por la constitución y por la regla 14—, **CryptoKit** —que ya usa el
descargador de feeds— y **CoreTransferable**, para compartir el fichero con nombre legible. Los tres
están comprobados en la interfaz del SDK instalado, no recordados (research.md D-502, D-513, D-517).

**Storage**: **sin cambios de esquema.** Ni migración, ni tabla, ni columna, ni índice. La copia local
del documento **no entra en la base de datos**: vive en el directorio de cachés y su estado se deriva
del sistema de ficheros (D-501). `PublicationQueries` gana **una** consulta de lectura y **ninguna** de
escritura, así que la regla 13 y la prueba de regresión del borrado siguen valiendo tal cual.

**Network**: `URLSession` con `async/await`, una configuración **propia** —límites de tiempo más largos
que los del feed, y `Accept` distinto— y el host `boc.cantabria.es`, que **no es** el de los feeds.

**Testing**: Swift Testing para lo unitario y de integración; XCUITest para la interfaz. Dobles escritos
a mano en `Fakes.swift`, como hasta ahora. Se añaden muestras reales de documento en `Fixtures/`, y el
documento de los escenarios de interfaz se **sintetiza en código** porque el proceso de la aplicación
no ve el bundle de pruebas (D-524).

**Target Platform**: iOS 18.0 o superior, solo iPhone, solo vertical, apariencia clara fijada. **La
versión mínima NO sube**, y es la divergencia más grande respecto al port de origen.

**Project Type**: aplicación móvil. Un único target, separación por carpetas.

**Performance Goals**: documento ya consultado en **menos de 1 s** sin red (SC-002); documento nuevo en
**menos de 10 s** con conexión normal (SC-003); un documento de cincuenta páginas no agota la memoria
ni bloquea la interfaz (SC-008). Las dos primeras se **miden con un hito**, no con la espera de la
prueba: XCUITest no sabe medir por debajo del segundo (D-525).

**Constraints**: `Domain` sin dependencias de plataforma —la ruta del fichero viaja como `String`—;
nunca más de 64 KiB del documento en memoria; ningún color, tamaño ni espaciado literal fuera del
tema; pruebas deterministas sin red real ni reloj del sistema; y **nada se presenta como documento
oficial sin haberlo comprobado**.

**Scale/Scope**: 2 pantallas nuevas y media —detalle, visor y el marcador de posición de preguntar—,
2 pantallas modificadas —Inicio y el armazón—. 58 requisitos. Del orden de **30 ficheros de producción
y 20 de prueba**.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluado contra la constitución **1.1.0**.

| Principio | Cómo lo satisface este plan | Puerta |
|---|---|---|
| **I. SDD obligatorio** | La feature recorre el ciclo completo; la rama la creó la extensión git. **No se enmienda la constitución**, a diferencia del port de origen, porque el motivo que allí lo obligaba —el visor— aquí no existe | ✅ |
| **II. Arquitectura limpia** | `OfficialDocument`, `DocumentStatus`, `ShareTarget`, `SharedDocument` y `DetailTab` son Swift puro; la ruta viaja como `String` para que `Domain` no opine de sistemas de ficheros. Descargador y caché son de `Data`; los tipos de PDFKit **no salen** de `UI/PDF/`, y eso lo comprueba la regla 14 en vez de confiarlo | ✅ |
| **III. MVVM** | Dos modelos de pantalla nuevos, `@MainActor @Observable`, con estado inmutable y `private(set)`. `document` y `share` van fuera de un enumerado único porque son ejes ortogonales, igual que en `HomeUiState`. Las vistas de contenido no conocen el modelo | ✅ |
| **IV. Composition root** | Descargador, caché, almacén, repositorio, cuatro casos de uso y dos modelos de pantalla se declaran en `AppContainer`, por inicializador y detrás de protocolo. La prueba que lo construye entero se amplía. **Y se corrige** que el armazón construya el modelo de Inicio en su redibujado (FR-051) | ✅ |
| **V. Testing exigente** | Las tres capas. La validación se prueba sustituyendo el protocolo de red con respuestas fabricadas para engañar; la caché, con directorios temporales; la retirada por antigüedad, con el **reloj inyectado**. Cuatro invariantes del almacén con prueba propia cada uno. **Y una prueba que demuestra que la rasterización no ocurre en el actor principal**, sin la cual `@concurrent` sería una convención | ✅ |
| **VI. Observabilidad desacoplada** | `document_opened` y `document_share` con banderas y enumerados. **Ningún dato personal**: ni título, ni dirección, ni clave, ni nombre de fichero. Ningún SDK nuevo, y ninguno fuera de `Data` | ✅ |
| **Restricciones tecnológicas** | Sin dependencias nuevas. **PDFKit es la excepción que la constitución nombra**, y se usa exactamente como la nombra: acotada tras una vista propia. Compartir se resuelve con un tipo transferible y **no** con un controlador de UIKit envuelto, que sería una pantalla en UIKit y exigiría enmienda (D-517). `async/await` y actores; nada de Combine ni de colas sueltas. Código en inglés, documentación en español | ✅ |

**Resultado de la puerta previa a la fase 0**: pasa. Ninguna violación que justificar.

**Re-evaluación posterior al diseño de la fase 1**: pasa. El diseño no introdujo desviaciones.
`data-model.md`, `contracts/internal-contracts.md` y `quickstart.md` no añadieron ninguna capa, ninguna
dependencia y ningún patrón fuera de los ya admitidos. Las decisiones que añaden algo no exigido
explícitamente quedan en *Complexity Tracking*.

## Project Structure

### Documentation (this feature)

```text
specs/005-detalle-y-documento/
├── spec.md                        # 4 historias, 58 requisitos, 15 criterios de éxito
├── plan.md                        # Este fichero
├── research.md                    # Fase 0: 25 decisiones, con lo descartado y por qué
├── data-model.md                  # Fase 1: la copia local, su estado y las transiciones
├── quickstart.md                  # Fase 1: 12 pasos de validación, ocho de ellos a ojo
├── contracts/
│   └── internal-contracts.md      # Fase 1: firmas, identificadores, telemetría y textos
├── checklists/
│   └── requirements.md            # Calidad de la especificación
└── tasks.md                       # Fase 2 (/speckit-tasks — NO lo crea /speckit-plan)
```

### Source Code (repository root)

```text
BOCantabria-ios/
├── Core/
│   ├── DI/AppContainer.swift                      # MODIFICADO: el grafo del documento
│   ├── Telemetry/AnalyticsEvent.swift             # MODIFICADO: document_opened, document_share
│   ├── UI/Strings.swift                           # MODIFICADO: Detail, PdfViewer, Share, Ask
│   ├── UI/Theme/BocUIColors.swift                 # NUEVO: los colores que UIKit necesita (D-522)
│   ├── UI/Component/PublicationCard.swift         # MODIFICADO: pulsable y comparte el documento
│   └── Util/AppSignposts.swift                    # MODIFICADO: el hito del documento
├── Data/
│   ├── Repository/DocumentRepositoryImpl.swift    # NUEVO
│   ├── Repository/DocumentStore.swift             # NUEVO: actor. Coalescencia y estado terminal
│   ├── Repository/PublicationRepositoryImpl.swift # MODIFICADO: observePublication
│   ├── Source/Remote/DocumentDownloader.swift     # NUEVO: protocolo y resultado
│   ├── Source/Remote/HttpDocumentDownloader.swift # NUEVO
│   ├── Source/Remote/ScenarioDocumentDownloader.swift  # NUEVO: la costura de los escenarios
│   ├── Source/Local/DocumentCache.swift           # NUEVO: protocolo
│   ├── Source/Local/FileDocumentCache.swift       # NUEVO: .part, lateral primero, retirada
│   ├── Source/Local/PublicationQueries.swift      # MODIFICADO: una consulta de lectura
│   ├── Source/Local/PublicationLocalDataSource.swift  # MODIFICADO: su observación
│   └── Sync/ScenarioDatabaseSeeder.swift          # MODIFICADO: cuatro casos nuevos
├── Domain/
│   ├── Model/OfficialDocument.swift · DocumentStatus.swift · ShareTarget.swift
│   │        · SharedDocument.swift · DetailTab.swift          # NUEVOS
│   ├── Repository/DocumentRepository.swift                    # NUEVO
│   ├── Repository/PublicationRepository.swift                 # MODIFICADO: +1 método
│   └── UseCase/ObservePublicationUseCase.swift
│            · ObserveOfficialDocumentUseCase.swift
│            · OpenOfficialDocumentUseCase.swift
│            · ShareOfficialDocumentUseCase.swift               # NUEVOS
└── UI/
    ├── Detail/PublicationDetailView.swift · PublicationDetailContentView.swift
    │          · PublicationDetailUiState.swift · PublicationDetailViewModel.swift   # NUEVOS
    ├── Detail/Component/DetailHeader.swift · DetailTabBar.swift · DocumentTab.swift
    │          · MetadataCard.swift · DetailActionBar.swift · MissingPublication.swift
    ├── PDF/PdfViewerView.swift · PdfViewerContentView.swift · PdfViewerUiState.swift
    │      · PdfViewerViewModel.swift · PdfDocumentView.swift · PdfDocumentProbe.swift
    │      · PdfPageRenderer.swift · DocumentFirstPagePreview.swift
    │                                                # NUEVOS. ÚNICO sitio con PDFKit
    ├── Ask/AskView.swift                            # NUEVO: marcador de posición
    ├── Share/SharedDocumentTransfer.swift           # NUEVO: el tipo transferible
    ├── Home/HomeView.swift · HomeContentView.swift  # MODIFICADOS: la tarjeta abre y comparte
    ├── Main/MainView.swift                          # MODIFICADO: la pila, y FR-051
    └── Navigation/Route.swift                       # MODIFICADO: +2 destinos

BOCantabria-iosTests/
├── Architecture/ArchitectureRulesTests.swift · SourceTreeTests.swift   # MODIFICADOS: regla 14
├── Domain/  (los cinco modelos y los cuatro casos de uso)
├── Data/    HttpDocumentDownloaderTests · FileDocumentCacheTests · DocumentStoreTests
│            · DocumentRepositoryImplTests · PublicationQueriesTests (ampliado)
├── UI/      PublicationDetailViewModelTests · PdfViewerViewModelTests
│            · MainViewModelTests (ampliado: FR-051)
├── Integration/  DocumentFlowIntegrationTests · AppContainerTests (ampliado)
├── Fakes/Fakes.swift                                # MODIFICADO: los dobles del documento
└── Fixtures/  documento_valido.pdf · documento_dos_paginas.pdf · documento_protegido.pdf
              · documento_truncado.pdf · pagina_error.html · declarado_pdf_no_lo_es.bin

BOCantabria-iosUITests/
├── Detail/DetailNavigationUITests · DetailContentUITests · DetailStatesUITests
├── PDF/PdfViewerUITests
└── Home/AccessibilityUITests.swift                  # MODIFICADO: la tarjeta ahora abre
```

**Structure Decision**: se mantiene el target único con separación por carpetas. Tres carpetas nuevas
en `UI`, y cada una por un motivo distinto: `Detail/` y `Ask/` porque en este proyecto **cada pantalla
tiene la suya**, y `PDF/` porque además hace de **frontera** —es lo único que conoce el marco del
visor, y la regla 14 lo comprueba—. `Share/` existe porque el mismo tipo transferible lo usan tres
pantallas y el sitio natural de lo compartido entre pantallas ya estaba previsto en `CLAUDE.md`. En
`Data` no se inventa nada: el descargador es una fuente remota más y la caché una local más,
exactamente como el lector de feeds y la base de datos de la 003. **La única pieza sin precedente en
el proyecto es `DocumentStore`**, y está en `Data/Repository/` porque es lo que da semántica a los
datos que las dos fuentes producen.

## Complexity Tracking

> La puerta de la constitución pasa sin violaciones. Se registran aquí, por transparencia, las
> decisiones que añaden algo que la constitución no exigía explícitamente.

| Decisión | Por qué es necesaria | Alternativa más simple y por qué se descartó |
|---|---|---|
| **`DocumentStore`, un actor con estado, que no existe en ninguna otra feature** | FR-026 a FR-029 —una sola descarga, quien espera no hereda la cancelación, y estado terminal siempre— son invariantes de coordinación, y no hay dónde ponerlos salvo en algo que recuerde qué hay en vuelo. La base de datos no sirve: la copia local no está en ella (D-501) | *Que cada modelo de pantalla descargue lo suyo*: dos pantallas mirando el mismo documento producirían dos descargas y dos ficheros a medias sobre el mismo nombre. *Un semáforo por clave*: resuelve la exclusión pero no el estado compartido ni la reproducción al suscribirse, que es lo que evita el cuelgue silencioso de D-510 |
| **La difusión del estado a mano, con un diccionario de continuaciones** | Un flujo asíncrono de la biblioteca estándar tiene **una** continuación, y aquí lo observan tres pantallas a la vez | *Un flujo por observador que consulte el estado*: convierte la publicación en sondeo. *Combine*: prohibido por la constitución en código nuevo |
| **Cuatro casos nuevos en el enumerado de escenarios, que pasa a llevar dos ejes** | Las pruebas de interfaz corren en otro proceso y el único mecanismo de sustitución son los argumentos de lanzamiento. Probar el visor y los rechazos sin salir a la red exige una costura | *Un tercer argumento de lanzamiento*: es exactamente lo que la constitución acota y lo que `LaunchConfiguration` prometió no hacer. *No probar los rechazos en interfaz*: dejaría sin cubrir SC-006, que es el criterio que nació de un defecto real |
| **Un fichero de colores de UIKit en el tema** | La vista del visor toma un color de UIKit, y la regla 7 **falla la build** si alguien lo construye fuera del tema | *Dejar el fondo transparente*: compila, pasa las pruebas y el visor pinta sobre lo que le toque, incumpliendo el apartado 24.2 del documento de diseño en silencio |
| **Arreglar FR-051, que no es alcance pedido** | Esta feature **lo empeora**: la pila de navegación añade estado al armazón y entonces cada entrada y cada retroceso registran una visita que nadie hizo | *Dejarlo para después*: sería arreglar algo que habremos empeorado a sabiendas, y el defecto solo se ve en el panel del proveedor, que es donde nadie mira hasta que alguien pregunta |
| **La regla de arquitectura 14** | La constitución exige por escrito que el marco del visor quede encerrado tras una vista propia; hasta ahora **nada** lo comprobaba, y la regla 6 solo vigila a los proveedores | *Confiar en la revisión*: es la definición de acuerdo de caballeros, y este proyecto ya decidió que una regla que no puede fallar no protege nada |
