import KAPLCore
import SwiftUI

struct ShieldContentView: View {
    let model: ShieldViewModel

    var body: some View {
        // Monitor and Transparent modes are not built yet. Until they are,
        // every mode falls back to Privacy: never show less than intended.
        PrivacyLockView(phase: model.phase)
            .environment(\.colorScheme, .dark)
    }
}

struct PrivacyLockView: View {
    let phase: LockPhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 64))
                    .padding(.bottom, 8)

                Text("Mac is protected")
                    .font(.system(size: 32, weight: .semibold))

                Text("Background tasks keep running")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if let lockedAt = phase.session?.lockedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Locked for \(Self.elapsed(from: lockedAt, to: context.date))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                UnlockHint(phase: phase)
                    .padding(.top, 24)
            }
            .foregroundStyle(.white)
        }
    }

    private static func elapsed(from start: Date, to now: Date) -> String {
        Duration.seconds(max(0, now.timeIntervalSince(start)))
            .formatted(.time(pattern: .hourMinuteSecond))
    }
}

private struct UnlockHint: View {
    let phase: LockPhase

    var body: some View {
        switch phase {
        case .locked:
            Label("Touch ID or press any key to unlock", systemImage: "touchid")
        case .authenticating:
            Label("Waiting for Touch ID or password…", systemImage: "touchid")
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
