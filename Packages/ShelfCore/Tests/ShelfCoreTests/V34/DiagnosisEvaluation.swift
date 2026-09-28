import Foundation
@testable import ShelfCore

/// Scores understanding diagnosis against the labeled fixture
/// (Tests/Fixtures/understanding-diagnosis-cases.json, labels written before V34 existed).
enum DiagnosisEvaluation {
    struct Case: Decodable {
        let id, split, document, text: String
        let page: Int?
        let concept: String?
        let covered, partial, conflicts, issues, optionalIssues: [String]
    }
    struct Fixture: Decodable { let cases: [Case] }

    struct Prediction {
        var claimCategories: [String: String] = [:]   // claim id -> covered/partial/conflict
        var issues: Set<String> = []
        var available = true
    }

    struct Report: CustomStringConvertible {
        var cases = 0, unavailable = 0, claimLabels = 0, claimStrict = 0, claimLenient = 0, claimUnrepresentable = 0
        var issueMust = 0, issueHit = 0, issueFalse = 0, claimFalseAlarms = 0, actionable = 0
        var perIssue: [String: (hit: Int, must: Int, falsePositive: Int)] = [:]
        var failures: [String] = []
        var actionableRate: Double { cases == 0 ? 0 : Double(actionable) / Double(cases) }
        var lenientRate: Double { claimLabels == 0 ? 0 : Double(claimLenient) / Double(claimLabels) }
        var issueRecall: Double { issueMust == 0 ? 0 : Double(issueHit) / Double(issueMust) }
        var description: String {
            let issues = perIssue.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.hit)/\($0.value.must) fp\($0.value.falsePositive)" }.joined(separator: " ")
            return "cases=\(cases) actionable=\(actionable) (\(Int((actionableRate * 100).rounded()))%) claimLenient=\(claimLenient)/\(claimLabels) strict=\(claimStrict) unrepresentable=\(claimUnrepresentable) issueRecall=\(issueHit)/\(issueMust) falseIssues=\(issueFalse) falseClaimAlignments=\(claimFalseAlarms) unavailable=\(unavailable) | \(issues)"
        }
    }

    static let fixture: Fixture = {
        let data = try! Data(contentsOf: LearningCorpus.fixtures.appendingPathComponent("understanding-diagnosis-cases.json"))
        return try! JSONDecoder().decode(Fixture.self, from: data)
    }()

    static let scoredIssues: Set<String> = ["contradiction", "causalReversal", "overgeneralization", "confusedConcept",
                                            "unsupported", "circular", "verbatim", "nonsense"]

    /// The claims a case's labels refer to, resolved by unique substring.
    static func labelClaim(_ key: String, in claims: [LearningClaim]) -> LearningClaim? {
        let needle = CanonicalWhitespaceResolver.normalize(key).lowercased()
        return claims.first { CanonicalWhitespaceResolver.normalize($0.evidence.text).lowercased().contains(needle) }
    }

    static func pageSource(_ document: String, _ page: Int) -> LearningSource {
        let analysis = LearningCorpus.analysis(document)
        let canonical = analysis.pages[page].canonicalText!
        return LearningSource(documentID: analysis.documentID, pageIndex: page, sourceText: canonical,
                              range: SourceTextRange(location: 0, length: canonical.utf16.count))
    }

    static func target(for item: Case) -> DiagnosisTarget? {
        let base = LearningCorpus.knowledge[item.document]!
        if let concept = item.concept { return DiagnosisTarget.concept(ConceptNames.key(concept), in: base) }
        return DiagnosisTarget.passage(pageSource(item.document, item.page!), in: base)
    }

    static func v34(_ item: Case) -> (Prediction, [LearningClaim]) {
        guard let target = target(for: item) else { return (Prediction(available: false), []) }
        let diagnosis = UnderstandingDiagnoser().diagnose(item.text, target: target)
        var prediction = Prediction()
        for assessment in diagnosis.claims {
            switch assessment.coverage {
            case .covered: prediction.claimCategories[assessment.claimID] = "covered"
            case .partial: prediction.claimCategories[assessment.claimID] = "partial"
            case .contradicted: prediction.claimCategories[assessment.claimID] = "conflict"
            case .missing: break
            }
        }
        for statement in diagnosis.statements {
            guard let id = statement.claimID, prediction.claimCategories[id] == nil,
                  target.supporting.contains(where: { $0.id == id }) else { continue }
            switch statement.verdict {
            case .supports, .restates: prediction.claimCategories[id] = "covered"
            case .partiallySupports, .overgeneralizes: prediction.claimCategories[id] = "partial"
            case .contradicts, .reverses: prediction.claimCategories[id] = "conflict"
            default: break
            }
        }
        prediction.issues = Set(diagnosis.issues.map(\.kind.rawValue)).intersection(scoredIssues)
        return (prediction, target.rubric + target.supporting)
    }

    /// The V27 Teach Leu validator on the same case (baseline, kept runnable).
    static func v27(_ item: Case) -> (Prediction, [LearningClaim]) {
        let analysis = LearningCorpus.analysis(item.document)
        let pageIndex: Int
        if let concept = item.concept {
            guard let card = LearningCorpus.knowledge[item.document]!.concept(ConceptNames.key(concept)) else { return (Prediction(available: false), []) }
            pageIndex = card.pageIndex
        } else { pageIndex = item.page! }
        guard let source = IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: pageIndex,
                sourceText: analysis.pages[pageIndex].canonicalText!), analysis: analysis) else { return (Prediction(available: false), []) }
        let result = TeachLeuValidator.evaluate(item.text, source: source)
        var prediction = Prediction()
        var claims: [LearningClaim] = []
        for claim in source.claims {
            guard let span = SourceSpan(resolving: claim.evidence.text, in: analysis.pages[pageIndex].canonicalText!,
                                        documentID: analysis.documentID, pageIndex: pageIndex) else { continue }
            let converted = LearningClaim(concept: ConceptKey(claim.concept), conceptName: claim.concept, kind: .property,
                subject: claim.concept, predicate: claim.predicate, object: claim.object, qualifier: claim.qualifier,
                negated: claim.negated, evidence: span, grounding: .literal, role: .core)
            claims.append(converted)
            if result.challenged.contains(where: { $0.sourceClaimID == claim.id }) { prediction.claimCategories[converted.id] = "conflict" }
            else if let supported = result.supported.first(where: { $0.claimID == claim.id }) {
                prediction.claimCategories[converted.id] = supported.complete ? "covered" : "partial"
            }
        }
        if !result.challenged.isEmpty { prediction.issues.insert("contradiction") }
        if !result.unsettled.isEmpty { prediction.issues.insert("unsupported") }
        return (prediction, claims)
    }

    static func evaluate(split: String, _ predictor: (Case) -> (Prediction, [LearningClaim])) -> Report {
        var report = Report()
        for item in fixture.cases where item.split == split {
            report.cases += 1
            let (prediction, claims) = predictor(item)
            if !prediction.available { report.unavailable += 1 }
            let labels = item.covered.map { ($0, "covered") } + item.partial.map { ($0, "partial") } + item.conflicts.map { ($0, "conflict") }
            var claimsRight = true, labeledIDs = Set<String>()
            for (key, expected) in labels {
                report.claimLabels += 1
                guard let claim = labelClaim(key, in: claims) else { report.claimUnrepresentable += 1; claimsRight = false; continue }
                labeledIDs.insert(claim.id)
                let predicted = prediction.claimCategories[claim.id] ?? "none"
                if predicted == expected { report.claimStrict += 1 }
                if predicted == expected || Set([predicted, expected]) == ["covered", "partial"] { report.claimLenient += 1 }
                else { claimsRight = false }
            }
            // Labels enumerate core claims. A consistent match to an unlabeled summary (supporting)
            // claim is not an error; any unlabeled core alignment, or any unlabeled conflict, is.
            // When the case itself is a contradiction, contradicting a summary that restates the
            // same idea is consistent, not an extra error.
            let expectsConflict = !item.conflicts.isEmpty
            let falseAlignments = prediction.claimCategories.filter { id, category in
                guard !labeledIDs.contains(id) else { return false }
                let supporting = claims.first(where: { $0.id == id })?.role == .supporting
                if supporting { return category == "conflict" && !expectsConflict }
                return true
            }.count
            report.claimFalseAlarms += falseAlignments
            let must = Set(item.issues), optional = Set(item.optionalIssues)
            let falseIssues = prediction.issues.subtracting(must).subtracting(optional)
            report.issueMust += must.count
            report.issueHit += must.intersection(prediction.issues).count
            report.issueFalse += falseIssues.count
            for kind in must { report.perIssue[kind, default: (0, 0, 0)].must += 1; if prediction.issues.contains(kind) { report.perIssue[kind]!.hit += 1 } }
            for kind in falseIssues { report.perIssue[kind, default: (0, 0, 0)].falsePositive += 1 }
            let actionable = claimsRight && must.isSubset(of: prediction.issues) && falseIssues.isEmpty && falseAlignments == 0
            if actionable { report.actionable += 1 }
            else {
                let predicted = prediction.claimCategories.map { id, category in "\(claims.first { $0.id == id }?.evidence.text.prefix(40) ?? "?")=\(category)" }
                report.failures.append("\(item.id): issues=\(prediction.issues.sorted()) must=\(must.sorted()) claims=\(predicted) expected=\(labels.map { "\($0.0.prefix(30))=\($0.1)" })")
            }
        }
        return report
    }
}
