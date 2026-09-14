import XCTest

final class ShelfRecoveryV25UITests: ShelfUITestCase {
    func test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels() {
        prepareAcceptedReactQuestions()
        openStudyAndStart(minutes: "10 minutes")
        advanceToAcceptedQuestion()
        XCTAssertTrue(element("question-card").waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["question-confidence-certain"].exists)
        tapStudyButton("question-option-0", scrollID: "study-activity")
        let names = ["Guessing", "Unsure", "Fairly sure", "Certain"]
        let controls = names.map { app.buttons[$0] }
        for (name, control) in zip(names, controls) {
            revealStudyButton(control.identifier, scrollID: "study-activity")
            XCTAssertTrue(control.waitForExistence(timeout: 5), name)
            XCTAssertEqual(control.label, name)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertTrue(control.isHittable, name)
        }
        for control in controls.dropFirst() {
            XCTAssertEqual(control.frame.width, controls[0].frame.width, accuracy: 1)
            XCTAssertEqual(control.frame.height, controls[0].frame.height, accuracy: 1)
        }
        tapStudyButton("question-confidence-fairlySure", scrollID: "study-activity")
        XCTAssertEqual(controls[2].value as? String, "Selected")
        capture("57-confidence-geometry")
    }

    func test58TrailContinueReturnsToTheRetainedTrail() throws {
        app.buttons["primary-trails"].tap()
        app.buttons["new-learning-trail"].tap()
        let title = app.textFields["Frontend interview"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("V25 route")
        app.buttons["Create"].tap()
        let trail = app.staticTexts["V25 route"]
        XCTAssertTrue(trail.waitForExistence(timeout: 8)); trail.tap()
        let add = app.buttons["Add stop"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        // The Documents action and the inline Page range picker legitimately
        // share this label. Select the unique action between the section headers.
        let documents = app.staticTexts["Documents"]
        let pageRange = app.staticTexts["Page range"]
        XCTAssertTrue(documents.waitForExistence(timeout: 5))
        XCTAssertTrue(pageRange.waitForExistence(timeout: 5))
        let matches = app.buttons.matching(identifier: "React Notes").allElementsBoundByIndex.filter {
            $0.frame.minY >= documents.frame.maxY && $0.frame.maxY <= pageRange.frame.minY
        }
        XCTAssertEqual(matches.count, 1, "Exactly one whole-document action must exist in Documents.")
        let document = try XCTUnwrap(matches.first)
        XCTAssertTrue(document.isHittable); document.tap()
        XCTAssertTrue(element("trail-add-confirmation").waitForExistence(timeout: 8))
        let next = app.buttons["trail-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        let back = app.buttons["reader-context-return"]
        XCTAssertTrue(back.waitForExistence(timeout: 10)); XCTAssertEqual(back.label, "Back to Trail")
        back.tap()
        XCTAssertTrue(app.navigationBars["V25 route"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your place"].exists)
        XCTAssertTrue(app.buttons["trail-continue"].exists)
        capture("58-trail-retained-position")
    }
}
