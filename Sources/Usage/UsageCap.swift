import Foundation
import AppKit
import Combine
import Darwin

/// Applies the cap. Writes `~/.claude/usage-cap.state`, which the Claude Code
/// hook (`hooks/usage-cap-hook.sh`) reads on every tool call and prompt:
/// at the cap sessions are told to wrap up, at cap + tolerance they are
/// stopped. Background `claude -p` runs are frozen (SIGSTOP) at the hard
/// stop instead, and resumed (SIGCONT) when usage drops below the cap.
@MainActor
final class UsageCapEngine: ObservableObject {
    static let shared = UsageCapEngine()

    @Published private(set) var status: UsageCapStatus = .clear

    nonisolated static let stateFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/usage-cap.state")
    private static let frozenKey = "CodexIsland.usageCapFrozenPids"

    private var frozen: Set<Int32> = []
    private var subs: Set<AnyCancellable> = []
    private var timer: Timer?
    private var lastWrite = Date.distantPast

    private init() {}

    func start() {
        // Anything left frozen by a previous run (crash, force quit) is resumed.
        for pid in UserDefaults.standard.array(forKey: Self.frozenKey) as? [Int32] ?? [] { kill(pid, SIGCONT) }
        UserDefaults.standard.removeObject(forKey: Self.frozenKey)

        Publishers.Merge(
            UsageStore.shared.$claude.map { _ in () },
            UsageCapStore.shared.objectWillChange.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in Task { @MainActor in self?.recompute() } }
        .store(in: &subs)

        // Every 2s: catch new background runs while paused, and keep the
        // state file fresh (the hook ignores a file older than 10 minutes,
        // so a quit or crashed island never leaves sessions blocked).
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                UsageCapEngine.shared.thawAll()
                try? FileManager.default.removeItem(at: Self.stateFile)
            }
        }
        recompute()
    }

    private func recompute() {
        let prefs = UsageCapStore.shared
        let claude = UsageStore.shared.claude
        let next = prefs.enabled && !AppEnvironment.isDemo
            ? UsageCapDecision.evaluate(fiveHour: claude.fiveHour, weekly: claude.weekly,
                                        fiveHourCap: prefs.fiveHourCap, weeklyCap: prefs.weeklyCap,
                                        tolerance: prefs.tolerancePercent)
            : .clear
        let changed = next != status
        status = next
        if changed { lastWrite = .distantPast }
        tick()
    }

    private func tick() {
        // The usage reading can outlive its window; re-judge on the clock too.
        if status.level != .none, let reset = status.resetAt, reset <= Date() { recompute(); return }
        switch status.level {
        case .none:
            thawAll()
            if FileManager.default.fileExists(atPath: Self.stateFile.path) {
                try? FileManager.default.removeItem(at: Self.stateFile)
            }
        case .soft:
            thawAll()
            writeState()
        case .hard:
            freezeBackgroundRuns()
            writeState()
        }
    }

    private func writeState() {
        guard Date().timeIntervalSince(lastWrite) >= 60 else { return }
        lastWrite = Date()
        let body = "level=\(status.level.rawValue)\nmessage=\(status.message(resetText: resetText))\nupdated=\(Int(Date().timeIntervalSince1970))\n"
        try? FileManager.default.createDirectory(at: Self.stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? body.write(to: Self.stateFile, atomically: true, encoding: .utf8)
    }

    private var resetText: String {
        guard let reset = status.resetAt else { return "" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(reset) ? "'at' h:mm a" : "'on' EEE 'at' h:mm a"
        return f.string(from: reset)
    }

    private func freezeBackgroundRuns() {
        let before = frozen
        for pid in Self.backgroundClaudeRuns() where !frozen.contains(pid) {
            if kill(pid, SIGSTOP) == 0 { frozen.insert(pid) }
        }
        frozen = frozen.filter { WorkingChatsStore.isAlive($0) }
        if frozen != before { UserDefaults.standard.set(Array(frozen), forKey: Self.frozenKey) }
    }

    func thawAll() {
        guard !frozen.isEmpty else { return }
        for pid in frozen { kill(pid, SIGCONT) }
        frozen.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.frozenKey)
    }

    /// Pids of this user's running `claude -p` / `--print` processes.
    nonisolated static func backgroundClaudeRuns() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let found = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        let me = getpid()
        return pids.prefix(Int(max(found, 0))).filter { pid in
            pid > 0 && pid != me && UsageCapDecision.isBackgroundClaude(WorkingChatsStore.arguments(of: pid))
        }
    }
}
