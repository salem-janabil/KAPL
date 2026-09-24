import KAPLCore
import KAPLSystem
import KAPLUI

/// Composition root: the only place that knows every concrete type.
@MainActor
final class AppEnvironment {
    let coordinator: LockCoordinator

    private let shield: ShieldController
    private let menuBar: MenuBarController
    private let lockHotKey: GlobalHotKey
    private let unlockObserver: SystemUnlockObserver

    init() {
        let shield = ShieldController()
        let authenticator = LocalAuthenticator()
        authenticator.presentTouchID = { [weak shield] context in shield?.showTouchID(for: context) }

        let coordinator = LockCoordinator(
            policy: .default,
            authenticator: authenticator,
            sleepPreventer: PowerAssertionSleepPreventer(scope: .systemAndDisplay),
            systemLock: SystemScreenLocker(),
            shield: shield
        )

        shield.onUnlockRequest = { [weak coordinator] in coordinator?.requestUnlock() }
        shield.onBreach = { [weak coordinator] reason in coordinator?.reportBreach(reason) }

        self.shield = shield
        self.coordinator = coordinator
        self.menuBar = MenuBarController { [weak coordinator] in coordinator?.lock() }
        self.lockHotKey = GlobalHotKey(
            keyCode: GlobalHotKey.lockShortcut.keyCode,
            modifiers: GlobalHotKey.lockShortcut.modifiers
        ) { [weak coordinator] in coordinator?.lock() }
        self.unlockObserver = SystemUnlockObserver { [weak coordinator] in coordinator?.systemSessionDidUnlock() }
    }
}
