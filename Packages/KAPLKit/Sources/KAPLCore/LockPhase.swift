import Foundation

/// Facts about one lock, from engaging the shield until the user is back.
public struct LockSession: Equatable, Sendable {
    public let mode: LockMode
    public let lockedAt: Date
    public internal(set) var failedAttempts: Int

    public init(mode: LockMode, lockedAt: Date, failedAttempts: Int = 0) {
        self.mode = mode
        self.lockedAt = lockedAt
        self.failedAttempts = failedAttempts
    }
}

public enum LockPhase: Equatable, Sendable {
    case unlocked
    /// Shield is up and waiting for the user.
    case locked(LockSession)
    /// The system authentication prompt is in progress.
    case authenticating(LockSession)
    /// Too many failed attempts; unlock requests are ignored until `until`.
    case coolingDown(LockSession, until: Date)
    /// Protection was handed over to the macOS lock screen. Background work
    /// keeps running; the phase ends when the user unlocks macOS itself.
    case escalated(LockSession)

    public var session: LockSession? {
        switch self {
        case .unlocked:
            nil
        case .locked(let session), .authenticating(let session),
             .coolingDown(let session, _), .escalated(let session):
            session
        }
    }

    /// Whether our own shield must cover the screens in this phase.
    public var requiresShield: Bool {
        switch self {
        case .locked, .authenticating, .coolingDown: true
        case .unlocked, .escalated: false
        }
    }
}
