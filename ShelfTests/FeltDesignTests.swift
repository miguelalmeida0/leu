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
        XCTAssertEqual(PrimaryArea.allCases, [.home, .shelf, .learn, .notes, .explore, .trails])
        XCTAssertEqual(PrimaryArea.compactTabs, [.home, .shelf, .learn, .notes, .explore], "iPhone keeps five places")
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

    func testEveryIdeaAcrossLightsTheLastWindowOnly() {
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 0, of: 3), 0)
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 1, of: 3), 1)
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 2, of: 3), 2)
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 3, of: 3), 3)
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 1, of: 7), 1, "any idea across lights a window")
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 6, of: 7), 2, "only every idea lights the third")
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 1, of: 1), 3)
        XCTAssertEqual(TeachGlobeProgress.windows(captured: 0, of: 0), 0)
    }

    func testGlobeWordsMatchTheWindows() {
        XCTAssertEqual(TeachGlobeProgress.heading(windows: 2), "Two windows lit")
        XCTAssertEqual(TeachGlobeProgress.heading(windows: 3), "Every window lit")
        XCTAssertEqual(TeachGlobeProgress.listening(ideaCount: 3, page: 87),
                       "Three ideas from page 87. Each one you get across lights a window.")
    }

    func testSnowSettlesOnTheHillAndStaysInsideTheGlass() {
        let snow = GlobeSnow(count: 60, lit: 0)
        for frame in 0..<900 { snow.advance(to: Double(frame) / 30, reduced: false) }
        for flake in snow.flakes {
            let r = (flake.x * flake.x + flake.y * flake.y + pow(flake.z - GlobeSnow.centreZ, 2)).squareRoot()
            XCTAssertLessThanOrEqual(r, GlobeSnow.radius * 0.9 + 0.000_1)
        }
        snow.light(3, reduced: true)
        snow.advance(to: 31, reduced: true)
        XCTAssertEqual(snow.shown, 3, "Reduce Motion lights windows at once")
        let centre = GlobeSnow.project(0, 0, GlobeSnow.centreZ)
        XCTAssertEqual(centre.x, Double(GlobeArt.centre.x), accuracy: 2)
        XCTAssertEqual(centre.y, Double(GlobeArt.centre.y), accuracy: 2)
    }

    func testStudyWaysSayWhatTheyDo() {
        XCTAssertEqual(StudyWay.allCases.map(\.phrase), ["ask me a few things", "test my memory", "talk it through", "explain it my way"])
        XCTAssertTrue(StudyWay.learn.usesMinutes && StudyWay.interview.usesMinutes)
        XCTAssertFalse(StudyWay.recall.usesMinutes || StudyWay.explain.usesMinutes)
        XCTAssertEqual(StudyWay.interviewQuestions(minutes: 5), 3)
        XCTAssertEqual(StudyWay.interviewQuestions(minutes: 10), 5)
        XCTAssertEqual(StudyWay.interviewQuestions(minutes: 30), 12)
        XCTAssertEqual(TeachGlobeProgress.ideaWord(1), "one idea")
        XCTAssertEqual(TeachGlobeProgress.ideaWord(3), "three ideas")
        XCTAssertEqual(TeachGlobeProgress.ideaWord(9), "9 ideas")
    }
}
