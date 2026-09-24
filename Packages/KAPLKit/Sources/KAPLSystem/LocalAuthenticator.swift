import KAPLCore
import LocalAuthentication

/// Touch ID via LocalAuthentication; this app never sees the password.
///
/// When `presentTouchID` is set, Touch ID runs inside the shield (an
/// `LAAuthenticationView` paired with the context), so touching the sensor
/// unlocks with no system alert. Without usable Touch ID (lid closed, not
/// enrolled, locked out), the system password prompt is the fallback.
@MainActor
public final class LocalAuthenticator: Authenticating {
    /// Pairs the context with a view in the shield. Must run before the
    /// context is evaluated, or macOS shows its own alert instead.
    public var presentTouchID: (@MainActor (LAContext) -> Void)?

    public init() {}

    public func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()

        if let presentTouchID, context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            presentTouchID(context)
            return await evaluate(context, policy: .deviceOwnerAuthenticationWithBiometrics, reason: reason)
        }

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failure(Self.failure(for: error))
        }
        return await evaluate(context, policy: .deviceOwnerAuthentication, reason: reason)
    }

    private func evaluate(_ context: LAContext, policy: LAPolicy, reason: String) async -> AuthResult {
        await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                continuation.resume(returning: success ? .success : .failure(Self.failure(for: error)))
            }
        }
    }

    nonisolated static func failure(for error: (any Error)?) -> AuthFailure {
        guard let error else { return .unavailable }
        guard let laError = error as? LAError else { return .systemError }

        switch laError.code {
        case .userCancel, .systemCancel, .appCancel, .userFallback:
            return .cancelled
        case .authenticationFailed:
            return .rejected
        case .biometryLockout:
            return .lockedOut
        case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled, .notInteractive:
            return .unavailable
        default:
            return .systemError
        }
    }
}
