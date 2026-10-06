import ShelfCore
import SwiftUI

/// Leu's answer after comparing the reader's words with the page: how many windows are
/// lit, the first loose end in the source's own words, and the full comparison below it.
/// Nothing here is a score, and nothing claims more than the source establishes.
struct TeachLeuReply: View {
    let result: TeachLeuResult
    let windows: Int
    /// Where the speech tail points: at the globe beside it, or up at the globe above it.
    var tailLeading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(TeachGlobeProgress.heading(windows: windows).uppercased())
                .font(LeuDesign.eyebrow(11))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnPaper)
                .accessibilityAddTraits(.isHeader)
            lead
                .font(.leu(.body, weight: .semibold))
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            details
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: LeuDesign.radius, style: .continuous))
        .overlay(alignment: tailLeading ? .topLeading : .top) {
            SpeechTail()
                .fill(LeuDesign.cream)
                .frame(width: 18, height: 14)
                .rotationEffect(tailLeading ? .degrees(-90) : .zero)
                .offset(x: tailLeading ? -15 : 0, y: tailLeading ? 34 : -13)
                .accessibilityHidden(true)
        }
        .shadow(color: LeuDesign.ink.opacity(0.10), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("teach-leu-result")
    }

    private var lead: Text {
        let loose = result.omitted.first?.evidence.text
        if result.supported.isEmpty {
            if let loose {
                return Text("Not across yet. Try starting from this part of the page: \(Text(loose).foregroundStyle(LeuDesign.redThreadText))")
            }
            return Text("Nothing from the page came across yet. Say what happens, and why.")
        }
        if let loose {
            return Text("That made sense. One thing is still loose: \(Text(loose).foregroundStyle(LeuDesign.redThreadText))")
        }
        return result.challenged.isEmpty
            ? Text("Every idea on the page came across.")
            : Text("Every idea came across. One part of what you said is worth a second look.")
    }

    @ViewBuilder private var details: some View {
        if !result.supported.isEmpty {
            section("You captured") {
                ForEach(Array(result.supported.enumerated()), id: \.offset) { _, point in
                    Text(point.description).font(.leu(.subheadline))
                }
            }
        }
        if !result.omitted.isEmpty {
            section("Worth adding") {
                ForEach(result.omitted, id: \.id) { claim in
                    Text(claim.evidence.text).font(.leu(.subheadline, serif: true))
                }
            }
        }
        if !result.challenged.isEmpty {
            section("Check this") {
                ForEach(Array(result.challenged.enumerated()), id: \.offset) { _, point in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("“\(point.learnerText)”").font(.leu(.subheadline, serif: true))
                        Text(point.explanation).font(.leu(.subheadline)).foregroundStyle(LeuDesign.secondary)
                    }
                }
            }
        }
        if !result.unsettled.isEmpty {
            section("Your source doesn't settle this") {
                ForEach(Array(result.unsettled.enumerated()), id: \.offset) { _, text in
                    Text("“\(text)”").font(.leu(.subheadline, serif: true))
                }
                Text("No conclusion has been drawn about these statements.")
                    .font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(LeuDesign.eyebrow(10))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnPaper)
                .accessibilityAddTraits(.isHeader)
            content().foregroundStyle(LeuDesign.ink)
        }
        .padding(.top, 4)
    }
}

/// The little point on a speech bubble, drawn pointing up.
private struct SpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY * 0.5))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY * 0.5))
        path.closeSubpath()
        return path
    }
}
