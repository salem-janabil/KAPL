import IOKit.pwr_mgt
import KAPLCore
import os

/// Keeps the Mac awake with IOKit power assertions (what `caffeinate` uses).
/// Assertions die with the process, so a crash can never leave the Mac
/// permanently awake.
@MainActor
public final class PowerAssertionSleepPreventer: SleepPreventing {
    public enum Scope: Sendable {
        case system
        case systemAndDisplay
    }

    private let scope: Scope
    private var assertions: [IOPMAssertionID] = []

    private static let log = Logger(subsystem: "io.github.salemjanabil.KAPL", category: "power")

    public init(scope: Scope) {
        self.scope = scope
    }

    public func begin(reason: String) {
        guard assertions.isEmpty else { return }

        var types = ["PreventUserIdleSystemSleep"]
        if scope == .systemAndDisplay {
            types.append("PreventUserIdleDisplaySleep")
        }

        for type in types {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                assertions.append(id)
            } else {
                Self.log.error("failed to create \(type, privacy: .public) assertion: \(result)")
            }
        }
    }

    public func end() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions.removeAll()
    }
}
