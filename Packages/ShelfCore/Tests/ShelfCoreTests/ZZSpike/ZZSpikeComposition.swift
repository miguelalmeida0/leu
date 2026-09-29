import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).
// V37's general mechanisms between the checked reading and the unchanged judge: claim families
// (risk 1), partial entailment (risk 2), reason → conclusion composition (risk 3), and the
// independent whole-answer check that gates decisive writes (configuration D).

/// Claim families (risk 1). Every claim of a concept belongs to one core claim's family: a core claim
/// heads its own, and a supporting claim joins the core claim it elaborates, the one sharing the most
/// content stems with it (the concept's own name does not count). With no shared stem it joins the
/// definition, the idea the concept rests on. Built only from the claims' concept, role and text, so
/// it holds for any concept.
enum SpikeClaimFamily {
    static func families(_ target: DiagnosisTarget) -> [String: String] {
        let core = target.rubric.filter { $0.role == .core }
        guard !core.isEmpty else { return [:] }
        let names = Set((target.concept.flatMap { target.names[$0] } ?? []).flatMap { LexicalProfile($0).terms.map(\.stem) })
        func stems(_ claim: LearningClaim) -> Set<String> { LexicalProfile(claim.evidence.text).stems.subtracting(names) }
        let definition = core.first { $0.kind == .definition } ?? core[0]
        var result = Dictionary(core.map { ($0.id, $0.id) }, uniquingKeysWith: { a, _ in a })
        for claim in target.supporting where result[claim.id] == nil {
            let own = stems(claim)
            let scored = core.map { ($0, own.intersection(stems($0)).count) }
            let best = scored.max { a, b in a.1 != b.1 ? a.1 < b.1 : (b.0.id == definition.id) }
            result[claim.id] = (best.map { $0.1 > 0 } ?? false) ? best!.0.id : definition.id
        }
        return result
    }
}

enum SpikeComposition {
    /// Links fixed by the answer's discourse markers (C and D). The model's own links are kept only in
    /// B; in dev01–02 they linked every segment to every other and to itself.
    static func markerLinks(_ input: SpikeInput, text: String) -> [SpikeLink] {
        SpikeSegmenter.links(input.segments.map(\.text), text: text).map { SpikeLink(reason: $0.reason, conclusion: $0.conclusion) }
    }

    /// A true premise used to support a false conclusion earns nothing (risk 3): "JWTs are signed, so
    /// nobody can read them" is one wrong idea, not a credited premise plus a wrong idea. The premise's
    /// credit is withdrawn and it is kept as the misconception's premise. Runs last, in every
    /// configuration, after anything that can make a conclusion wrong.
    static func withholdPremises(_ checked: inout SpikeChecked) {
        for link in checked.links {
            let conclusion = checked.segments[link.conclusion - 1]
            guard conclusion.wrong != nil else { continue }
            var premise = checked.segments[link.reason - 1]
            guard premise.credit != nil else { continue }
            premise.credit = nil; premise.creditFirm = false; premise.premiseOf = link.conclusion
            checked.segments[link.reason - 1] = premise
            checked.fired.append("P1")
        }
    }

    /// Canonical claim ids for what is recorded: a credit or wrong idea on a supporting claim counts for
    /// its family's core claim. The segment keeps the claim it named for the misconception memory.
    static func canonicalize(_ checked: inout SpikeChecked, target: DiagnosisTarget) {
        let families = SpikeClaimFamily.families(target)
        for index in checked.segments.indices {
            guard checked.segments[index].familyID == nil, let id = checked.segments[index].claimID, let family = families[id] else { continue }
            checked.segments[index].familyID = family
            if family != id { checked.fired.append("F1") }
        }
    }

    /// Configuration D: the independent whole-answer check (correct · vague · mistaken · flawedReason)
    /// must agree before anything is written firmly, and a wrong idea must also be placed by the locator
    /// (which can answer "none"). Agreement keeps a label firm; anything else is asked about first.
    /// * Credit is firm only when the check says correct, or when the check's error is a wrong reason the
    ///   locator places elsewhere, behind this credited conclusion. Disputed credit counts as partial at most.
    /// * The located segment is a wrong idea (firm when V9 grounded it), unless the answer's own markers make
    ///   it the reason for a credited conclusion: then it is that conclusion's confirmed wrong reason. The
    ///   locator's own "kind" is recorded but not trusted (dev04: it called most misconceptions wrong reasons).
    /// * Disputed credit (risk 2): an answer the check does not call correct earns partial credit on one
    ///   idea at most — the definition's family when credited — so partial pieces never add up to mastery.
    /// * A wrong label the locator did not place is firm only when the check says mistaken.
    /// * A wrong answer nobody can place leaves no credit firm and is asked about as a misconception.
    static func applyAnswerCheck(_ opinion: SpikeSecondOpinionOutput?, definition: String?, to checked: inout SpikeChecked) {
        let verdicts = Dictionary((opinion?.verdicts ?? []).map { ($0.item, $0.verdict) }, uniquingKeysWith: { a, _ in a })
        let answer = opinion?.items.first { $0.kind == "answer" }.flatMap { verdicts[$0.item] }
        let locate = opinion?.items.first { $0.kind == "locate" }
        let placed = (locate?.segment ?? 0) > 0 ? locate!.segment : nil
        let wrongAnswer = answer == "mistaken" || answer == "flawedReason"
        let wrongReasonPlaced = wrongAnswer && placed.map { checked.segments[$0 - 1].reasonOf != nil } == true
        for index in checked.segments.indices {
            var s = checked.segments[index]
            // Disputed whether firm or already tentative (dev08: a full credit V7 had made tentative still
            // counted as covered, so "vague" answers reached "mostly").
            if s.credit != nil {
                let explained = wrongReasonPlaced && checked.segments[placed! - 1].reasonOf == s.n
                if !(answer == "correct" || explained) { s.credit = .partial; s.creditFirm = false; checked.fired.append("D-credit") }
            }
            if s.wrong != nil, s.wrongFirm {
                let agreed = s.n == placed ? wrongAnswer : answer == "mistaken"
                if !agreed { s.wrongFirm = false; checked.fired.append("D-wrong") }
            }
            if s.reasonOf != nil {
                s.reasonConfirmed = wrongAnswer && s.n == placed
                s.reasonSupported = answer == "correct" && ["entails", "partiallyEntails"].contains(s.relation)
            }
            checked.segments[index] = s
        }
        // Only credit the check disputes is capped (dev09: tentative credit the check agrees with was capped too).
        let disputed = answer == "correct" ? [] : checked.segments.filter { $0.credit != nil && !$0.creditFirm }
        if disputed.count > 1 {
            let keep = disputed.first { $0.familyID == definition } ?? disputed[0]
            for s in disputed where s.n != keep.n {
                checked.segments[s.n - 1].credit = nil; checked.segments[s.n - 1].claimID = nil
                checked.fired.append("D-cap")
            }
        }
        guard wrongAnswer, !checked.segments.contains(where: { $0.wrong != nil || ($0.reasonOf != nil && $0.reasonConfirmed) }) else { return }
        // Wrong, but placed nowhere (the locator said none): a conclusion drawn in the answer is the likeliest
        // place, then any statement the reading could not match, then the credited statements themselves.
        let conclusions = Set(checked.links.map(\.conclusion))
        let doubtful: [Int]
        if !conclusions.isEmpty { doubtful = Array(conclusions) }
        else {
            let unmatched = checked.segments.filter { $0.credit == nil && !["hedge", "filler"].contains($0.role) }.map(\.n)
            doubtful = unmatched.isEmpty ? checked.segments.filter { $0.credit != nil }.map(\.n) : unmatched
        }
        for n in doubtful {
            var s = checked.segments[n - 1]
            s.credit = nil; s.creditFirm = false
            s.wrong = .contradiction; s.wrongFirm = false
            s.claimID = s.claimID ?? s.named
            checked.segments[n - 1] = s
        }
        checked.fired.append("D-unplaced")
    }
}
