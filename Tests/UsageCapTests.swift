import Foundation

@main
struct UsageCapTests {
    static var failures = 0
    static func expect(_ c: Bool, _ label: String) { if c { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 } }

    static func w(_ pct: Double, reset: Date? = Date().addingTimeInterval(3600)) -> WindowUsage {
        WindowUsage(usedPercent: pct, resetAt: reset, error: nil)
    }

    static func main() {
        func eval(_ five: WindowUsage, _ week: WindowUsage, five5: Int = 90, weekCap: Int = 95, tol: Int = 2) -> UsageCapStatus {
            UsageCapDecision.evaluate(fiveHour: five, weekly: week, fiveHourCap: five5, weeklyCap: weekCap, tolerance: tol)
        }
        expect(eval(w(0.50), w(0.50)).level == .none, "below both caps: nothing")
        expect(eval(w(0.90), w(0.50)).level == .soft, "5h at cap: wrap up")
        expect(eval(w(0.91), w(0.50)).hardAt == 92, "hard stop is cap + tolerance")
        expect(eval(w(0.92), w(0.50)).level == .hard, "5h at cap + tolerance: pause")
        expect(eval(w(0.50), w(0.96)).window == "weekly", "weekly cap trips on its own")
        expect(eval(w(0.90), w(0.97)).level == .hard && eval(w(0.90), w(0.97)).window == "weekly", "hard beats soft across windows")
        expect(eval(w(0.99), w(0.50), five5: 99, tol: 5).hardAt == 100, "hard stop never above 100%")
        expect(eval(w(0.95), w(0.50), tol: 0).level == .hard, "zero tolerance pauses at the cap")
        expect(eval(w(0.95, reset: Date().addingTimeInterval(-60)), w(0.50)).level == .none, "reading from before the reset is ignored")
        expect(eval(WindowUsage.unknown, w(0.50)).level == .none, "no reading: nothing")

        let soft = eval(w(0.90), w(0.50)).message(resetText: "at 3:40 PM")
        let hard = eval(w(0.93), w(0.50)).message(resetText: "at 3:40 PM")
        expect(soft.contains("Finish only the step you are on"), "soft message asks to wrap up")
        expect(hard.contains("paused until the window resets at 3:40 PM"), "hard message says when it resumes")
        expect(!(soft + hard).contains("\"") && !(soft + hard).contains("\\"), "messages are JSON safe")

        let desktop = "/Users/x/Library/Application Support/Claude/claude-code/2.1.295/claude.app/Contents/MacOS/claude"
        expect(UsageCapDecision.isBackgroundClaude(["claude", "-p", "--model", "x"]), "claude -p is a background run")
        expect(UsageCapDecision.isBackgroundClaude(["node", "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js", "--print"]), "node claude-code --print is a background run")
        expect(!UsageCapDecision.isBackgroundClaude([desktop, "--output-format", "stream-json"]), "desktop chat is not")
        expect(!UsageCapDecision.isBackgroundClaude(["claude"]), "terminal chat is not")
        expect(!UsageCapDecision.isBackgroundClaude(["python3", "-p", "claude"]), "other programs are not")

        print(failures == 0 ? "All usage cap tests passed" : "\(failures) usage cap tests FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
