import Foundation

/// The stacked peek pill shows the weekly window under the 5-hour one.
/// It must only do so when the pill's main row really is the 5-hour window
/// and the plan reports a weekly window.
@main
struct PeekSecondaryWindowTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if condition { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 }
    }

    static func reading(_ p: Double) -> WindowUsage { WindowUsage(usedPercent: p, resetAt: nil, error: nil) }

    static func main() {
        let both = AppUsage(fiveHour: reading(0.32), weekly: reading(0.61), reportedWindows: [.fiveHour, .weekly])
        expect(both.peekWindowKind == .fiveHour, "two-window plan: main row is 5h")
        expect(both.peekSecondaryWindow?.usedPercent == 0.61, "two-window plan: second row is the weekly reading")

        let weeklyOnly = AppUsage(fiveHour: .unknown, weekly: reading(0.40), reportedWindows: [.weekly])
        expect(weeklyOnly.peekWindowKind == .weekly, "weekly-only plan: main row is weekly")
        expect(weeklyOnly.peekSecondaryWindow == nil, "weekly-only plan: no second row")

        let fiveOnly = AppUsage(fiveHour: reading(0.10), weekly: .unknown, reportedWindows: [.fiveHour])
        expect(fiveOnly.peekSecondaryWindow == nil, "5h-only plan: no second row")

        let weeklyFailed = AppUsage(fiveHour: reading(0.20),
                                    weekly: WindowUsage(usedPercent: 0, resetAt: nil, error: "rate limited"),
                                    reportedWindows: [.fiveHour, .weekly])
        expect(weeklyFailed.peekSecondaryWindow.map { !$0.hasReading } == true,
               "weekly fetch failed: second row still present (shows -%)")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all peek secondary window tests passed")
    }
}
