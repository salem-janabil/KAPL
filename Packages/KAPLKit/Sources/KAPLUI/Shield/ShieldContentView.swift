import AppKit
import KAPLCore
import SwiftUI

struct ShieldContentView: View {
    let model: ShieldViewModel
    /// Only the main screen (the MacBook's own) shows how to unlock; the
    /// others are just blur. The live Touch ID view can exist once anyway.
    let isMainScreen: Bool

    var body: some View {
        // Monitor and Transparent modes are not built yet. Until they are,
        // every mode falls back to Privacy: never show less than intended.
        if isMainScreen {
            PrivacyLockView(phase: model.phase, touchIDView: model.touchIDView)
                .environment(\.colorScheme, .dark)
        }
    }
}

struct PrivacyLockView: View {
    let phase: LockPhase
    /// Set while Touch ID runs inside the shield.
    let touchIDView: NSView?

    // The blur behind the content comes from the window itself: see
    // `ShieldWindow`. On top of it, only how to unlock.
    var body: some View {
        ZStack {
            if phase.requiresShield {
                UnlockHint(phase: phase, touchIDView: touchIDView)
                    .font(.system(size: 17, weight: .medium))
                    .imageScale(.large)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .shieldGlass(in: .capsule)
                    .shake(on: phase.session?.failedAttempts ?? 0)
            }
        }
        .foregroundStyle(.white)
        .animation(.smooth, value: phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    /// Liquid Glass on macOS 26 and later, a translucent material before it.
    @ViewBuilder
    func shieldGlass(in shape: some Shape) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.15)))
        }
    }

    func shake(on trigger: Int) -> some View {
        modifier(Shake(trigger: trigger))
    }
}

/// Shakes sideways, like the macOS password field, whenever `trigger`
/// changes: here, on every wrong finger.
private struct Shake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                for offset in [-12.0, 10, -8, 6, -3, 0] {
                    LinearKeyframe(offset, duration: 0.06)
                }
            }
        }
    }
}

private struct UnlockHint: View {
    let phase: LockPhase
    let touchIDView: NSView?

    var body: some View {
        switch phase {
        case .locked:
            Label("Press any key to unlock", systemImage: "keyboard")
        case .authenticating:
            if let touchIDView {
                Label {
                    Text("Touch ID to Unlock")
                } icon: {
                    TouchIDGlyph(view: touchIDView)
                        .id(ObjectIdentifier(touchIDView))
                        .frame(width: 32, height: 32)
                }
            } else {
                // Touch ID is not usable: the system password prompt is up.
                Label("Enter your password to unlock", systemImage: "lock")
            }
        case .coolingDown(_, let until):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
                Label("Too many attempts. Try again in \(seconds) s", systemImage: "hourglass")
            }
        case .unlocked, .escalated:
            EmptyView()
        }
    }
}

/// The `LAAuthenticationView` paired with the context being evaluated.
/// macOS reads the sensor only while it is actually visible (it watches its
/// own occlusion), so it must never be hidden or covered.
private struct TouchIDGlyph: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
