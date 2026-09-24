import Darwin
import KAPLCore

/// Engages the real macOS lock screen, the same one as Control-Command-Q.
///
/// Uses `SACLockScreenImmediate` from the private login.framework: macOS has
/// no public API for this. Fine for Developer ID distribution, not allowed on
/// the Mac App Store. If the symbol ever disappears, `lockNow()` returns false
/// and our shield simply stays up.
@MainActor
public final class SystemScreenLocker: SystemLocking {
    private typealias LockScreenImmediate = @convention(c) () -> Int32

    private static let frameworkPath = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"

    public init() {}

    public func lockNow() -> Bool {
        guard
            let handle = dlopen(Self.frameworkPath, RTLD_LAZY),
            let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return false }

        let lockScreen = unsafeBitCast(symbol, to: LockScreenImmediate.self)
        return lockScreen() == 0
    }
}
