import Foundation
import Testing
@testable import KAPLCore

struct LockReducerTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let policy = LockPolicy(failuresPerCooldown: 3, cooldownDuration: 30, failuresBeforeEscalation: 6)

    private func locked(failed: Int = 0) -> LockPhase {
        .locked(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: failed))
    }

    private func authenticating(failed: Int = 0) -> LockPhase {
        .authenticating(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: failed))
    }

    @Test func lockingPreventsSleep() {
        var phase = LockPhase.unlocked
        let effects = LockReducer.reduce(&phase, .lockRequested(.privacy, at: t0), policy: policy)
        #expect(phase == locked())
        #expect(effects == [.preventSleep])
    }

    @Test func lockingWhileLockedIsIgnored() {
        var phase = locked(failed: 2)
        let effects = LockReducer.reduce(&phase, .lockRequested(.privacy, at: t0 + 5), policy: policy)
        #expect(phase == locked(failed: 2))
        #expect(effects.isEmpty)
    }

    @Test func interactionStartsAuthentication() {
        var phase = locked()
        let effects = LockReducer.reduce(&phase, .unlockRequested, policy: policy)
        #expect(phase == authenticating())
        #expect(effects == [.authenticate])
    }

    @Test func repeatedInteractionDuringAuthenticationIsIgnored() {
        var phase = authenticating()
        let effects = LockReducer.reduce(&phase, .unlockRequested, policy: policy)
        #expect(phase == authenticating())
        #expect(effects.isEmpty)
    }

    @Test func successUnlocksAndAllowsSleep() {
        var phase = authenticating(failed: 2)
        let effects = LockReducer.reduce(&phase, .authenticationFinished(.success, at: t0), policy: policy)
        #expect(phase == .unlocked)
        #expect(effects == [.allowSleep])
    }

    @Test func cancellationDoesNotCountAsFailure() {
        var phase = authenticating(failed: 2)
        let effects = LockReducer.reduce(&phase, .authenticationFinished(.failure(.cancelled), at: t0), policy: policy)
        #expect(phase == locked(failed: 2))
        #expect(effects.isEmpty)
    }

    @Test func rejectionIsCounted() {
        var phase = authenticating()
        _ = LockReducer.reduce(&phase, .authenticationFinished(.failure(.rejected), at: t0), policy: policy)
        #expect(phase == locked(failed: 1))
    }

    @Test func everyThirdFailureCoolsDown() {
        var phase = authenticating(failed: 2)
        let effects = LockReducer.reduce(&phase, .authenticationFinished(.failure(.rejected), at: t0), policy: policy)
        let until = t0 + 30
        #expect(phase == .coolingDown(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: 3), until: until))
        #expect(effects == [.scheduleCooldownEnd(until)])
    }

    @Test func unlockRequestsAreIgnoredDuringCooldown() {
        let cooling = LockPhase.coolingDown(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: 3), until: t0 + 30)
        var phase = cooling
        let effects = LockReducer.reduce(&phase, .unlockRequested, policy: policy)
        #expect(phase == cooling)
        #expect(effects.isEmpty)
    }

    @Test func cooldownEndsOnlyWhenElapsed() {
        let session = LockSession(mode: .privacy, lockedAt: t0, failedAttempts: 3)
        var phase = LockPhase.coolingDown(session, until: t0 + 30)

        _ = LockReducer.reduce(&phase, .cooldownElapsed(at: t0 + 10), policy: policy)
        #expect(phase == .coolingDown(session, until: t0 + 30))

        _ = LockReducer.reduce(&phase, .cooldownElapsed(at: t0 + 30), policy: policy)
        #expect(phase == .locked(session))
    }

    @Test func tooManyFailuresEscalateAndStillThrottle() {
        var phase = authenticating(failed: 5)
        let effects = LockReducer.reduce(&phase, .authenticationFinished(.failure(.rejected), at: t0), policy: policy)
        #expect(phase == .coolingDown(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: 6), until: t0 + 30))
        #expect(effects == [.escalate(.tooManyFailures), .scheduleCooldownEnd(t0 + 30)])
    }

    @Test(arguments: [AuthFailure.unavailable, .lockedOut])
    func unusableAuthenticationEscalates(failure: AuthFailure) {
        var phase = authenticating()
        let effects = LockReducer.reduce(&phase, .authenticationFinished(.failure(failure), at: t0), policy: policy)
        #expect(phase == locked())
        #expect(effects == [.escalate(.authenticationUnavailable)])
    }

    @Test func breachEscalatesWithoutDroppingTheShield() {
        var phase = locked()
        let effects = LockReducer.reduce(&phase, .breachDetected(.lostFocus), policy: policy)
        #expect(phase == locked())
        #expect(phase.requiresShield)
        #expect(effects == [.escalate(.shieldBreached(.lostFocus))])
    }

    @Test func breachWhileUnlockedIsIgnored() {
        var phase = LockPhase.unlocked
        let effects = LockReducer.reduce(&phase, .breachDetected(.lostFocus), policy: policy)
        #expect(phase == .unlocked)
        #expect(effects.isEmpty)
    }

    @Test func failedSystemLockKeepsTheShield() {
        var phase = locked()
        let effects = LockReducer.reduce(&phase, .systemLockFailed, policy: policy)
        #expect(phase == locked())
        #expect(effects.isEmpty)
    }

    @Test func escalationKeepsSleepPreventionUntilMacOSUnlocks() {
        var phase = locked(failed: 1)
        let engaged = LockReducer.reduce(&phase, .systemLockEngaged, policy: policy)
        #expect(phase == .escalated(LockSession(mode: .privacy, lockedAt: t0, failedAttempts: 1)))
        #expect(!phase.requiresShield)
        #expect(engaged.isEmpty)

        let unlocked = LockReducer.reduce(&phase, .systemSessionUnlocked, policy: policy)
        #expect(phase == .unlocked)
        #expect(unlocked == [.allowSleep])
    }

    @Test func systemUnlockDoesNotBypassOurShield() {
        var phase = locked()
        let effects = LockReducer.reduce(&phase, .systemSessionUnlocked, policy: policy)
        #expect(phase == locked())
        #expect(effects.isEmpty)
    }
}
