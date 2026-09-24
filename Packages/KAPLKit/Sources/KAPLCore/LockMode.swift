/// How the shield presents the locked session.
public enum LockMode: String, Sendable, Codable, CaseIterable {
    /// Opaque shield showing only the lock status. The default.
    case privacy
    /// Opaque shield with a safe task-status panel.
    case monitor
    /// Desktop stays visible, input is blocked. Not a privacy mode.
    case transparent
}
