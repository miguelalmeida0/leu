import SwiftUI

/// One motion vocabulary for the whole app. Reader interactions do not invent local curves.
enum ShelfMotion {
    static let chromeIn = Animation.easeOut(duration: 0.12)
    static let chromeOut = Animation.easeIn(duration: 0.24)
    static let sheetPresent = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.85)
    static let pageSettle = Animation.interactiveSpring(response: 0.32, dampingFraction: 0.90)
    static let gentle = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)

    static func rubberBand(distance: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        guard distance != 0, dimension > 0 else { return 0 }
        let sign: CGFloat = distance < 0 ? -1 : 1
        let magnitude = abs(distance)
        let offset = (1 - (1 / ((magnitude * constant / dimension) + 1))) * dimension / constant
        return sign * offset
    }
}
