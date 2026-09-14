import Foundation

public struct TeachSemanticAssessment: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case supported = "SUPPORTED", overgeneralized = "OVERGENERALIZED", contradicted = "CONTRADICTED"
        case incomplete = "INCOMPLETE", unsupported = "SOURCE_DOES_NOT_SUPPORT"
    }
    public let status: Status
    public let family: String?
    public let reasonCode: String
    public let explanation: String
    public let missingConditions: [String]
    public let complete: Bool
    public let backend: String
}

/// Bounded local semantic contracts. Concept aliases propose a family; each
/// family's predicate, polarity and scope rules independently decide admission.
/// An unrecognized family or unsupported extra technical assertion stays unsettled.
public enum TeachLeuV2 {
    public static func evaluate(_ learner: String, source: RelationalSourceFact,
                                analyses: [UUID: DocumentAnalysis]) -> TeachSemanticAssessment {
        guard source.isCurrent(in: analyses) else {
            return result(.unsupported, nil, "stale_source", "Reopen the current source before comparing this explanation.")
        }
        return compare(learner, sourceText: source.quote.text, topic: source.title)
    }
    static func compare(_ learner: String, sourceText: String, topic: String) -> TeachSemanticAssessment {
        let s = normalize(sourceText), text = normalize(learner), title = normalize(topic)
        func has(_ phrases: String...) -> Bool { phrases.contains { contains(text, $0) } }
        func sourceHas(_ phrases: String...) -> Bool { phrases.contains { contains(s, $0) } }
        func matches(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        let family: String?
        if sourceHas("react"), sourceHas("match"), sourceHas("stable key", "correct keys") { family = "react.stable-key" }
        else if (title == "retry" || sourceHas("retry", "retry failures")), sourceHas("temporary", "transient") { family = "reliability.retry" }
        else if (title == "unique constraint" || sourceHas("unique constraints", "unique constraint")), sourceHas("cannot appear more than once", "do not duplicate", "duplicates") { family = "db.unique-constraint" }
        else if (title == "closure" || sourceHas("a closure")), sourceHas("lexical", "scope where it was created"), sourceHas("access") { family = "programming.closure" }
        else if (title == "immutability" || sourceHas("without mutating the source array")), sourceHas("unchanged", "without mutating"), sourceHas("new values", "new array") { family = "programming.immutable-update" }
        else { family = nil }
        guard let family else { return result(.unsupported, nil, "unrepresented_semantic_family", "This source comparison cannot establish that statement.") }
        func supported(_ code: String, _ explanation: String, _ missing: [String] = []) -> TeachSemanticAssessment {
            // Relation recognition cannot license an unrelated extra assertion.
            // This controlled vocabulary is deliberately bounded: unknown content
            // words stay unsettled, even when another clause matches the source.
            let vocabulary = Self.words(s).union(Self.words(Self.commonVocabulary))
                .union(Self.words(Self.familyVocabulary[family] ?? ""))
            guard Self.words(text).isSubset(of: vocabulary) else {
                return result(.unsupported, family, "unrepresented_clause_content", "The core idea may match, but the source comparison cannot establish all of this statement.")
            }
            if family != "programming.immutable-update" && family != "db.unique-constraint",
               has("not", "never", "cannot", "can't", "don't", "doesn't", "no") {
                return result(.unsupported, family, "unresolved_polarity_scope", "The negative clause needs a source-supported interpretation before it can be accepted.")
            }
            return result(.supported, family, code, explanation, missing)
        }
        let sourceProtection = ProtectedSemanticTokens(sourceText), learnerProtection = ProtectedSemanticTokens(learner)
        if !learnerProtection.numbers.isEmpty, !learnerProtection.numbers.isSubset(of: sourceProtection.numbers) {
            return result(.unsupported, family, "unsupported_numeric_claim", "The supplied source does not establish the numbers in this explanation.")
        }
        // Alias ID/UNIQUE is allowed only inside its proved technical family;
        // other invented API names and operators remain unsupported.
        let aliasIdentifiers: Set<String> = family == "react.stable-key" ? ["ID", "IDs"] : (family == "db.unique-constraint" ? ["UNIQUE", "DB", "SQL"] : [])
        if !learnerProtection.identifiers.subtracting(sourceProtection.identifiers).subtracting(aliasIdentifiers).isEmpty ||
            !learnerProtection.operators.isSubset(of: sourceProtection.operators) {
            return result(.unsupported, family, "unsupported_identifier_or_operator", "This explanation introduces an identifier or operator that the source does not establish.")
        }
        if has("encrypt", "encryption", "faster", "speed", "security", "random keys are always safe"),
           !sourceHas("encrypt", "faster", "speed", "security") {
            return result(.unsupported, family, "unsupported_extra_effect", "The source does not establish that additional effect.")
        }
        switch family {
        case "react.stable-key":
            if has("globally", "every unrelated list", "all lists", "any list", "guarantees", "always preserve") {
                return result(.overgeneralized, family, "missing_identity_scope", "The source describes matching items within siblings; it does not give a global identity or unconditional state guarantee.", ["sibling-list scope", "no unconditional state guarantee"])
            }
            if matches(#"\b(?:do not|don't|does not|doesn't|cannot|can't|never) (?:help|match|recognize|identify|keep track)\b"#) ||
                matches(#"\b(?:prevent|prevents|stop|stops) react from (?:recognizing|matching|identifying)\b"#) || has("make react forget", "makes react forget") {
                return result(.contradicted, family, "identity_relation_reversed", "Your explanation reverses the source's key-to-item matching relationship.")
            }
            let identifier = has("key", "keys", "id", "ids", "identifier", "identifiers")
            let correspondence = has("same item", "same element", "previous item", "earlier instance", "which item is which", "which previous item", "previous instance", "recognize an item again")
            let relation = has("match", "recognize", "recognizing", "knows", "tell", "tells", "keep track", "keeps track", "identify")
            if identifier && correspondence && relation && has("react") {
                return supported("identity_core_captured", "You connected an item's identifier with recognizing the same item across list changes.", has("sibling", "siblings") ? [] : ["keys are compared among siblings"])
            }
        case "reliability.retry":
            let repeatAttempt = has("retry", "retries", "try again", "another attempt", "attempt the operation again", "attempting again", "another go")
            if repeatAttempt && (has("every failed", "all failed", "any failed", "every failure", "regardless", "guarantees", "always succeed")) {
                return result(.overgeneralized, family, "missing_transient_condition", "Retry is conditional on a failure that may be temporary; success is not guaranteed.", ["temporary/transient condition", "success remains uncertain"])
            }
            if repeatAttempt && (has("never retry temporary", "never retry transient", "permanent failures rather than temporary", "permanent instead of temporary")) {
                return result(.contradicted, family, "retry_condition_reversed", "Your retry condition reverses the source's temporary-failure condition.")
            }
            if repeatAttempt && has("temporary", "transient", "short-lived", "short lived", "can go away", "recovering") {
                return supported("transient_retry_captured", "You retained the condition that another attempt is appropriate for a potentially temporary failure.")
            }
            if repeatAttempt { return result(.overgeneralized, family, "missing_transient_condition", "Add the temporary-failure condition before generalizing retry to a failed request.", ["temporary/transient failure"]) }
        case "db.unique-constraint":
            let duplicate = has("duplicate", "duplicates", "repeated values", "same constrained value", "same value", "unique")
            let constraint = has("constraint", "constraints", "unique rule", "uniqueness constraint", "database")
            if duplicate && (has("allow duplicate", "allows duplicate", "both permitted", "permits duplicate")) {
                return result(.contradicted, family, "uniqueness_invariant_reversed", "The source says the constrained value or combination cannot appear more than once.")
            }
            if has("check", "checking") && has("application", "app") && !constraint {
                return result(.incomplete, family, "missing_concurrency_safety", "An application check alone omits the constraint that protects against check-then-insert races.", ["database constraint", "concurrent check-then-insert safety"])
            }
            if duplicate && constraint && has("rejects", "reject", "stops", "stop", "prevents", "prevent", "protection", "keeps", "guarantee", "cannot", "not") {
                return supported("uniqueness_constraint_captured", "You identified the constraint that protects the selected value or combination against duplicates, including concurrent inserts.")
            }
        case "programming.closure":
            if has("every variable", "any unrelated function", "all variables", "any scope", "whole program") {
                return result(.overgeneralized, family, "lexical_scope_overgeneralized", "The source grants access to the enclosing lexical environment, not arbitrary program variables.", ["enclosing lexical environment"])
            }
            if has("loses access", "cannot access", "can't access", "no access") && has("outer", "returned", "returns", "finishes") {
                return result(.contradicted, family, "lexical_access_reversed", "The source explicitly keeps access after the outer call returns.")
            }
            if has("function", "closure") && has("access", "reaches", "keeps", "retains", "retain") &&
                has("variables", "bindings", "environment", "scope") &&
                has("lexical", "surrounding", "enclosing", "outer", "where it was", "place where") {
                return supported("lexical_access_captured", "You connected the function with continued access to its enclosing lexical environment.")
            }
        case "programming.immutable-update":
            if has("deep cloning every", "deep clone every", "no values can ever change", "no value can ever change", "all values never change") {
                return result(.overgeneralized, family, "immutability_scope_overgeneralized", "The source preserves existing input while creating new values; it does not require deep-cloning everything or forbid new changed values.", ["preserve existing input", "new values may represent updates"])
            }
            let mutatingOriginal = matches(#"\b(?:mutating|mutates|edits|edit|changing|changes) (?:the )?(?:existing |original )?(?:input|value|object)\b"#)
            let negatedMutation = matches(#"\b(?:rather than|instead of|without|not) (?:editing|mutating|changing)\b"#)
            if mutatingOriginal && !negatedMutation {
                return result(.contradicted, family, "input_preservation_reversed", "That changes the existing input, whereas the source preserves it and creates a new value.")
            }
            let newValue = has("new", "fresh", "updated copy")
            let preserved = has("unchanged", "untouched", "intact", "alone", "rather than editing", "instead of changing", "without mutating")
            if newValue && preserved {
                return supported("immutable_update_captured", "You separated the new updated value from the existing input that remains unchanged.")
            }
        default: break
        }
        return result(.unsupported, family, "unsettled_relation", "The source does not establish this explanation as written.")
    }
    private static func result(_ status: TeachSemanticAssessment.Status, _ family: String?, _ code: String,
                               _ explanation: String, _ missing: [String] = []) -> TeachSemanticAssessment {
        .init(status: status, family: family, reasonCode: code, explanation: explanation,
            missingConditions: missing, complete: status == .supported && missing.isEmpty,
            backend: "deterministic-semantic-contracts; no-model-inference")
    }
    private static func normalize(_ value: String) -> String {
        CanonicalWhitespaceResolver.normalize(value).replacingOccurrences(of: "’", with: "'").lowercased()
    }
    private static func words(_ value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
    private static let commonVocabulary = "a an the this that these those it its it s is are was were be been being of to from for in on at by with without and or but so because if when while then after before even still again already also just as than rather instead does do can could may might should would will have has had how which where what same previous new existing other one two each including against"
    private static let familyVocabulary: [String: String] = [
        "react.stable-key": "react key keys stable consistent persistent id ids identifier identifiers identity item items element elements instance instances earlier previous list lists sibling siblings position order moves moved changes changed reorders reordering across needs need knows know tells tell recognize recognizes recognizing identify identifies match matches matching keep keeps track belongs let lets",
        "reliability.retry": "retry retries request failed failure failures error errors temporary transient short lived problem problems attempt attempts operation another give try trying later work works sense make makes go away recovering reason appropriate potentially uncertain",
        "db.unique-constraint": "unique uniqueness rule rules database constraint constraints constrained value values combination selected column columns duplicate duplicates repeated reject rejects stop stops prevent prevents protect protects protection keep keeps guarantee guarantees cannot not check checking app application code alone unsafe insufficient inserts insert inserting clients concurrent concurrency writes race races time",
        "programming.closure": "closure function functions access accessing reaches reach keeps keep retains retain retained brings bring variables variable bindings binding environment lexical surrounding enclosing scope outer call calls ends ended returns returned invocation outlives place made created continues continued",
        "programming.immutable-update": "immutability immutable update updates updated fresh value values data input original previous existing unchanged untouched intact alone keep keeps editing edit changing change creating create produces produce represent represents copy make leave leaves holds code mutable mutating mutation object objects array arrays"
    ]
    private static func contains(_ text: String, _ phrase: String) -> Bool {
        let pattern = #"(?<![a-z0-9_])"# + NSRegularExpression.escapedPattern(for: phrase) + #"(?![a-z0-9_])"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
