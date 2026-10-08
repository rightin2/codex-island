import Foundation
import CoreGraphics

@main
struct WorkingChatsTests {
    static var failures = 0
    static func expect(_ c: Bool, _ label: String) { if c { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 } }

    static func json(_ s: String) -> Data { Data(s.utf8) }

    static func main() {
        // Session registry parsing
        let busy = json(#"{"pid":"101","kind":"interactive","status":"busy","name":"CODEX ISLAND","startedAt":"5"}"#)
        let idle = json(#"{"pid":"102","kind":"interactive","status":"idle","name":"MODELS","startedAt":"6"}"#)
        let unnamed = json(#"{"pid":"103","kind":"interactive","status":"busy","startedAt":"7"}"#)
        let alive: (Int32) -> Bool = { _ in true }
        let notHeadless: (Int32) -> Bool = { _ in false }
        expect(WorkingChatsStore.parse(busy, isAlive: alive, isHeadless: notHeadless)?.name == "CODEX ISLAND", "busy chat is listed by name")
        expect(WorkingChatsStore.parse(idle, isAlive: alive, isHeadless: notHeadless) == nil, "idle chat is not listed")
        expect(WorkingChatsStore.parse(busy, isAlive: { _ in false }, isHeadless: notHeadless) == nil, "dead process is not listed")
        expect(WorkingChatsStore.parse(busy, isAlive: alive, isHeadless: { _ in true }) == nil, "claude -p script run is not listed")
        expect(WorkingChatsStore.parse(unnamed, isAlive: alive, isHeadless: notHeadless)?.name == "Claude", "unnamed chat falls back to Claude")
        expect(WorkingChatsStore.isHeadless(getpid()) == false, "this test process is not headless")

        // Layout: 7pt per character, dot 13, gap 14
        let m: (String) -> CGFloat = { CGFloat($0.count) * 7 }
        let names = ["AUDIOBOOKS", "CODEX ISLAND", "Course submission requirements"]
        let wide = WorkingChatsLayout.fit(names: names, available: 2000, measure: m)
        expect(wide.items.count == 3 && wide.overflow == 0, "plenty of room: all three")
        expect(wide.items[2].maxWidth == 170, "very long name capped at 170")
        let squeezed = WorkingChatsLayout.fit(names: names, available: 300, measure: m)
        expect(squeezed.items.count == 3 && squeezed.width <= 300, "less room: names shortened, all still shown")
        let tight = WorkingChatsLayout.fit(names: names, available: 120, measure: m)
        expect(tight.overflow > 0 && tight.width <= 120, "tight: some chats plus a +N count")
        let tiny = WorkingChatsLayout.fit(names: names, available: 22, measure: m)
        expect(tiny.items.isEmpty && tiny.overflow == 3, "very tight: just +3")
        expect(WorkingChatsLayout.fit(names: names, available: 5, measure: m) == .empty, "no room: nothing")
        expect(WorkingChatsLayout.fit(names: [], available: 500, measure: m) == .empty, "no chats: nothing")

        if failures > 0 { print("\(failures) failure(s)"); exit(1) }
        print("all working chats tests passed")
    }
}
