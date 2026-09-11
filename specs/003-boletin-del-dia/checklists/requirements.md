# Specification Quality Checklist: Boletín del día — lectura del BOC y pantalla de Inicio

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-11
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- **Sobre «sin detalles de implementación», comprobado y no supuesto**: una búsqueda sobre el
  fichero no encuentra ni una vez el motor de persistencia, el cliente de red, el analizador, el
  formato de intercambio, ningún marco de interfaz ni ningún nombre de lenguaje. Las únicas
  menciones a plataforma están en el apartado **Input** y en **Assumptions**, y son de
  **procedencia** —de dónde vienen los requisitos—, no de diseño. Donde hacía falta nombrar algo se
  nombra por su función: «las diecinueve fuentes oficiales», «el campo de clasificación», «lo
  guardado».

- **Sobre el alcance acotado**: la frontera está escrita en tres sitios a propósito —las
  suposiciones, los requisitos del marco de navegación y los criterios de éxito—. Lo que **no**
  entra: las notificaciones y los avisos por completo; el detalle de la publicación y cualquier
  trato con el documento en PDF, que es la feature siguiente; y el contenido real de Buscar y
  Guardados, que existen como destinos para fijar la estructura. La lupa de la barra superior
  **no** es todavía un filtro de la lista: se dice expresamente, porque ese control existe en la
  aplicación de origen y confundirlo sería ampliar el alcance sin darse cuenta.

- **Sobre las dos historias con prioridad P1**: es deliberado y está heredado. La historia 1 y la
  historia 2 comparten el camino de datos, y una aplicación de consulta oficial que solo funciona
  con cobertura no es un producto entregable. Ninguna de las dos es el MVP por sí sola; el MVP es
  la primera, y la segunda es lo que la hace defendible.

- **Sobre las cuatro decisiones que en el origen fueron ambiguas**: composición de la barra
  superior, alcance del listado al elegir una sección, qué va donde el diseño original ponía un
  número de boletín, y cuándo sincronizar. Las cuatro se plantearon al propietario en su momento y
  están resueltas en FR-031, FR-037/FR-038, FR-036 y FR-023/FR-024. No se vuelven a abrir.

- **Sobre las tres decisiones propias de este port**, acordadas con el propietario antes de
  redactar y registradas en *Procedencia*: llegar al estado final en lugar de al histórico —que es
  lo que trae los requisitos de los chips, del rótulo de la fecha y del panel—, portar el panel
  como panel lateral, y mantenerlo todo en una sola feature. Ninguna necesita
  `[NEEDS CLARIFICATION]` porque ninguna quedó abierta.

- **Sobre FR-036, que contradice al documento de diseño original a propósito**: el diseño ponía un
  número de boletín junto al escudo. El servicio oficial **no lo publica** en las fuentes que la
  aplicación consume, y escribirlo sería presentar como oficial un dato fabricado. Se sustituye por
  el recuento de anuncios, que es un dato real. Es la misma decisión que tomó el propietario en la
  aplicación de origen.

- **Sobre FR-081, que es una obligación documental y no de producto**: existe porque el documento
  de diseño es la fuente de verdad de lo visual, y una fuente de verdad que contradice a la
  aplicación deja de serlo. Esta feature arrastra tres desviaciones vivas y dos apartados del
  propio documento que sus enmiendas dejaron obsoletos.

- **Decisiones que el plan debe tomar, ya acotadas por la especificación**: cómo se persiste y cómo
  se observa lo guardado (FR-019), cómo se piden las fuentes con un tope de simultaneidad (FR-005),
  cómo se analiza el contenido de forma endurecida (FR-008), cómo se conserva la selección frente a
  la terminación del proceso (FR-068) y cómo se construye el panel lateral con sus gestos (FR-057,
  FR-064). Ninguna es un `[NEEDS CLARIFICATION]`: los requisitos son comprobables tal como están y
  lo que falta por elegir es el mecanismo, que es materia de `plan.md` y de `research.md`.

- **Riesgo de alcance, anotado**: son dos trabajos en una misma feature —leer el boletín y
  dibujarlo—, y el punto de corte natural está entre la historia 2 y la historia 3. Si hubiera que
  partir la entrega, las historias 1 y 2 ya son una aplicación que sirve.

- **Escala a vigilar**: la primera sincronización ronda las mil novecientas publicaciones repartidas
  en diecinueve fuentes. SC-002 obliga a que la pantalla no espere a todas para pintar.

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
