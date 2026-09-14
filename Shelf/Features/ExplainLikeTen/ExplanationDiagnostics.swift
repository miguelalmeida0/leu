import Foundation
import ShelfCore

/// Local status only. No passage, generated text, document title or identifier.
struct ExplanationDiagnostics: Codable, Equatable, Sendable {
    var availability: LearningModelState?
    var attempts = 0
    var responses = 0
    var accepted = 0
    var rejections = 0
    var lastValidationFailures: [String] = []
    var lastValidationWarnings: [String] = []
    var lastError: String?
    var lastResponseMilliseconds: Double?
}

/// Reporting only. Severity comes from the existing acceptance policy, so this
/// cannot introduce a second interpretation of which findings block an answer.
struct ExplanationValidationReport: Equatable, Sendable {
    let failures: [String]
    let warnings: [String]

    init(_ findings: [ExplanationValidator.Failure]) {
        let validator = ExplanationValidator()
        var fatal: [String] = [], advisory: [String] = []
        for finding in findings {
            if validator.isDisplayable([finding]) { advisory.append(finding.code) }
            else { fatal.append(finding.code) }
        }
        failures = fatal
        warnings = advisory
    }
}
