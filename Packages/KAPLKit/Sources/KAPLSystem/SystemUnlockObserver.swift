import Foundation

/// Reports when the user unlocks the macOS lock screen.
@MainActor
public final class SystemUnlockObserver {
    nonisolated(unsafe) private var token: (any NSObjectProtocol)?

    public init(onUnlock: @escaping @MainActor () -> Void) {
        token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onUnlock() }
        }
    }

    deinit {
        if let token {
            DistributedNotificationCenter.default().removeObserver(token)
        }
    }
}
