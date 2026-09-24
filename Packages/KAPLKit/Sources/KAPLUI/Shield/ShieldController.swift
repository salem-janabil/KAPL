import AppKit
import KAPLCore
import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import SwiftUI

/// Covers every screen while the session is locked and swallows all input.
///
/// Input blocking relies on kiosk presentation options plus a local event
/// monitor, not a global event tap, so it needs no Accessibility permission.
/// The catch: it only works while this app is active. Losing focus is
/// therefore reported as a breach, and the core escalates to the macOS lock.
@MainActor
public final class ShieldController: ShieldPresenting {
    public var onUnlockRequest: (@MainActor () -> Void)?
    public var onBreach: (@MainActor (BreachReason) -> Void)?

    private let model = ShieldViewModel()
    private var windows: [ShieldWindow] = []
    private var eventMonitor: Any?
    private var observers: [any NSObjectProtocol] = []
    private var workspaceObserver: (any NSObjectProtocol)?
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var focusCheck: Task<Void, Never>?

    private var isEngaged: Bool { eventMonitor != nil }

    /// The Dock and menu bar stay on screen so they show through the blur.
    /// AppKit rejects every other kiosk option unless the Dock is hidden, so
    /// ⌘Tab, Force Quit and log out are not blocked. They take focus from
    /// the shield, which takes it back at once or else escalates.
    private static let kioskOptions: NSApplication.PresentationOptions = [
        .disableHideApplication,
    ]

    private static let blockedEvents: NSEvent.EventTypeMask = [
        .keyDown, .keyUp, .flagsChanged,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel, .magnify, .rotate, .swipe, .smartMagnify,
    ]

    private static let unlockTriggers: Set<NSEvent.EventType> = [
        .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    public init() {}

    public func render(_ phase: LockPhase) {
        model.phase = phase
        if case .authenticating = phase {} else {
            model.touchIDView = nil
        }

        guard phase.requiresShield else {
            disengage()
            return
        }
        if !isEngaged {
            engage()
        }
        // The system password prompt belongs to another process and takes
        // focus while it is up. Otherwise the shield keeps focus.
        if systemPromptIsUp {
            focusCheck?.cancel()
        } else {
            reclaimFocus()
        }
    }

    /// Runs Touch ID inside the shield for this context instead of the
    /// system alert: touching the sensor is all it takes. Must be called
    /// before the context is evaluated.
    public func showTouchID(for context: LAContext) {
        model.touchIDView = LAAuthenticationView(context: context, controlSize: .small)
        reclaimFocus()
    }

    // MARK: - Engage / disengage

    private func engage() {
        Self.forceActivate()
        rebuildWindows()

        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = Self.kioskOptions

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.blockedEvents) { [weak self] event in
            if Self.unlockTriggers.contains(event.type) {
                self?.onUnlockRequest?()
            }
            return nil
        }

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuildWindows() }
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appDidResignActive() }
            },
        ]
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appDidActivate(app) }
        }
    }

    private func disengage() {
        guard isEngaged else { return }

        focusCheck?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil

        NSApp.presentationOptions = savedPresentationOptions
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    /// One window per screen; called again whenever displays change.
    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = Self.screensMainFirst().enumerated().map { index, screen in
            let content = NSHostingView(rootView: ShieldContentView(model: model, isMainScreen: index == 0))
            // The window must cover its screen whatever the content: an empty
            // hosting view would otherwise shrink it to nothing, and nothing
            // would be blurred.
            content.sizingOptions = []
            let window = ShieldWindow(screen: screen, content: content)
            window.orderFrontRegardless()
            return window
        }
        windows.first?.makeKey()
    }

    /// The main screen, which shows the Touch ID hint, is the MacBook's own
    /// display, next to the sensor. With the lid closed it is the screen
    /// with the menu bar.
    private static func screensMainFirst() -> [NSScreen] {
        var screens = NSScreen.screens
        if let builtIn = screens.firstIndex(where: \.isBuiltIn) {
            screens.insert(screens.remove(at: builtIn), at: 0)
        }
        return screens
    }

    // MARK: - Focus

    /// The system password prompt (the fallback when Touch ID is not usable)
    /// is up and holds focus. Touch ID inside the shield does not take it.
    private var systemPromptIsUp: Bool {
        if case .authenticating = model.phase {
            return model.touchIDView == nil
        }
        return false
    }

    /// While the system prompt is up the shield does not hold focus, and
    /// ⌘Tab is not blocked. The prompt's agent is not a regular app; a
    /// regular app getting focus would receive the keyboard behind the blur.
    private func appDidActivate(_ app: NSRunningApplication?) {
        guard systemPromptIsUp, app?.activationPolicy == .regular else { return }

        // The prompt closing can hand focus to another app just before its
        // result arrives: only a switch that lasts is a breach.
        focusCheck?.cancel()
        focusCheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled, self.systemPromptIsUp,
                  NSWorkspace.shared.frontmostApplication?.activationPolicy == .regular
            else { return }
            self.onBreach?(.appActivatedDuringAuthentication)
        }
    }

    private func appDidResignActive() {
        if systemPromptIsUp { return }
        reclaimFocus()
    }

    /// Takes focus back; if the system refuses, the shield can no longer
    /// block input and reports a breach.
    private func reclaimFocus() {
        Self.forceActivate()
        windows.first?.makeKeyAndOrderFront(nil)

        focusCheck?.cancel()
        focusCheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled, self.isEngaged else { return }
            if !NSApp.isActive {
                self.onBreach?(.lostFocus)
            }
        }
    }

    /// Cooperative `NSApp.activate()` (macOS 14+) is only a request, and the
    /// system turns it down for a menu bar app when another app is frontmost:
    /// the shield came up without focus and escalated right away. The
    /// deprecated forcing call is still honored, so use it.
    private static func forceActivate() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension NSScreen {
    var isBuiltIn: Bool {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
