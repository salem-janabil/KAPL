import AppKit

/// A borderless window that covers one screen, on every Space, and blurs
/// everything under it: the desktop, windows, Dock and menu bar stay faintly
/// visible but unreadable.
final class ShieldWindow: NSWindow {
    /// Above regular windows, the Dock and the menu bar.
    static let shieldLevel = NSWindow.Level.screenSaver

    // MARK: - Blur settings

    /// How strongly the screen under the shield is blurred. At 12 only
    /// shapes and colors remain; at 4 text under the shield is readable.
    static let blurRadius = 10
    /// Darkening over the blur, from 0 (none) to 1 (black). Keeps the white
    /// text on the shield readable over light windows.
    static let dimming = 0.25

    init(screen: NSScreen, content: NSView) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = Self.shieldLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(Self.dimming)
        hasShadow = false
        isMovable = false
        animationBehavior = .none

        if WindowBlur.apply(radius: Self.blurRadius, to: self) {
            contentView = content
        } else {
            contentView = Self.systemBlur(around: content)
        }
    }

    /// Fallback with a fixed, stronger blur for when the adjustable one is
    /// unavailable: the shield must never leave the screen unblurred.
    private static func systemBlur(around content: NSView) -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        content.frame = blur.bounds
        content.autoresizingMask = [.width, .height]
        blur.addSubview(content)
        return blur
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Keep the window over the menu bar area instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
