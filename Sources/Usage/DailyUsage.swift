import Foundation

/// How much of a window was used since local midnight, worked out from the
/// readings `UsageHistoryStore` records on every successful refresh.
enum DailyUsage {
    /// A reading this far below the previous one is a window reset, not noise.
    static let resetDrop = 0.02
    /// Only a reading from shortly before midnight counts as the day's start;
    /// an older one (app closed overnight) would pin yesterday's usage on today.
    static let baselineMaxAge: TimeInterval = 12 * 3600

    /// Fraction (0...1+) of the window used today, or nil with no reading today.
    /// Rises are summed; a reset during the day counts the new reading from zero.
    static func usedToday(_ readings: [(at: Date, used: Double)], now: Date = Date(),
                          calendar: Calendar = .current) -> Double? {
        let start = calendar.startOfDay(for: now)
        let today = readings.filter { $0.at >= start && $0.at <= now }
        guard let first = today.first else { return nil }
        var previous = readings.last(where: { $0.at < start && start.timeIntervalSince($0.at) <= baselineMaxAge })?.used
            ?? first.used
        var total = 0.0
        for reading in today {
            if reading.used >= previous {
                total += reading.used - previous
            } else if previous - reading.used > resetDrop {
                total += reading.used
            }
            previous = reading.used
        }
        return total
    }
}
