import UIKit
import ShelfCore

/// One pan owner for a paginated viewport. Never modifies PDFKit's private scroll views.
/// Child pans wait for our decision; pinch and stationary text selection remain native.
@MainActor
final class ReaderPageTurnDriver: NSObject, UIGestureRecognizerDelegate {
    private weak var viewport: UIView?
    private weak var content: UIView?
    private var neighbor: UIView?
    private var neighborDelta: Int?
    private var animator: UIViewPropertyAnimator?
    private var policy = PageTurnPolicy()
    private var generation = 0
    private var cancelling = false
    private var touchOrigin: CGPoint?
    private(set) var isCommitting = false
    private(set) var isMoving = false
    var reduceMotion = false
    var consumesVerticalAtFit = false
    var diagnosticContext: () -> String = { "" }
    var canBegin: () -> Bool = { false }
    var pageState: () -> (index: Int, count: Int) = { (0, 0) }
    var preview: (Int) -> UIView? = { _ in nil }
    var commit: (Int) -> Void = { _ in }
    private(set) lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))

    func install(viewport: UIView, content: UIView) {
        self.viewport = viewport
        self.content = content
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        viewport.addGestureRecognizer(pan)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let allowed = canBegin() && !isCommitting
        touchOrigin = viewport.map { touch.location(in: $0) }
        trace("GESTURE_BEGIN hit=\(String(describing: touch.view)) canBegin=\(allowed)")
        guard allowed else { return false }
        var view = touch.view
        while let candidate = view, candidate !== viewport {
            if candidate is UIControl { trace("GESTURE_REJECT control=\(type(of: candidate))"); return false }
            view = candidate.superview
        }
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let viewport, canBegin(), !isCommitting else { return false }
        policy = PageTurnPolicy()
        let translation = displacement(in: viewport)
        let velocity = pan.velocity(in: viewport)
        _ = policy.lock(dx: Double(translation.x), dy: Double(translation.y),
                        velocityX: Double(velocity.x), velocityY: Double(velocity.y))
        // At full-page fit there is nothing to scroll vertically. Consume jitter as a no-op.
        // Reflowed text can be taller than the screen, so its vertical scroll must win instead.
        let allowed = policy.axis == .horizontal || consumesVerticalAtFit
        trace("GESTURE_ARBITRATION canBegin=\(allowed)")
        return allowed
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, other is UIPanGestureRecognizer,
              let viewport, let otherView = other.view else { return false }
        return otherView.isDescendant(of: viewport)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { false }

    @objc private func handle(_ recognizer: UIPanGestureRecognizer) {
        guard !cancelling, let viewport, let content else { return }
        switch recognizer.state {
        case .began:
            // UIKit's pan translation can begin after its recognition slop.
            // Feed the policy actual travel from touch-down, in the fixed viewport.
            recognizer.setTranslation(displacement(in: viewport), in: viewport)
            let existingOffset = content.layer.presentation()?.affineTransform().tx ?? content.transform.tx
            generation += 1
            animator?.stopAnimation(true)
            animator = nil
            if policy.axis == .horizontal && neighbor != nil {
                // Re-grabbing a settling page inherits its on-screen position, not the target.
                recognizer.setTranslation(CGPoint(x: existingOffset, y: 0), in: viewport)
                content.transform = CGAffineTransform(translationX: existingOffset, y: 0)
            } else {
                content.transform = .identity
                neighbor?.removeFromSuperview()
                neighbor = nil
                neighborDelta = nil
            }
            isMoving = true
            fallthrough
        case .changed:
            let travel = recognizer.translation(in: viewport)
            let velocity = recognizer.velocity(in: viewport)
            _ = policy.lock(dx: Double(travel.x), dy: Double(travel.y),
                            velocityX: Double(velocity.x), velocityY: Double(velocity.y))
            trace("GESTURE_MOVE")
            let dx = recognizer.translation(in: viewport).x
            let delta = dx < 0 ? 1 : -1
            let state = pageState()
            let exists = (0..<state.count).contains(state.index + delta)
            if policy.axis == .horizontal, exists, neighborDelta != delta {
                neighbor?.removeFromSuperview()
                neighbor = preview(delta)
                neighborDelta = delta
                if let neighbor {
                    neighbor.frame = viewport.bounds
                    neighbor.isUserInteractionEnabled = false
                    neighbor.accessibilityElementsHidden = true
                    viewport.addSubview(neighbor)
                }
            }
            let offset = CGFloat(policy.offset(dx: Double(dx), width: Double(viewport.bounds.width),
                                               hasNeighbor: exists && neighbor != nil))
            content.transform = CGAffineTransform(translationX: reduceMotion ? 0 : offset, y: 0)
            if let neighbor {
                neighbor.transform = CGAffineTransform(
                    translationX: CGFloat(neighborDelta ?? delta) * viewport.bounds.width + offset, y: 0)
                neighbor.isHidden = reduceMotion || policy.axis != .horizontal
            }
        case .ended:
            let state = pageState()
            let delta = policy.targetDelta(dx: Double(recognizer.translation(in: viewport).x),
                velocityX: Double(recognizer.velocity(in: viewport).x),
                velocityY: Double(recognizer.velocity(in: viewport).y), width: Double(viewport.bounds.width),
                page: state.index, count: state.count)
            trace("GESTURE_END targetDelta=\(String(describing: delta)) preview=\(neighbor != nil)")
            settle(delta: neighbor == nil ? nil : delta)
        case .cancelled, .failed:
            settle(delta: nil)
        default: break
        }
    }

    private func settle(delta: Int?) {
        guard let viewport, let content else { return }
        let destination = delta.map { -CGFloat($0) * viewport.bounds.width } ?? 0
        generation += 1
        let token = generation
        let finish: (UIViewAnimatingPosition) -> Void = { [weak self] position in
            guard let self, self.generation == token, position == .end else { return }
            self.animator = nil
            if let delta {
                self.isCommitting = true
                let before = self.pageState().index
                self.commit(delta)
                self.trace("GESTURE_COMMIT targetDelta=\(delta) pageBefore=\(before) pageAfter=\(self.pageState().index)")
                content.transform = .identity
                content.layoutIfNeeded()
                // The prepared incoming page covers the commit; never remove it before layout.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.finish()
                }
            } else { self.finish() }
        }
        if reduceMotion {
            finish(.end)
            return
        }
        let animation = UIViewPropertyAnimator(duration: delta == nil ? 0.22 : 0.24, dampingRatio: 1)
        animation.addAnimations { [weak self] in
            content.transform = CGAffineTransform(translationX: destination, y: 0)
            if let self, let neighbor = self.neighbor {
                neighbor.transform = CGAffineTransform(
                    translationX: CGFloat(self.neighborDelta ?? 1) * viewport.bounds.width + destination, y: 0)
            }
        }
        animation.addCompletion(finish)
        animator = animation
        animation.startAnimation()
    }

    /// Called for explicit jumps, mode changes, sheet presentation, and resizing.
    func cancel() {
        guard !isCommitting else { return }
        if isMoving { trace("GESTURE_CANCEL") }
        generation += 1
        animator?.stopAnimation(true)
        animator = nil
        finish()
        if pan.state == .began || pan.state == .changed {
            cancelling = true
            pan.isEnabled = false
            pan.isEnabled = true
            cancelling = false
        }
    }

    private func finish() {
        content?.transform = .identity
        neighbor?.transform = .identity
        neighbor?.removeFromSuperview()
        neighbor = nil
        neighborDelta = nil
        isMoving = false
        isCommitting = false
        policy = PageTurnPolicy()
    }

    private func displacement(in viewport: UIView) -> CGPoint {
        guard let origin = touchOrigin else { return pan.translation(in: viewport) }
        let point = pan.location(in: viewport)
        return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    private func trace(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["LEU_UI_DIAGNOSTICS"] == "1", let viewport else { return }
        StudyInteractionTrace.record("\(event) viewport=\(viewport.accessibilityIdentifier ?? "unknown") \(diagnosticContext()) translation=\(pan.translation(in: viewport)) travel=\(displacement(in: viewport)) velocity=\(pan.velocity(in: viewport)) state=\(pan.state.rawValue) axis=\(policy.axis) page=\(pageState().index)")
        #endif
    }
}
