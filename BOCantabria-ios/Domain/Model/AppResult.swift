//
//  AppResult.swift
//  What every domain operation returns.
//
//  Es un alias sobre el `Result` de la biblioteca estándar, no un tipo propio, y es una decisión
//  (research.md D-101). El proyecto Android escribió el suyo porque `kotlin.Result` lleva un
//  `Throwable` dentro: el error quedaba opaco y el `when` de la pantalla no podía ser exhaustivo.
//  El `Result` de Swift **sí** es genérico en el error, así que da exactamente esa garantía sin
//  escribir nada, y trae hechos `map`, `flatMap`, `mapError` y `get()`.
//
//  Invariante que no se negocia: **una colección vacía es un éxito**, nunca un fallo. «Vacío» y
//  «error» se distinguen en la capa de presentación.
//

typealias AppResult<Success> = Result<Success, DomainError>
