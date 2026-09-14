import SwiftUI

/// Shared fill/foreground contract for normal, pressed and disabled primary actions.
struct LeuPrimaryButtonStyle: ButtonStyle {
    var filled = true
    var pill = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(enabled ? (filled ? LeuDesign.onSignal : LeuDesign.textPrimary) : LeuDesign.disabledForeground)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .background(fill(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: pill ? 100 : LeuDesign.smallRadius))
            .overlay {
                RoundedRectangle(cornerRadius: pill ? 100 : LeuDesign.smallRadius)
                    .stroke(filled && enabled ? Color.clear : LeuDesign.separator, lineWidth: 1)
            }
    }

    private func fill(pressed: Bool) -> Color {
        guard enabled else { return LeuDesign.disabledSurface }
        return filled ? (pressed ? LeuDesign.signalPressed : LeuDesign.signal) : (pressed ? LeuDesign.surfaceRaised : LeuDesign.surfaceSecondary)
    }
}

/// Confirmation belongs inside the item's own circle. Other positions stay neutral.
struct LeuStepIndicator: View {
    let number: Int
    let confirmed: Bool
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(LeuDesign.surfaceRaised)
            Circle().stroke(confirmed ? LeuDesign.success : LeuDesign.separator, lineWidth: 2)
            if confirmed {
                Image(systemName: "checkmark").font(.body.bold()).foregroundStyle(LeuDesign.success)
            } else {
                Text("\(number)").font(.body.monospacedDigit()).foregroundStyle(LeuDesign.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number)")
        .accessibilityValue(confirmed ? "Confirmed correct" : "Unresolved")
    }
}

private struct LeuScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func leuScaledFont(_ size: CGFloat, weight: Font.Weight = .regular,
                       design: Font.Design = .default, relativeTo: Font.TextStyle = .body) -> some View {
        modifier(LeuScaledFont(size: size, weight: weight, design: design, relativeTo: relativeTo))
    }
}
