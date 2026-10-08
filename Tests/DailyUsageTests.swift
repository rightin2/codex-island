import Foundation

@main
struct DailyUsageTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if condition { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 }
    }

    static func near(_ a: Double?, _ b: Double) -> Bool { a.map { abs($0 - b) < 0.0001 } ?? false }

    static func main() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        let midnight = cal.date(from: DateComponents(year: 2026, month: 10, day: 8))!
        func at(_ hours: Double) -> Date { midnight.addingTimeInterval(hours * 3600) }
        let now = at(15)

        let steady: [(at: Date, used: Double)] = [(at(-1), 0.40), (at(9), 0.42), (at(12), 0.47), (at(14), 0.49)]
        expect(near(DailyUsage.usedToday(steady, now: now, calendar: cal), 0.09),
               "counts from the last reading before midnight")

        let reset: [(at: Date, used: Double)] = [(at(-1), 0.90), (at(8), 0.95), (at(10), 0.03), (at(14), 0.06)]
        expect(near(DailyUsage.usedToday(reset, now: now, calendar: cal), 0.11),
               "weekly reset mid-day: 5% before + 6% after")

        let noise: [(at: Date, used: Double)] = [(at(-1), 0.50), (at(9), 0.495), (at(12), 0.52)]
        expect(near(DailyUsage.usedToday(noise, now: now, calendar: cal), 0.025),
               "a tiny dip is rounding noise, not a reset")

        let stale: [(at: Date, used: Double)] = [(at(-30), 0.20), (at(9), 0.35), (at(12), 0.38)]
        expect(near(DailyUsage.usedToday(stale, now: now, calendar: cal), 0.03),
               "a baseline older than 12h is ignored; the day starts at its first reading")

        let yesterdayOnly: [(at: Date, used: Double)] = [(at(-3), 0.20)]
        expect(DailyUsage.usedToday(yesterdayOnly, now: now, calendar: cal) == nil, "no reading today gives nil")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all daily usage tests passed")
    }
}
