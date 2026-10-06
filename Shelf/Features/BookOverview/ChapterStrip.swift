import SwiftUI

/// The whole book as a strip of felt pockets, one per chapter, each as wide as the chapter is
/// long and filled from the bottom as far as you understand (or have read) it. The chapter
/// you are in wears an ink outline and a "you, p. N" tag. Tap a chapter to open it.
struct ChapterStrip: View {
    let chapters: [ChapterSpan]
    var wide: Bool
    let open: (ChapterSpan) -> Void

    private let height: CGFloat = 168

    var body: some View {
        Group {
            if wide {
                GeometryReader { proxy in
                    let total = CGFloat(chapters.reduce(0) { $0 + $1.pages.count })
                    let gaps = CGFloat(max(chapters.count - 1, 0)) * 6
                    let minimum: CGFloat = 76
                    let flexible = max(proxy.size.width - gaps - minimum * CGFloat(chapters.count), 0)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(chapters) { chapter in
                            pocket(chapter).frame(width: minimum + flexible * CGFloat(chapter.pages.count) / max(total, 1))
                        }
                    }
                }
                .frame(height: height + 26)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(chapters) { chapter in
                            pocket(chapter).frame(width: min(max(CGFloat(chapter.pages.count) * 4, 92), 220))
                        }
                    }
                    .padding(.top, 2)
                }
                .scrollIndicators(.hidden)
                .frame(height: height + 26)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapters")
    }

    private func pocket(_ chapter: ChapterSpan) -> some View {
        Button { open(chapter) } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xCBD3A3))
                Rectangle()
                    .fill(chapter.understood == nil ? LeuDesign.oat : LeuDesign.butter)
                    .frame(height: height * min(max(chapter.fill, 0), 1))
                    .overlay(alignment: .top) {
                        if chapter.fill > 0.02 && chapter.fill < 0.98 {
                            Line().stroke(LeuDesign.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])).frame(height: 1.5)
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(chapter.number)").font(.leu(.caption, weight: .bold).monospacedDigit())
                    Text(chapter.title).font(.leu(.caption, weight: .bold)).lineLimit(3).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text(chapter.caption).font(.leu(.caption2, weight: .semibold)).lineLimit(2)
                }
                .foregroundStyle(LeuDesign.ink)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if chapter.isCurrent { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(LeuDesign.ink, lineWidth: 2.5) }
            }
            .overlay(alignment: .top) {
                if chapter.isCurrent {
                    Text("you are here")
                        .font(.leu(.caption2, weight: .bold)).foregroundStyle(LeuDesign.cream)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(LeuDesign.ink, in: Capsule())
                        .fixedSize()
                        .offset(y: -22)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(FeltPressStyle())
        .padding(.top, 24)
        .accessibilityLabel(spoken(chapter))
        .accessibilityHint("Opens the chapter")
        .accessibilityAddTraits(chapter.isCurrent ? .isSelected : [])
    }

    private func spoken(_ chapter: ChapterSpan) -> String {
        let base = "Chapter \(chapter.number), \(chapter.title), pages \(chapter.pages.lowerBound + 1) to \(chapter.pages.upperBound)"
        return chapter.caption.isEmpty ? base : base + ", " + chapter.caption
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
