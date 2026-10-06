import SwiftUI

/// Lays felt patches out like a quilt: rows of equal height whose patches share the row's
/// width in proportion to their weight (a long book is a wider patch), so every full row
/// ends flush with the shelf. A short last row keeps natural widths instead of stretching.
///
/// VoiceOver and keyboard order follow the data order, row by row, left to right.
struct QuiltLayout: Layout {
    var rowHeight: CGFloat
    var spacing: CGFloat = 12
    /// The width a weight-1 patch would like to be. Rows break when the next patch would
    /// squeeze below its ideal width.
    var idealUnitWidth: CGFloat = 200

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealUnitWidth * 4
        let count = rows(for: width, subviews: subviews).count
        return CGSize(width: width, height: CGFloat(count) * rowHeight + CGFloat(max(count - 1, 0)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: bounds.width, subviews: subviews) {
            let weights = row.map { subviews[$0][QuiltWeight.self] }
            let gaps = spacing * CGFloat(row.count - 1)
            let natural = weights.reduce(0) { $0 + $1 * idealUnitWidth }
            // Justify full rows; let a sparse last row keep its natural widths.
            let available = bounds.width - gaps
            let stretch = natural + gaps >= bounds.width * 0.72 ? available / natural : min(1, available / natural)
            var x = bounds.minX
            for (offset, index) in row.enumerated() {
                let width = weights[offset] * idealUnitWidth * stretch
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: width, height: rowHeight))
                x += width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func rows(for width: CGFloat, subviews: Subviews) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var used: CGFloat = 0
        for index in subviews.indices {
            let ideal = subviews[index][QuiltWeight.self] * idealUnitWidth
            let next = used + (current.isEmpty ? 0 : spacing) + ideal
            if !current.isEmpty && next > width {
                rows.append(current)
                current = [index]
                used = ideal
            } else {
                current.append(index)
                used = next
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}

/// How wide a patch wants to be, relative to a standard book.
struct QuiltWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func quiltWeight(_ weight: CGFloat) -> some View {
        layoutValue(key: QuiltWeight.self, value: weight)
    }
}
