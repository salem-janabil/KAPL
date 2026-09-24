import AppKit

/// The status-bar icon: the app's only UI while unlocked.
@MainActor
public final class MenuBarController: NSObject {
    /// The default symbol size is noticeably smaller than other menu bar icons.
    private static let iconPointSize: CGFloat = 17

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onLock: @MainActor () -> Void

    public init(onLock: @escaping @MainActor () -> Void) {
        self.onLock = onLock
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Keep-Alive Privacy Lock")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: Self.iconPointSize, weight: .regular))

        let menu = NSMenu()
        // Shows ⌘⎋ next to the item; the shortcut itself is the global hot key.
        let lockItem = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "\u{1b}")
        lockItem.keyEquivalentModifierMask = .command
        lockItem.target = self
        menu.addItem(lockItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func lockNow() {
        onLock()
    }
}
