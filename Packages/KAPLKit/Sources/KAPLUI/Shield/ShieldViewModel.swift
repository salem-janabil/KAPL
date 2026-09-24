import AppKit
import KAPLCore
import Observation

/// What the SwiftUI shield content observes. Owned by `ShieldController`,
/// shared by the windows on every screen.
@MainActor
@Observable
final class ShieldViewModel {
    var phase: LockPhase = .unlocked
    /// The Touch ID glyph paired with the context being evaluated, while
    /// Touch ID runs inside the shield. Nil while the system password prompt
    /// is used instead.
    var touchIDView: NSView?
}
