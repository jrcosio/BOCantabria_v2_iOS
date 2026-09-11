# Specification Quality Checklist: La tarjeta se lee de un vistazo, y la cabecera no se va

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-12
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

- **Sobre «sin detalles de implementación»**: una búsqueda sobre el fichero no encuentra ni un marco
  de interfaz, ni un tipo de vista, ni una llamada del sistema. Donde hacía falta nombrar algo se
  nombra por su función: «la zona que no se desplaza», «la escala tipográfica del sistema de
  diseño». **Cómo se detecta el desplazamiento y con qué se compacta la cabecera son las dos
  preguntas que el plan tiene que responder**, y la sección de suposiciones lo dice expresamente.

- **Sobre la sección sin entidades**: es deliberado y va escrito en vez de omitido. Esta feature no
  introduce, modifica ni consulta ningún dato, y decirlo es lo que evita que alguien busque el
  `data-model.md` que no va a existir.

- **Sobre «los cuatro datos se distinguen por tamaño»** (FR-001, SC-001): parece vago y no lo es,
  porque FR-018 lo convierte en una comprobación mecánica —dos datos que midan lo mismo ponen algo
  en rojo—. Sin esa pareja, el requisito sería una opinión.

- **Sobre los dos requisitos que no pidió el propietario**: FR-005, el apilado de la fila de
  acciones, y FR-013, el fondo sólido con divisor. Los dos salen del propio documento de diseño
  —apartados 31.2, 31.3 y 14.6— y se descubrieron al inventariar qué contradecía el cambio. No son
  alcance añadido por gusto: sin ellos, el cambio pedido rompería reglas que el documento ya tenía
  escritas.

- **Sobre qué sustituye**: FR-039 de la 003 enumeraba la fecha y las acciones como dos pasos
  consecutivos, y juntarlas lo contradice. Se sustituye desde aquí y **no se reescribe la 003**: es
  una feature cerrada e integrada, y editar su especificación convertiría su historia en algo que no
  ocurrió. La sección de procedencia lo deja escrito.

- **Decisión que el plan debe tomar, ya acotada por la especificación**: con qué mecanismo se sabe
  que el listado se ha desplazado, y cómo se evita que la cabecera se redibuje en cada fotograma.
  Esto **no** es un `[NEEDS CLARIFICATION]`: FR-010 y FR-012 son comprobables tal como están y lo
  que falta por elegir es el mecanismo, que es materia de `plan.md`.

- **Riesgo anotado**: nueve pruebas de interfaz de la 003 usan el listado como puerta de entrada y
  dos afirman sobre la etiqueta de accesibilidad de la tarjeta. Reorganizar el contenedor de
  desplazamiento y poner el organismo en mayúsculas las toca a todas; ninguna se silencia.

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
