import Foundation

public enum AuthFailure: Equatable, Sendable {
    /// The user or the system dismissed the prompt. Not counted as an attempt.
    case cancelled
    /// Wrong finger or password.
    case rejected
    /// No way to authenticate on this Mac right now.
    case unavailable
    /// Biometry is locked out after too many failures.
    case lockedOut
    case systemError
}

public enum AuthResult: Equatable, Sendable {
    case success
    case failure(AuthFailure)
}

/// Why the shield can no longer guarantee that input is blocked.
public enum BreachReason: Equatable, Sendable {
    /// Another app became active and the shield could not take focus back.
    case lostFocus
}

public enum EscalationReason: Equatable, Sendable {
    case tooManyFailures
    case authenticationUnavailable
    case shieldBreached(BreachReason)
}

/// Inputs to the lock state machine.
public enum LockEvent: Equatable, Sendable {
    case lockRequested(LockMode, at: Date)
    /// Someone touched the keyboard, mouse or trackpad on the shield.
    case unlockRequested
    case authenticationFinished(AuthResult, at: Date)
    case cooldownElapsed(at: Date)
    case breachDetected(BreachReason)
    case systemLockEngaged
    case systemLockFailed
    /// The user unlocked the macOS lock screen.
    case systemSessionUnlocked
}

/// Side effects the state machine asks the coordinator to perform.
public enum LockEffect: Equatable, Sendable {
    case preventSleep
    case allowSleep
    case authenticate
    case scheduleCooldownEnd(Date)
    /// Hand protection over to the macOS lock screen.
    case escalate(EscalationReason)
}
