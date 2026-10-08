import CoreGraphics

/// Decides how many working chats fit beside the island, and how wide each
/// name may be. Pure, so it is tested without AppKit.
///
/// Order of give: full names first; then names truncated (down to `minName`);
/// then the first few chats plus a "+N" count; then just the count; then nothing.
struct WorkingChatsLayout: Equatable {
    struct Item: Equatable { let name: String; let maxWidth: CGFloat }
    var items: [Item]
    var overflow: Int
    var width: CGFloat

    static let empty = WorkingChatsLayout(items: [], overflow: 0, width: 0)

    static func fit(names: [String], available: CGFloat, measure: (String) -> CGFloat,
                    dot: CGFloat = 13, gap: CGFloat = 14, minName: CGFloat = 56, maxName: CGFloat = 170) -> WorkingChatsLayout {
        guard !names.isEmpty, available > 0 else { return .empty }
        func total(_ widths: [CGFloat], overflow: Int) -> CGFloat {
            var w = widths.reduce(0) { $0 + dot + $1 } + gap * CGFloat(max(0, widths.count - 1))
            if overflow > 0 { w += (widths.isEmpty ? 0 : gap) + measure("+\(overflow)") }
            return w
        }
        let natural = names.map { min(measure($0), maxName) }
        // 1. Everything at natural width, then 2. squeeze names evenly.
        var cap = maxName
        while cap >= minName {
            let widths = natural.map { min($0, cap) }
            let w = total(widths, overflow: 0)
            if w <= available {
                return WorkingChatsLayout(items: zip(names, widths).map { Item(name: $0, maxWidth: $1) }, overflow: 0, width: w)
            }
            cap -= 8
        }
        // 3. The first k chats at the minimum width plus a count.
        for k in stride(from: names.count - 1, through: 0, by: -1) {
            let widths = natural.prefix(k).map { min($0, minName) }
            let w = total(Array(widths), overflow: names.count - k)
            if w <= available {
                return WorkingChatsLayout(items: zip(names.prefix(k), widths).map { Item(name: $0, maxWidth: $1) },
                                          overflow: names.count - k, width: w)
            }
        }
        return .empty
    }
}
