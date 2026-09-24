import Foundation
import Observation
import os

/// Runs the lock state machine: feeds it events, renders the resulting phase
/// on the shield and performs the effects it asks for.
@MainActor
@Observable
public final class LockCoordinator {
    public private(set) var phase: LockPhase = .unlocked

    public var isLocked: Bool { phase != .unlocked }

    @ObservationIgnored private let policy: LockPolicy
    @ObservationIgnored private let authenticator: any Authenticating
    @ObservationIgnored private let sleepPreventer: any SleepPreventing
    @ObservationIgnored private let systemLock: any SystemLocking
    @ObservationIgnored private let shield: any ShieldPresenting
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?

    private static let log = Logger(subsystem: "io.github.salemjanabil.KAPL", category: "lock")

    public init(
        policy: LockPolicy = .default,
        authenticator: any Authenticating,
        sleepPreventer: any SleepPreventing,
        systemLock: any SystemLocking,
        shield: any ShieldPresenting,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.policy = policy
        self.authenticator = authenticator
        self.sleepPreventer = sleepPreventer
        self.systemLock = systemLock
        self.shield = shield
        self.now = now
    }

    public func lock(mode: LockMode = .privacy) {
        send(.lockRequested(mode, at: now()))
    }

    public func requestUnlock() {
        send(.unlockRequested)
    }

    public func reportBreach(_ reason: BreachReason) {
        send(.breachDetected(reason))
    }

    public func systemSessionDidUnlock() {
        send(.systemSessionUnlocked)
    }

    private func send(_ event: LockEvent) {
        let previous = phase
        let effects = LockReducer.reduce(&phase, event, policy: policy)
        if phase != previous {
            Self.log.info("phase \(String(describing: previous), privacy: .public) -> \(String(describing: self.phase), privacy: .public)")
            shield.render(phase)
        }
        effects.forEach(perform)
    }

    private func perform(_ effect: LockEffect) {
        switch effect {
        case .preventSleep:
            sleepPreventer.begin(reason: "Keep-Alive Privacy Lock is protecting this session")

        case .allowSleep:
            cooldownTask?.cancel()
            sleepPreventer.end()

        case .authenticate:
            Task { [weak self, authenticator] in
                let result = await authenticator.authenticate(reason: "unlock this session")
                guard let self else { return }
                self.send(.authenticationFinished(result, at: self.now()))
            }

        case .scheduleCooldownEnd(let until):
            cooldownTask?.cancel()
            let delay = max(0, until.timeIntervalSince(now()))
            cooldownTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.send(.cooldownElapsed(at: until))
            }

        case .escalate(let reason):
            Self.log.notice("escalating to system lock: \(String(describing: reason), privacy: .public)")
            if systemLock.lockNow() {
                send(.systemLockEngaged)
            } else {
                Self.log.error("system lock failed; keeping the shield up")
                send(.systemLockFailed)
            }
        }
    }
}
