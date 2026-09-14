import SwiftUI

/// UIKit tracking is stable across SwiftUI updates and uses an opaque, non-glass thumb.
@MainActor
struct ReaderTrackingSlider: UIViewRepresentable {
    @Binding var value: Double
    @Environment(\.isEnabled) private var enabled
    let range: ClosedRange<Double>
    var step: Double = 0
    let label: String
    let identifier: String
    var valueDescription: ((Double) -> String)? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider()
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        slider.editingChanged = { [weak coordinator = context.coordinator] editing in
            coordinator?.parent.onEditingChanged(editing)
        }
        return slider
    }
    func updateUIView(_ slider: TrackingSlider, context: Context) {
        context.coordinator.parent = self
        slider.isEnabled = enabled
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.step = Float(step)
        slider.minimumTrackTintColor = UIColor(ShelfTheme.accent)
        slider.maximumTrackTintColor = UIColor(LeuDesign.separator)
        slider.accessibilityLabel = label
        slider.accessibilityIdentifier = identifier
        slider.valueDescription = valueDescription
        if !slider.dragging { slider.setValue(Float(value), animated: false) }
        slider.accessibilityValue = slider.formattedAccessibilityValue
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TrackingSlider, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 180, height: 44)
    }

    @MainActor final class Coordinator: NSObject {
        var parent: ReaderTrackingSlider
        init(parent: ReaderTrackingSlider) { self.parent = parent }
        @objc func changed(_ slider: TrackingSlider) { parent.value = Double(slider.value) }
    }
}

@MainActor
final class TrackingSlider: UISlider {
    var editingChanged: ((Bool) -> Void)?
    var valueDescription: ((Double) -> String)?
    var step: Float = 0
    private(set) var dragging = false
    private var startX: CGFloat = 0
    private var startValue: Float = 0
    private var startedOnThumb = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isContinuous = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28))
        let thumb = renderer.image { context in
            UIColor(ShelfTheme.paper).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: 26, height: 26))
        }
        setThumbImage(thumb, for: .normal)
        setThumbImage(thumb, for: .highlighted)
        setThumbImage(thumb, for: .selected)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        dragging = true
        startX = touch.location(in: self).x
        startValue = value
        let thumb = thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
        startedOnThumb = thumb.insetBy(dx: -10, dy: -10).contains(touch.location(in: self))
        editingChanged?(true)
        update(touch)
        return true
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        update(touch)
        return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let touch { update(touch) }
        finish()
    }
    override func cancelTracking(with event: UIEvent?) { finish() }

    override func accessibilityIncrement() { adjust(1) }
    override func accessibilityDecrement() { adjust(-1) }

    var formattedAccessibilityValue: String {
        if let valueDescription { return valueDescription(Double(value)) }
        let span = max(maximumValue - minimumValue, 0.0001)
        let normalized = (value - minimumValue) / span
        return "\(Int((normalized * 100).rounded()))%"
    }

    private func adjust(_ direction: Float) {
        editingChanged?(true)
        let increment = step > 0 ? step : (maximumValue - minimumValue) / 10
        setClamped(value + increment * direction)
        editingChanged?(false)
    }
    private func update(_ touch: UITouch) {
        let track = trackRect(forBounds: bounds)
        let width = max(track.width - 28, 1)
        let x = touch.location(in: self).x
        let direction: CGFloat = effectiveUserInterfaceLayoutDirection == .rightToLeft ? -1 : 1
        let span = maximumValue - minimumValue
        if startedOnThumb {
            setClamped(startValue + Float(direction * (x - startX) / width) * span)
        } else {
            var fraction = (x - track.minX - 14) / width
            if direction < 0 { fraction = 1 - fraction }
            setClamped(minimumValue + Float(fraction) * span)
        }
    }
    private func setClamped(_ proposed: Float) {
        let snapped = step > 0 ? minimumValue + ((proposed - minimumValue) / step).rounded() * step : proposed
        let next = min(max(snapped, minimumValue), maximumValue)
        guard abs(value - next) > 0.00001 else { return }
        setValue(next, animated: false)
        accessibilityValue = formattedAccessibilityValue
        sendActions(for: .valueChanged)
    }
    private func finish() {
        guard dragging else { return }
        dragging = false
        editingChanged?(false)
    }
}
