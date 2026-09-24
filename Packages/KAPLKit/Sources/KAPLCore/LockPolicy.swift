import Foundation

public struct LockPolicy: Equatable, Sendable {
    /// Every this many failed attempts, unlocking pauses for `cooldownDuration`.
    public var failuresPerCooldown: Int
    public var cooldownDuration: TimeInterval
    /// After this many failed attempts the macOS lock screen takes over.
    public var failuresBeforeEscalation: Int

    public init(
        failuresPerCooldown: Int = 3,
        cooldownDuration: TimeInterval = 30,
        failuresBeforeEscalation: Int = 6
    ) {
        self.failuresPerCooldown = failuresPerCooldown
        self.cooldownDuration = cooldownDuration
        self.failuresBeforeEscalation = failuresBeforeEscalation
    }

    public static let `default` = LockPolicy()
}
