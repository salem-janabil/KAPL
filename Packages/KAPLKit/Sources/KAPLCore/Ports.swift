// Ports: what the core needs from the outside world. Adapters live in
// KAPLSystem (macOS services) and KAPLUI (the shield itself).

@MainActor
public protocol Authenticating: AnyObject {
    /// Asks the device owner to prove their identity (Touch ID or the system
    /// password prompt). Must never collect or store the password itself.
    func authenticate(reason: String) async -> AuthResult
}

@MainActor
public protocol SleepPreventing: AnyObject {
    func begin(reason: String)
    func end()
}

@MainActor
public protocol SystemLocking: AnyObject {
    /// Engages the macOS lock screen. Returns false if it could not.
    func lockNow() -> Bool
}

@MainActor
public protocol ShieldPresenting: AnyObject {
    /// Called after every phase change. Must be idempotent: the shield
    /// derives what to show purely from the phase it is given.
    func render(_ phase: LockPhase)
}
