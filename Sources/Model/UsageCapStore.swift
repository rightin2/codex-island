import Foundation

/// User-chosen Claude usage caps. When a cap is reached, `UsageCapEngine`
/// asks every Claude Code session to wrap up, and once usage passes the cap
/// plus `tolerancePercent` it pauses all Claude work until the window resets.
///
/// Default `enabled = false`: pausing work is opt-in via Settings.
@MainActor
final class UsageCapStore: ObservableObject {
    static let shared = UsageCapStore()

    private static let enabledKey = "CodexIsland.usageCapEnabled"
    private static let fiveHourKey = "CodexIsland.usageCapFiveHour"
    private static let weeklyKey = "CodexIsland.usageCapWeekly"
    private static let toleranceKey = "CodexIsland.usageCapTolerance"

    static let capRange: ClosedRange<Int> = 10...100
    static let toleranceRange: ClosedRange<Int> = 0...10

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }

    @Published var fiveHourCap: Int {
        didSet { UserDefaults.standard.set(fiveHourCap, forKey: Self.fiveHourKey) }
    }

    @Published var weeklyCap: Int {
        didSet { UserDefaults.standard.set(weeklyCap, forKey: Self.weeklyKey) }
    }

    @Published var tolerancePercent: Int {
        didSet { UserDefaults.standard.set(tolerancePercent, forKey: Self.toleranceKey) }
    }

    private init() {
        self.enabled = Pref.seededBool(key: Self.enabledKey, default: false)
        self.fiveHourCap = Pref.int(key: Self.fiveHourKey, default: 90, range: Self.capRange)
        self.weeklyCap = Pref.int(key: Self.weeklyKey, default: 95, range: Self.capRange)
        self.tolerancePercent = Pref.int(key: Self.toleranceKey, default: 2, range: Self.toleranceRange)
    }
}
