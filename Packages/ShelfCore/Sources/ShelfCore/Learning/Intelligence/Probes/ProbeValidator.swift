import Foundation

/// Rejects any probe that is not fully grounded, leaks its answer, or offers bad options.
public enum ProbeValidator {
    public static func failure(_ probe: LearningProbe, in knowledge: ConceptKnowledgeBase, analysis: DocumentAnalysis? = nil) -> String? {
        let claims = probe.rubricClaimIDs.map { id in knowledge.claims.first { $0.id == id } }
        guard !claims.isEmpty, claims.allSatisfy({ $0 != nil }) else { return "rubric claim missing" }
        guard !probe.evidence.isEmpty else { return "no evidence" }
        if let analysis, !(probe.evidence.allSatisfy { $0.isCurrent(in: analysis) }) { return "evidence not current" }
        guard probe.prompt.count >= 12, probe.prompt.count <= 420, probe.prompt.contains("?") else { return "prompt shape" }
        let template = probe.prompt.replacingOccurrences(of: #"“[^”]*”"#, with: "", options: .regularExpression)
        if QuestionSelfContainment.hasUnresolvedReference(template) { return "unresolved reference" }
        switch probe.operation {
        case .purpose, .mechanism, .condition:
            let answer = claims.compactMap { $0 }.map { $0.content }.joined(separator: " ")
            if PromptRealizer.leaks(probe.prompt, answer: answer) { return "prompt leaks answer" }
        default: break
        }
        if case .choice(let options, let answerIndex) = probe.format {
            guard (3...4).contains(options.count), options.indices.contains(answerIndex) else { return "option count" }
            let keys = options.map { ConceptKey($0) }
            guard Set(keys).count == options.count else { return "duplicate options" }
            guard keys[answerIndex] == probe.concept.concept || ConceptKey(probe.conceptName) == keys[answerIndex] else { return "answer is not the concept" }
            guard keys.allSatisfy({ knowledge.concept($0) != nil }) else { return "option is not a source concept" }
            if ProbeGenerator.names(probe.conceptName, in: template) { return "prompt names the answer" }
            // The quoted definition or example is source text: it must not give the answer away.
            let quoted = probe.prompt.split(separator: "“").dropFirst()
                .compactMap { $0.split(separator: "”", maxSplits: 1, omittingEmptySubsequences: false).first }.joined(separator: " ")
            let names = knowledge.concept(probe.concept.concept)?.names ?? [probe.conceptName]
            let distractors = options.indices.filter { $0 != answerIndex }.map { options[$0] }
            if ProbeGenerator.singlesOut(names, among: distractors, in: quoted) { return "quoted text points to the answer" }
        }
        return nil
    }
}
