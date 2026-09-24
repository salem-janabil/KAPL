import KAPLCore
import Observation

/// What the SwiftUI shield content observes. Owned by `ShieldController`,
/// shared by the windows on every screen.
@MainActor
@Observable
final class ShieldViewModel {
    var phase: LockPhase = .unlocked
}
