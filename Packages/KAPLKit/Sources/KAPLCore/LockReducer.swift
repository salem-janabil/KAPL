import Foundation

/// The lock state machine as a pure function: all security decisions live
/// here, so they can be unit tested without a Mac to lock.
///
/// Any doubt resolves toward more protection: when our shield cannot be
/// trusted, the reducer escalates to the macOS lock screen, which also keeps
/// background work running.
public enum LockReducer {
    public static func reduce(
        _ phase: inout LockPhase,
        _ event: LockEvent,
        policy: LockPolicy
    ) -> [LockEffect] {
        switch (phase, event) {
        case (.unlocked, .lockRequested(let mode, let at)):
            phase = .locked(LockSession(mode: mode, lockedAt: at))
            return [.preventSleep]

        case (.locked(let session), .unlockRequested):
            phase = .authenticating(session)
            return [.authenticate]

        case (.authenticating, .authenticationFinished(.success, _)):
            phase = .unlocked
            return [.allowSleep]

        case (.authenticating(let session), .authenticationFinished(.failure(let failure), let at)):
            return registerFailure(failure, session: session, at: at, phase: &phase, policy: policy)

        case (.coolingDown(let session, let until), .cooldownElapsed(let at)) where at >= until:
            phase = .locked(session)
            return []

        case (.locked, .breachDetected(let reason)),
             (.authenticating, .breachDetected(let reason)),
             (.coolingDown, .breachDetected(let reason)):
            return [.escalate(.shieldBreached(reason))]

        case (.locked(let session), .systemLockEngaged),
             (.authenticating(let session), .systemLockEngaged),
             (.coolingDown(let session, _), .systemLockEngaged):
            // Sleep prevention stays on: the work must survive the system lock.
            phase = .escalated(session)
            return []

        case (.escalated, .systemSessionUnlocked):
            phase = .unlocked
            return [.allowSleep]

        default:
            // Includes .systemLockFailed: the shield simply stays up.
            return []
        }
    }

    private static func registerFailure(
        _ failure: AuthFailure,
        session: LockSession,
        at now: Date,
        phase: inout LockPhase,
        policy: LockPolicy
    ) -> [LockEffect] {
        switch failure {
        case .cancelled:
            phase = .locked(session)
            return []

        case .unavailable, .lockedOut:
            phase = .locked(session)
            return [.escalate(.authenticationUnavailable)]

        case .rejected, .systemError:
            var session = session
            session.failedAttempts += 1

            if session.failedAttempts >= policy.failuresBeforeEscalation {
                // Also cool down, so attempts stay throttled if escalation fails.
                let until = now.addingTimeInterval(policy.cooldownDuration)
                phase = .coolingDown(session, until: until)
                return [.escalate(.tooManyFailures), .scheduleCooldownEnd(until)]
            }
            if session.failedAttempts.isMultiple(of: policy.failuresPerCooldown) {
                let until = now.addingTimeInterval(policy.cooldownDuration)
                phase = .coolingDown(session, until: until)
                return [.scheduleCooldownEnd(until)]
            }
            phase = .locked(session)
            return []
        }
    }
}
