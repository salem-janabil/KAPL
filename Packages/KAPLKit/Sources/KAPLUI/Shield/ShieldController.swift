import AppKit
import KAPLCore
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
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var focusCheck: Task<Void, Never>?

    private var isEngaged: Bool { eventMonitor != nil }

    private static let kioskOptions: NSApplication.PresentationOptions = [
        .hideDock,
        .hideMenuBar,
        .disableAppleMenu,
        .disableProcessSwitching,
        .disableForceQuit,
        .disableSessionTermination,
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

        guard phase.requiresShield else {
            disengage()
            return
        }
        if !isEngaged {
            engage()
        }
        // The system auth prompt belongs to another process and takes focus
        // while it is up. Once it is gone, take focus back.
        if case .authenticating = phase {
            focusCheck?.cancel()
        } else {
            reclaimFocus()
        }
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
    }

    private func disengage() {
        guard isEngaged else { return }

        focusCheck?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
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
        windows = NSScreen.screens.map { screen in
            let window = ShieldWindow(screen: screen)
            window.contentView = NSHostingView(rootView: ShieldContentView(model: model))
            window.orderFrontRegardless()
            return window
        }
        windows.first?.makeKey()
    }

    // MARK: - Focus

    private func appDidResignActive() {
        if case .authenticating = model.phase { return }
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
