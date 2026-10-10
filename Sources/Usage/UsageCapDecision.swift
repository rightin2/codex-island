import Foundation

/// Where Claude stands against the user's usage caps.
struct UsageCapStatus: Equatable {
    enum Level: String { case none, soft, hard }

    let level: Level
    var window = ""          // "5h" or "weekly"
    var percent = 0
    var cap = 0
    var hardAt = 0
    var resetAt: Date?

    static let clear = UsageCapStatus(level: .none)

    /// The text Claude Code sessions are shown. Kept free of quotes and
    /// backslashes so the hook can drop it straight into JSON.
    func message(resetText: String) -> String {
        let text: String
        switch level {
        case .none:
            text = ""
        case .soft:
            text = "Usage cap reached: Claude \(window) usage is \(percent)% (cap \(cap)%, everything pauses at \(hardAt)%). "
                + "Finish only the step you are on, save your work, then stop and tell the user you paused for the usage cap. Do not start anything new."
        case .hard:
            text = "Usage cap: Claude \(window) usage is \(percent)% (cap \(cap)% plus tolerance). All Claude work is paused"
                + (resetText.isEmpty ? "" : " until the window resets \(resetText)")
                + ". To continue sooner, raise or turn off the cap in CodexIsland settings."
        }
        return text.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

/// The cap judgment, kept pure so it can be tested with plain values.
enum UsageCapDecision {
    static func evaluate(fiveHour: WindowUsage, weekly: WindowUsage, fiveHourCap: Int, weeklyCap: Int,
                         tolerance: Int, now: Date = Date()) -> UsageCapStatus {
        let candidates = [("5h", fiveHour, fiveHourCap), ("weekly", weekly, weeklyCap)].map { name, window, cap in
            status(name: name, window: window, cap: cap, tolerance: tolerance, now: now)
        }
        // Hard beats soft; on a tie the 5h window (listed first) wins.
        return candidates.first { $0.level == .hard } ?? candidates.first { $0.level == .soft } ?? .clear
    }

    private static func status(name: String, window: WindowUsage, cap: Int, tolerance: Int, now: Date) -> UsageCapStatus {
        guard window.hasPercentageReading else { return .clear }
        // A reading from before the window reset no longer counts.
        if let reset = window.resetAt, reset <= now { return .clear }
        let pct = window.percentInt
        let hardAt = min(cap + tolerance, 100)
        let level: UsageCapStatus.Level = pct >= hardAt ? .hard : (pct >= cap ? .soft : .none)
        guard level != .none else { return .clear }
        return UsageCapStatus(level: level, window: name, percent: pct, cap: cap, hardAt: hardAt, resetAt: window.resetAt)
    }

    /// True for a Claude Code process started with `-p` / `--print`.
    nonisolated static func isBackgroundClaude(_ args: [String]) -> Bool {
        guard let first = args.first else { return false }
        let isClaude = (first as NSString).lastPathComponent == "claude"
            || args.prefix(2).contains { $0.contains("claude-code") }
        return isClaude && (args.contains("-p") || args.contains("--print"))
    }
}
