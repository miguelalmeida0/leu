import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

enum SpikeConfig: String, CaseIterable { case b = "B", c = "C", d = "D" }
enum SpikeWrongKind: String { case contradiction, reversal, overgeneralization, confusion }

/// A reading after the checks: per segment, what may count and how firmly. Checks only ever
/// downgrade (firm → tentative credit, firm → doubtful wrong idea, confirmed → unconfirmed reason).
struct SpikeChecked {
    struct Segment {
        let n: Int
        let text: String
        var role = "statement", relation = "unrelated", polarity = "affirmed", specificity = "specific"
        var claimID: String?
        var mistakeID: String?
        var credit: ClaimCoverage?          // .covered or .partial
        var creditFirm = false
        var wrong: SpikeWrongKind?
        var wrongFirm = false
        var confusedWith: ConceptKey?
        var reasonOf: Int?                  // the credited conclusion this segment is a wrong reason for
        var reasonConfirmed = false
        /// The claim the model tied the segment to (its claim, or the claim its mistake contradicts),
        /// kept when a wrong reason is folded into its conclusion: the claim a repair question asks about.
        var named: String?
        var confidence = "high"
    }
    var segments: [Segment]
    /// Reason → conclusion links that survived V1 and, in C and D, V8.
    var links: [SpikeLink] = []
    var fired: [String] = []
}

enum SpikeChecks {
    static let roles: Set = ["statement", "reason", "example", "analogy", "hedge", "filler"]
    static let relations: Set = ["entails", "partiallyEntails", "contradicts", "unrelated"]
    static let conclusionMarkers: Set = ["therefore", "thus", "hence", "that's why", "that is why", "which means"]
    static let confidences: Set = ["high", "medium", "low"]

    /// V1 (every configuration): nil when the reading cannot be used at all, i.e. a schema error.
    static func check(_ reading: SpikeReading, input: SpikeInput, text: String, key: SpikeAnswerKey?, target: DiagnosisTarget,
                      config: SpikeConfig, opinion: SpikeSecondOpinionOutput?) -> SpikeChecked? {
        let k = input.segments.count
        let claimIDs = Set(input.claims.map(\.id)), mistakes = key?.mistakes ?? []
        guard k > 0, reading.segments.count == k, Set(reading.segments.map(\.n)) == Set(1...k),
              reading.segments.allSatisfy({ label in
                  (label.claim == "none" || claimIDs.contains(label.claim)) && roles.contains(label.role) && relations.contains(label.relation)
                      && (label.misconception == "none" || mistakes.contains { $0.id == label.misconception })
                      && (label.confidence.map(confidences.contains) ?? true)
              }) else { return nil }
        var checked = SpikeChecked(segments: input.segments.map { SpikeChecked.Segment(n: $0.n, text: $0.text) })
        let neighbours = Dictionary(input.neighbours.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        for label in reading.segments {
            var s = checked.segments[label.n - 1]
            s.role = label.role; s.relation = label.relation; s.polarity = label.polarity; s.specificity = label.specificity
            let mistake = mistakes.first { $0.id == label.misconception }
            s.named = label.claim != "none" ? label.claim : mistake?.contradicts
            s.confidence = label.confidence ?? "high"
            if ["entails", "partiallyEntails"].contains(label.relation), label.claim != "none" {
                s.claimID = label.claim; s.credit = label.relation == "entails" ? .covered : .partial; s.creditFirm = true
            } else if label.relation == "contradicts", label.claim != "none" || mistake != nil || neighbours[label.describes] != nil {
                // The relation decides; a mistake id only says which kind of wrong idea it is.
                let neighbour = mistake.flatMap { neighbours[$0.confusedWith] } ?? neighbours[label.describes]
                var wrong = mistake.map(kind) ?? (neighbour != nil ? SpikeWrongKind.confusion : .contradiction)
                if wrong == .confusion && neighbour == nil { wrong = .contradiction }
                s.wrong = wrong
                s.confusedWith = wrong == .confusion ? neighbour.map { ConceptKey($0.key) } : nil
                s.claimID = label.claim != "none" ? label.claim : mistake?.contradicts
                s.mistakeID = mistake?.id
                s.wrongFirm = true
            }
            checked.segments[label.n - 1] = s
        }
        var links = reading.links.filter { (1...k).contains($0.reason) && (1...k).contains($0.conclusion) && $0.reason != $0.conclusion }
        links = links.filter { link in !links.contains { $0.reason == link.conclusion && $0.conclusion == link.reason } }
        if config != .b {
            let kept = links.filter { markerSupports($0, checked: checked, text: text) }
            if kept.count < links.count { checked.fired.append("V8") }
            links = kept
        }
        checked.links = links
        applyLinks(links, to: &checked)
        guard config != .b else { return checked }
        verify(&checked, target: target, input: input, key: key)
        if config == .d { applyOpinion(opinion, to: &checked) }
        return checked
    }

    static func kind(_ mistake: SpikeAnswerKey.Mistake) -> SpikeWrongKind {
        switch mistake.kind {
        case "reversed": return .reversal
        case "overgeneralized": return .overgeneralization
        case "confused": return .confusion
        default: return .contradiction
        }
    }

    /// A wrong or unsupported reason given for a credited conclusion is judged as a reason, not as a
    /// separate idea. A reason that itself entails a claim is a supported reason and stays a statement.
    static func applyLinks(_ links: [SpikeLink], to checked: inout SpikeChecked) {
        for link in links where checked.segments[link.conclusion - 1].credit != nil {
            var reason = checked.segments[link.reason - 1]
            guard reason.credit == nil else { continue }
            reason.reasonOf = link.conclusion; reason.reasonConfirmed = true
            reason.wrong = nil; reason.wrongFirm = false; reason.claimID = nil; reason.mistakeID = nil; reason.confusedWith = nil
            checked.segments[link.reason - 1] = reason
        }
    }

    /// V8: a link needs the reason role or a marker at the boundary.
    static func markerSupports(_ link: SpikeLink, checked: SpikeChecked, text: String) -> Bool {
        let reason = checked.segments[link.reason - 1], conclusion = checked.segments[link.conclusion - 1]
        if reason.role == "reason" { return true }
        if let marker = SpikeSegmenter.leadingMarker(reason.text), SpikeSegmenter.introducesReason.contains(marker) { return true }
        if let marker = SpikeSegmenter.leadingMarker(conclusion.text), conclusionMarkers.contains(marker) { return true }
        guard let r = text.range(of: reason.text), let c = text.range(of: conclusion.text) else { return false }
        let gap = r.upperBound <= c.lowerBound ? text[r.upperBound..<c.lowerBound] : (c.upperBound <= r.lowerBound ? text[c.upperBound..<r.lowerBound] : "")
        return gap.lowercased().range(of: #"\bso\b|\bbecause\b|\bsince\b"#, options: .regularExpression) != nil
    }

    /// V2–V7 on credit, V9 on wrong ideas, V10 on both.
    static func verify(_ checked: inout SpikeChecked, target: DiagnosisTarget, input: SpikeInput, key: SpikeAnswerKey?) {
        let claims = Dictionary((target.rubric + target.supporting).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nameStems = Set((target.concept.flatMap { target.names[$0] } ?? []).flatMap { LexicalProfile($0).terms.map(\.stem) })
        var strongSupport = Set<String>()   // claims credited by at least one specific, non-trivial segment
        for index in checked.segments.indices {
            var s = checked.segments[index]
            let profile = LexicalProfile(s.text)
            if s.credit != nil, ["hedge", "filler"].contains(s.role) {
                s.credit = nil; s.creditFirm = false; s.claimID = nil; checked.fired.append("V2")
            }
            if s.credit != nil, let id = s.claimID, let claim = claims[id] {
                let claimProfile = LexicalProfile(claim.evidence.text)
                let segmentNegative = profile.negationCount > 0
                let claimNegative = claim.negated || claimProfile.negationCount > 0
                if segmentNegative != claimNegative || (s.polarity == "negated") != segmentNegative { mark(&s, "V3", &checked) }
                if antonym(profile, claimProfile) { mark(&s, "V4", &checked) }
                if !profile.universals.isEmpty, !claimProfile.hedges.isEmpty { mark(&s, "V5", &checked) }
                if reversedOrder(profile, claim: claim) { mark(&s, "V6", &checked) }
                if s.specificity == "specific", contentWords(s.text, excluding: nameStems) > 3 { strongSupport.insert(id) }
            }
            if s.wrong != nil, s.wrongFirm {
                var stems = Set<String>()
                if let id = s.claimID, let claim = claims[id] { stems.formUnion(LexicalProfile(claim.evidence.text).stems) }
                if let id = s.mistakeID, let mistake = key?.mistakes.first(where: { $0.id == id }) { stems.formUnion(LexicalProfile(mistake.text).stems) }
                if let confused = s.confusedWith, let neighbour = input.neighbours.first(where: { $0.key == confused.value }) {
                    stems.formUnion(LexicalProfile(neighbour.definition).stems)
                }
                let grounded = !profile.stems.subtracting(nameStems).isDisjoint(with: stems.subtracting(nameStems))
                let backed = s.claimID.flatMap { claims[$0] }.map { claim -> Bool in
                    let claimProfile = LexicalProfile(claim.evidence.text)
                    return (profile.negationCount > 0) != (claim.negated || claimProfile.negationCount > 0) || antonym(profile, claimProfile)
                        || (!profile.universals.isEmpty && !claimProfile.hedges.isEmpty)
                } ?? false
                if !grounded && !backed { s.wrongFirm = false; checked.fired.append("V9") }
            }
            // V10: what the model itself calls a low-confidence label is never written firmly.
            if s.confidence == "low" {
                if s.creditFirm { mark(&s, "V10", &checked) }
                if s.wrong != nil, s.wrongFirm { s.wrongFirm = false; checked.fired.append("V10") }
            }
            checked.segments[index] = s
        }
        // V7: credit resting only on vague or very short (≤ 3 content words) segments is tentative.
        for index in checked.segments.indices {
            let s = checked.segments[index]
            guard let id = s.claimID, s.credit != nil, s.creditFirm, !strongSupport.contains(id) else { continue }
            checked.segments[index].creditFirm = false
            checked.fired.append("V7")
        }
    }

    /// V35's own function words: its closed-class lists and the connectives its keyword-list rule uses.
    static let functionWords: Set<String> = ClauseLexicon.auxiliaries.union(ClauseLexicon.determiners).union(ClauseLexicon.prepositions)
        .union(ClauseLexicon.subordinators).union(["and", "or", "but", "not", "no", "so", "it", "its", "they", "their", "them", "this",
                                                    "these", "those", "that", "which", "who", "what", "when", "if", "because", "than",
                                                    "as", "you", "your", "we", "i"])

    /// V7's "content words": every word outside the function words and the concept's own name.
    static func contentWords(_ text: String, excluding nameStems: Set<String>) -> Int {
        Lexicon.words(text.lowercased()).filter { word in
            word.first?.isLetter == true && !functionWords.contains(word) && !nameStems.contains(Lexicon.stem(word))
        }.count
    }

    static func antonym(_ segment: LexicalProfile, _ claim: LexicalProfile) -> Bool {
        segment.terms.contains { term in
            !claim.stems.contains(term.stem) && claim.terms.contains { SemanticAntonyms.opposed(term.stem, $0.stem) }
        }
    }

    /// V6 (crude): the claim's subject and object head words appear in the opposite order.
    static func reversedOrder(_ segment: LexicalProfile, claim: LearningClaim) -> Bool {
        guard let subject = LexicalProfile(claim.subject).terms.last?.stem, let object = LexicalProfile(claim.object).terms.last?.stem,
              subject != object else { return false }
        let stems = segment.terms.map(\.stem)
        guard let s = stems.firstIndex(of: subject), let o = stems.firstIndex(of: object) else { return false }
        return o < s
    }

    static func mark(_ segment: inout SpikeChecked.Segment, _ check: String, _ checked: inout SpikeChecked) {
        guard segment.creditFirm else { return }
        segment.creditFirm = false
        checked.fired.append(check)
    }

    /// The second opinion (D): firm only where it agrees; anything unchecked or disputed is asked about.
    static func applyOpinion(_ opinion: SpikeSecondOpinionOutput?, to checked: inout SpikeChecked) {
        let verdicts = Dictionary((opinion?.verdicts ?? []).map { ($0.item, $0.verdict) }, uniquingKeysWith: { a, _ in a })
        func verdict(_ kind: String, _ n: Int) -> String? {
            opinion?.items.first { $0.kind == kind && $0.segment == n }.flatMap { verdicts[$0.item] }
        }
        for index in checked.segments.indices {
            var s = checked.segments[index]
            if s.credit != nil {
                switch verdict("credit", s.n) {
                case "same"?: break
                case "part"? where s.credit == .partial: break
                case "opposite"?:
                    s.wrong = .contradiction; s.wrongFirm = false; s.credit = nil; s.creditFirm = false
                default: s.creditFirm = false
                }
            }
            if let wrong = s.wrong, s.wrongFirm {
                let agreed = wrong == .confusion ? ["same", "part"].contains(verdict("confusion", s.n) ?? "")
                    : verdict("contradiction", s.n) == "opposite"
                if !agreed { s.wrongFirm = false }
            }
            if s.reasonOf != nil { s.reasonConfirmed = ["opposite", "different"].contains(verdict("reason", s.n) ?? "") }
            checked.segments[index] = s
        }
    }
}
