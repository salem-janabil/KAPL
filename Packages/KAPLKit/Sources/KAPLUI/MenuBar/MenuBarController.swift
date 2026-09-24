import AppKit

/// The status-bar icon: the app's only UI while unlocked.
@MainActor
public final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onLock: @MainActor () -> Void

    public init(onLock: @escaping @MainActor () -> Void) {
        self.onLock = onLock
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Keep-Alive Privacy Lock")

        let menu = NSMenu()
        let lockItem = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit KAPL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func lockNow() {
        onLock()
    }
}
