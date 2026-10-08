import Foundation
import Combine
import Darwin

/// One Claude chat that is working right now.
struct WorkingChat: Equatable, Identifiable {
    let pid: Int32
    let name: String
    let startedAt: Double
    var id: Int32 { pid }
}

/// Reads Claude Code's own session registry (`~/.claude/sessions/<pid>.json`,
/// one file per running Claude process) and keeps the chats whose status is
/// `busy`. Headless `claude -p` runs started by scripts register there too;
/// they are not chats, so they are left out.
@MainActor
final class WorkingChatsStore: ObservableObject {
    static let shared = WorkingChatsStore()

    @Published private(set) var chats: [WorkingChat] = []

    private let directory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/sessions")
    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let found = files.filter { $0.pathExtension == "json" }.compactMap { url -> WorkingChat? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return Self.parse(data, isAlive: Self.isAlive, isHeadless: Self.isHeadless)
        }.sorted { $0.startedAt < $1.startedAt }
        if found != chats { chats = found }
    }

    /// A busy interactive chat, or nil. Pure, so it can be tested with fakes.
    nonisolated static func parse(_ data: Data, isAlive: (Int32) -> Bool, isHeadless: (Int32) -> Bool) -> WorkingChat? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pid = Int32(String(describing: json["pid"] ?? "")),
              (json["status"] as? String) == "busy",
              (json["kind"] as? String ?? "interactive") == "interactive",
              isAlive(pid), !isHeadless(pid)
        else { return nil }
        let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let started = Double(String(describing: json["startedAt"] ?? "")) ?? 0
        return WorkingChat(pid: pid, name: (name?.isEmpty == false ? name! : "Claude"), startedAt: started)
    }

    nonisolated static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// True for `claude -p` / `--print` runs (scripts and pipelines).
    nonisolated static func isHeadless(_ pid: Int32) -> Bool {
        let args = arguments(of: pid)
        return args.contains("-p") || args.contains("--print")
    }

    /// The process's argv, read with sysctl(KERN_PROCARGS2).
    nonisolated static func arguments(of pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }      // executable path
        while index < size, buffer[index] == 0 { index += 1 }      // padding
        var args: [String] = []
        var start = index
        while index < size, args.count < Int(argc) {
            if buffer[index] == 0 {
                args.append(String(decoding: buffer[start..<index], as: UTF8.self))
                start = index + 1
            }
            index += 1
        }
        return args
    }
}
