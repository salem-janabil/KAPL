import KAPLCore
import LocalAuthentication

/// Touch ID with the system password prompt as fallback, via LocalAuthentication.
/// The prompt is drawn by macOS; this app never sees the password.
@MainActor
public final class LocalAuthenticator: Authenticating {
    private static let policy = LAPolicy.deviceOwnerAuthentication

    public init() {}

    public func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(Self.policy, error: &error) else {
            return .failure(Self.failure(for: error))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(Self.policy, localizedReason: reason) { success, error in
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
