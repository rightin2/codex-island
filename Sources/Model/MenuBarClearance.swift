import AppKit
import ApplicationServices
import Combine

/// Where the frontmost app's menus (File, Edit, View…) end, so the island
/// never grows over them. Menus differ per app, so this is re-read whenever
/// the frontmost app changes and every few seconds while something needs it.
/// Reading another app's menu bar needs Accessibility permission; without it
/// `menusEndX` stays nil and callers fall back to a cautious layout.
@MainActor
final class MenuBarClearance: ObservableObject {
    static let shared = MenuBarClearance()

    /// Right edge of the last app menu, in points from the screen's left edge.
    @Published private(set) var menusEndX: CGFloat?
    @Published private(set) var trusted = AXIsProcessTrusted()

    private static let promptedKey = "CodexIsland.menuBarClearance.prompted"
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    private init() {
        if !trusted, !UserDefaults.standard.bool(forKey: Self.promptedKey) {
            UserDefaults.standard.set(true, forKey: Self.promptedKey)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        trusted = AXIsProcessTrusted()
        guard trusted, let app = NSWorkspace.shared.frontmostApplication else {
            if menusEndX != nil { menusEndX = nil }
            return
        }
        let end = Self.menusEnd(pid: app.processIdentifier)
        if end != menusEndX { menusEndX = end }
    }

    /// Largest maxX of the app's menu bar items, relative to the left edge
    /// of the display that menu bar is on.
    private static func menusEnd(pid: pid_t) -> CGFloat? {
        let app = AXUIElementCreateApplication(pid)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success,
              let barElement = bar else { return nil }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(barElement as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return nil }
        var maxX: CGFloat?
        var originX: CGFloat = 0
        for item in items {
            guard let frame = frame(of: item), frame.width > 0 else { continue }
            if maxX == nil {
                // The first item (the Apple menu) sits at the display's left edge.
                originX = NSScreen.screens.first { $0.frame.minX <= frame.minX && frame.minX < $0.frame.maxX }?.frame.minX ?? 0
            }
            maxX = max(maxX ?? 0, frame.maxX)
        }
        return maxX.map { $0 - originX }
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success
        else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }
}
