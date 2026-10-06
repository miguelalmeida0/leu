import SwiftUI
import UIKit
import XCTest
@testable import Shelf

/// The Felt system's load-bearing promises: the bundled faces really register and resolve,
/// sizes keep scaling with the right Dynamic Type style, and Home greets by the clock.
@MainActor
final class FeltDesignTests: XCTestCase {
    private let faces = ["Gabarito-Regular", "Gabarito-Medium", "Gabarito-SemiBold", "Gabarito-Bold",
                         "Gabarito-ExtraBold", "Gabarito-Black", "Literata-Regular", "Literata-Medium",
                         "Literata-SemiBold", "Literata-Italic"]

    func testEveryBundledFaceRegistersAndResolves() {
        LeuType.registerFonts()
        LeuType.registerFonts()   // idempotent: a second call must not fail or duplicate
        for face in faces {
            XCTAssertNotNil(UIFont(name: face, size: 17), "\(face) did not resolve after registration")
        }
    }

    func testWeightsResolveToRealFaces() {
        XCTAssertEqual(LeuType.sansFace(.heavy), "Gabarito-ExtraBold")
        XCTAssertEqual(LeuType.sansFace(.bold), "Gabarito-Bold")
        XCTAssertEqual(LeuType.sansFace(.light), "Gabarito-Regular")
        XCTAssertEqual(LeuType.serifFace(.bold), "Literata-SemiBold")
        XCTAssertEqual(LeuType.serifFace(.regular), "Literata-Regular")
    }

    func testFixedSizesScaleWithTheMatchingTextStyle() {
        XCTAssertEqual(LeuType.textStyle(for: 46), .largeTitle)
        XCTAssertEqual(LeuType.textStyle(for: 18), .body)
        XCTAssertEqual(LeuType.textStyle(for: 15), .subheadline)
        XCTAssertEqual(LeuType.textStyle(for: 11), .caption2)
        XCTAssertEqual(LeuType.size(for: .body), 17)
        XCTAssertEqual(LeuType.size(for: .caption2), 11)
    }

    func testHomeGreetsByTheClock() {
        func at(_ hour: Int) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: 10, second: 0, of: Date())!
        }
        XCTAssertEqual(HomeScreen.greeting(for: at(3)), "Late night")
        XCTAssertEqual(HomeScreen.greeting(for: at(8)), "Good morning")
        XCTAssertEqual(HomeScreen.greeting(for: at(14)), "Good afternoon")
        XCTAssertEqual(HomeScreen.greeting(for: at(19)), "Good evening")
        XCTAssertEqual(HomeScreen.greeting(for: at(23)), "Late night")
    }

    func testHomeLeadsTheNavigation() {
        XCTAssertEqual(PrimaryArea.allCases, [.home, .shelf, .learn, .trails])
        XCTAssertEqual(PrimaryArea.home.title, "Home")
    }

    func testRainVoiceIsSilentUntilAsked() {
        let voice = RainVoice()
        let quiet = (0..<2_000).map { _ in abs(voice.nextSample()) }.max() ?? 1
        XCTAssertLessThan(quiet, 0.000_1)
        voice.target = 0.55
        let audible = (0..<44_100).map { _ in abs(voice.nextSample()) }.max() ?? 0
        XCTAssertGreaterThan(audible, 0.001)
        XCTAssertLessThan(audible, 1, "rain must never clip")
    }
}
