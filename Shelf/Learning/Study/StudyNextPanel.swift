import SwiftUI

/// "Or spend these minutes another way": every way as a small card. The chosen one is a
/// cream patch with a red running stitch under its name.
struct StudyWaysStrip: View {
    @Binding var way: StudyWay
    let ways: [StudyWay]
    let minutes: Int
    var wide: Bool

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .top, spacing: 10) { cards }
            } else {
                ScrollView(.horizontal) { HStack(alignment: .top, spacing: 10) { cards }.padding(.vertical, 6) }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 2, for: .scrollContent)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ways to study")
    }

    private var cards: some View {
        ForEach(ways) { option in
            let selected = option == way
            Button { way = option } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(option.phrase)
                        .font(.leu(.headline, weight: .bold))
                        .foregroundStyle(LeuDesign.ink)
                        .padding(.bottom, 3)
                        .overlay(alignment: .bottomLeading) {
                            if selected { StitchUnderline().stroke(LeuDesign.redThread, lineWidth: 1.6).frame(height: 5).offset(y: 4) }
                        }
                    Text(option.usesMinutes ? "\(option.detail) · \(minutes) min" : option.detail)
                        .font(.leu(.footnote))
                        .foregroundStyle(LeuDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(width: wide ? nil : 220, alignment: .topLeading)
                .frame(maxWidth: wide ? .infinity : nil, minHeight: 112, alignment: .topLeading)
                .background(selected ? LeuDesign.cream : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: selected ? LeuDesign.ink.opacity(0.12) : .clear, radius: 10, x: 0, y: 6)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(FeltPressStyle())
            .accessibilityLabel(option.phrase)
            .accessibilityHint(option.detail)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("study-way-\(option.rawValue)")
            .animation(.easeInOut(duration: 0.35), value: selected)
        }
    }
}

/// "What happens next": three plain steps, the start button, and the promise that nothing
/// is scored. For "explain it my way" the snow globe sits beside the steps, all windows dark.
struct StudyNextPanel: View {
    let way: StudyWay
    let steps: [String]
    let startTitle: String
    let ready: Bool
    let reason: String?
    var wide: Bool
    var globe: Bool
    let start: () -> Void

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .center, spacing: 36) {
                    if globe { SnowGlobe(lit: 0).frame(width: 300).transition(.opacity) }
                    stepList.frame(maxWidth: .infinity, alignment: .leading)
                    startColumn(alignment: .center).frame(width: 260)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if globe { SnowGlobe(lit: 0).frame(maxWidth: 300).frame(maxWidth: .infinity).transition(.opacity) }
                    stepList
                    startColumn(alignment: .leading)
                }
            }
        }
        .padding(wide ? 30 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.studyLabsSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.easeInOut(duration: 0.6), value: globe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study-next")
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT HAPPENS NEXT")
                .font(LeuDesign.eyebrow(11))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.leu(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(LeuDesign.ink)
                        .frame(width: 30, height: 30)
                        .overlay { Circle().strokeBorder(LeuDesign.ink, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])) }
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                        .accessibilityHidden(true)
                    Text(step)
                        .font(.leu(.body, weight: .semibold))
                        .foregroundStyle(LeuDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Step \(index + 1): \(step)")
                }
            }
        }
    }

    private func startColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Button(startTitle, action: start)
                .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                .disabled(!ready)
                .accessibilityIdentifier("study-start")
            Text(reason ?? "Nothing is scored. You can stop any time.")
                .font(.leu(.footnote))
                .foregroundStyle(LeuDesign.secondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
