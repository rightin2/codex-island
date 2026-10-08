import SwiftUI
import AppKit

/// Working Claude chats, shown in a black strip that grows out of the
/// island's left edge. It only ever grows left (the right side of the menu
/// bar holds status icons) and never over the frontmost app's menus.
struct WorkingChatsStrip: View {
    let islandWidth: CGFloat
    let height: CGFloat
    let screenWidth: CGFloat

    @ObservedObject private var store = WorkingChatsStore.shared
    @ObservedObject private var menuBar = MenuBarClearance.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Strip padding: before the first chat, and the part hidden under the island.
    static let leadingPad: CGFloat = 12
    static let joinPad: CGFloat = 10
    static let overlap: CGFloat = 24
    /// Keep this much clear after the last app menu.
    static let menuMargin: CGFloat = 14
    /// Without Accessibility permission the menus' extent is unknown, so
    /// stay within this much and let the layout fall back to a count.
    static let blindBudget: CGFloat = 150

    private static let font = NSFont.menuBarFont(ofSize: 0)

    private var layout: WorkingChatsLayout {
        let islandLeft = screenWidth / 2 - islandWidth / 2
        let room: CGFloat
        if let end = menuBar.menusEndX {
            room = islandLeft - end - Self.menuMargin
        } else {
            room = min(Self.blindBudget, islandLeft - 120)
        }
        let available = room - Self.leadingPad - Self.joinPad
        return WorkingChatsLayout.fit(names: store.chats.map(\.name), available: available) { text in
            ceil((text as NSString).size(withAttributes: [.font: Self.font]).width)
        }
    }

    var body: some View {
        let layout = layout
        let visible = layout.width > 0
        HStack(spacing: 14) {
            ForEach(Array(layout.items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 5) {
                    WorkingDot()
                    Text(item.name)
                        .font(NotchPeekPill.menuBarFont)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: item.maxWidth, alignment: .leading)
                }
            }
            if layout.overflow > 0 {
                Text("+\(layout.overflow)")
                    .font(NotchPeekPill.menuBarFont)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .fixedSize()
        .padding(.leading, Self.leadingPad)
        .padding(.trailing, Self.joinPad + Self.overlap)
        .frame(height: height)
        .background(IslandShape().fill(.black))
        .offset(x: -(layout.width + Self.leadingPad + Self.joinPad))
        .opacity(visible ? 1 : 0)
        .animation(reduceMotion ? nil : .openMorph, value: layout)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.chats.isEmpty ? "" : "Working chats: " + store.chats.map(\.name).joined(separator: ", "))
        .accessibilityHidden(!visible)
    }
}

/// Small pulsing Claude-coloured dot: this chat is working.
private struct WorkingDot: View {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(IslandProvider.claude.color)
            .frame(width: 8, height: 8)
            .opacity(on ? 1 : 0.45)
            .onAppear {
                guard !reduceMotion else { on = true; return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
