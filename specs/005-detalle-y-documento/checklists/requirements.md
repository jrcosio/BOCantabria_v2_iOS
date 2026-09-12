# Specification Quality Checklist: Del titular al documento oficial

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

- **Sobre «sin detalles de implementación», comprobado y no supuesto.** Una búsqueda sobre el fichero
  no encuentra el nombre del lenguaje, ni el del marco de interfaz, ni el del visor de documentos, ni
  el del algoritmo de la suma de verificación, ni el protocolo, ni la firma de los primeros bytes de
  un documento portátil. Donde hacía falta nombrar algo se nombra **por su función**: «canal seguro»,
  «servicio del boletín», «documento portátil», «suma de verificación», «el marco del visor». Es una
  feature con mucha frontera técnica y ése era el riesgo principal de esta especificación.

- **Sobre la cifra que sí aparece.** El límite de 25 MB de descarga y el presupuesto de 100 MiB de
  caché están en *Assumptions* con nombre y apellidos. **No son detalles de implementación: son
  decisiones de producto** —cuánto de los datos y del almacenamiento de la persona puede gastar la
  aplicación—, y por eso llevan también escrito de dónde salen y que se pueden revisar antes de
  planificar sin tocar ningún requisito. Dejarlas sin número habría hecho FR-020 y FR-030 no
  comprobables.

- **Sobre por qué no hay ningún `[NEEDS CLARIFICATION]`.** Las dos preguntas abiertas de verdad —la
  cabecera del detalle y el orden de sus datos— las dejó aplazadas el documento de diseño y **se
  resolvieron con el propietario antes de escribir esto**, el 12 de septiembre de 2026. Están en
  FR-007 y FR-011, y su porqué en *Procedencia*. Lo que queda por decidir es **mecanismo**, que es
  materia de `plan.md` y no de aquí: cómo se desplaza la cabecera con las pestañas quedándose, cómo
  se encierra el marco del visor, y cómo dos peticiones del mismo documento acaban en una descarga.
  La sección de suposiciones lo dice expresamente.

- **Sobre los requisitos que parecen técnicos y no lo son.** FR-018 a FR-024 describen **qué se
  comprueba antes de creerle al servicio**, no con qué. Están así de detallados a propósito: son la
  historia 2 entera, y son la diferencia entre una aplicación que enseña el boletín y una que enseña
  lo que le dieron. FR-023 —la huella se escribe antes que el documento— parece un detalle de
  fontanería y es un requisito de producto: sin ese orden existe una ventana en la que un documento
  bueno se declara obsoleto, y regenerar lo que depende de él cuesta cuota.

- **Sobre FR-029 y SC-006, que son el mismo requisito visto dos veces.** «Ninguna pantalla se queda
  cargando» suena a obviedad y es el defecto de severidad media que la auditoría de la aplicación de
  origen encontró: un fallo devuelto y no publicado. Por eso el criterio de éxito exige comprobarlo
  **para cada camino**, no en general.

- **Sobre los dos requisitos que no pidió el propietario**: FR-051, el modelo de pantalla de Inicio
  que nace en cada redibujado, y FR-052, la regla que encierra el marco del visor. Ninguno es alcance
  añadido por gusto. El primero es un defecto que **esta feature empeora** —la pila de navegación del
  detalle redibuja el armazón en cada entrada y cada retroceso—, así que arreglarlo aquí es más
  barato que convivir con él; el segundo lo exige literalmente la constitución y hasta ahora no lo
  comprobaba nada. Los dos están en *Procedencia* con su motivo.

- **Sobre el alcance, que es grande y está acotado por escrito.** Entran cuatro historias, dos
  pantallas nuevas y una copia local de documentos. Quedan fuera, dichas una por una en
  *Assumptions*: el resumen de IA y la conversación —de los que solo se reserva el sitio—, guardar
  publicaciones, buscar dentro del documento, el menú de más opciones del visor y la extracción de
  texto con su modo lectura.

- **Riesgo anotado, y es el mayor de la feature.** La tarjeta de publicación pasa a ser pulsable y
  además cambia lo que comparte. Ocho aserciones de pruebas de interfaz penden de su árbol de
  accesibilidad —dos de ellas miden su alto a dos tamaños de letra y el marco de su acción de
  compartir—, y son justo las tres cosas que un envoltorio pulsable altera. Ninguna se silencia: el
  árbol se vuelca antes del cambio y se compara después.

- **Segundo riesgo anotado**: FR-011 pide que la cabecera se vaya y las pestañas se queden, que es
  **lo contrario** de lo que la feature anterior hizo en Inicio. La tentación de reutilizar aquel
  mecanismo porque «ya estaba resuelto» es exactamente la trampa número uno declarada en la guía del
  proyecto, y el `research.md` tiene que comparar las dos formas en vez de copiar una.

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
