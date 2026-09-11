//
//  ManualClockTests.swift
//
//  El doble del reloj es infraestructura de la que dependen las pruebas de la caducidad, del
//  límite de espera del arranque y de los reintentos. Si se rompe, esas pruebas no fallan: se
//  cuelgan, o pasan sin comprobar nada. Por eso tiene pruebas propias.
//

import Foundation
import Synchronization
import Testing
@testable import BOCantabria_ios

@Suite("Reloj manual")
struct ManualClockTests {

    @Test("Su «ahora» no se mueve solo")
    func nowDoesNotMoveOnItsOwn() {
        let clock = ManualClock()
        let first = clock.now()
        #expect(clock.now() == first)
    }

    @Test("Adelantar el tiempo mueve el «ahora» exactamente lo pedido")
    func advancingMovesNow() async {
        let clock = ManualClock()
        let before = clock.now()
        await clock.advance(by: 1_800)
        #expect(clock.now().timeIntervalSince(before) == 1_800)
    }

    @Test("Una espera no vuelve hasta que la prueba adelanta el reloj")
    func aSleepWaitsForTheTestToAdvance() async throws {
        let clock = ManualClock()
        let finished = Mutex(false)

        let task = Task {
            try await clock.sleep(seconds: 30)
            finished.withLock { $0 = true }
        }

        // `waitUntilSleeping` es lo que evita la carrera: sin él, el adelanto podría llegar antes
        // de que la espera se registre, perderse, y colgar la prueba en vez de fallarla.
        await clock.waitUntilSleeping()
        #expect(!finished.withLock { $0 })

        await clock.advance(by: 30)
        try await task.value
        #expect(finished.withLock { $0 })
    }

    @Test("Registra qué se esperó, no solo cuánto")
    func recordsWhatWasRequested() async throws {
        let clock = ManualClock()
        let task = Task {
            try await clock.sleep(seconds: 2)
            try await clock.sleep(seconds: 5)
        }
        await clock.waitUntilSleeping(count: 1)
        await clock.advance(by: 2)
        await clock.waitUntilSleeping(count: 2)
        await clock.advance(by: 5)
        try await task.value
        #expect(clock.requestedSleeps == [2, 5])
    }

    @Test("Una espera cancelada muere en el acto, sin que nadie adelante nada")
    func aCancelledSleepDiesImmediately() async {
        let clock = ManualClock()
        let task = Task { try await clock.sleep(seconds: 8) }
        await clock.waitUntilSleeping()
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test("El reloj inmediato tampoco lee la hora del sistema")
    func theImmediateClockIsNotTheSystemClock() {
        // Si devolviera `Date()` sería el reloj del sistema disfrazado y las pruebas volverían a
        // depender de cuándo se ejecutan.
        #expect(ImmediateClock().now() == ImmediateClock.fixedNow)
        #expect(ImmediateClock().now() == ImmediateClock().now())
    }

    @Test("La aleatoriedad fija deja el jitter en el centro, y la extrema en los bordes")
    func fixedRandomnessIsPredictable() {
        #expect(FixedRandom(0.5).jittered(5) == 5)
        #expect(FixedRandom(0).jittered(5) == 4)      // 5 − 20 %
        #expect(FixedRandom(1).jittered(5) == 6)      // 5 + 20 %
    }
}
