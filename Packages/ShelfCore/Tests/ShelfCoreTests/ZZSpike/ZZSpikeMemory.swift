import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// V37 misconception memory (risk 4), in the spike's own write path. The unchanged evidence mapper
/// records misconceptions on core claims only, and a whole concept marked "wrong" says nothing about
/// which idea is wrong. This memory keeps the idea itself: the exact claim it contradicts (core or
/// supporting), that claim's family, what the learner believes, how sure the judgement was, the
/// learner's words, when and by which version it was found, and what has happened to it since.
/// It is `Codable`: a later session loads it and tests the idea again in a new context.
///
/// Write policy (decisive only, as the learner model's): a record is written or reconfirmed only when
/// the judgement commits a misconception without asking; a doubtful wrong idea is asked about, not
/// stored. A later firm, committed credit on the same claim family counts as a correction.
struct SpikeMisconceptionMemory: Codable, Equatable {
    static let version = "v37-spike-memory-1"

    struct Evidence: Codable, Equatable {
        let answerID: String
        let learnerText: String
        let at: Date
    }

    enum Repair: String, Codable { case open, probed, repaired }

    struct Reconfirmation: Codable, Equatable {
        enum Outcome: String, Codable { case stillHeld, corrected }
        let at: Date
        let answerID: String
        let outcome: Outcome
    }

    struct Record: Codable, Equatable {
        let id: String
        let documentID: String
        let concept: String
        /// The claim the idea contradicts, core or supporting, and the core claim heading its family.
        let claimID: String
        let claimRole: String
        let familyID: String
        /// What the learner believes: the matched likely mistake, or the learner's own words.
        let misconception: String
        let mistakeID: String?
        let kind: String
        let confusedWith: String?
        /// A question that tells the idea apart from the right one, when the answer key has one.
        let question: String?
        var confidence: Double
        var evidence: [Evidence]
        let detectedAt: Date
        let detectedVersion: String
        var repair: Repair
        var reconfirmations: [Reconfirmation]
    }

    var records: [Record] = []

    /// Reads one judged answer into the memory. Returns the ids of the records written or updated.
    @discardableResult
    mutating func observe(_ outcome: SpikeAdapter.Outcome, answerID: String, documentID: String, target: DiagnosisTarget,
                          key: SpikeAnswerKey?, at: Date) -> [String] {
        guard let checked = outcome.checked, let concept = target.concept?.value else { return [] }
        let judged = outcome.judged
        let roles = Dictionary(target.allClaims.map { ($0.id, $0.role == .core ? "core" : "supporting") }, uniquingKeysWith: { a, _ in a })
        var touched: [String] = []
        if judged.state == "misconception", !judged.asksProbe {
            for s in checked.segments where s.wrong != nil && s.wrongFirm {
                guard let claim = s.claimID, let role = roles[claim] else { continue }
                let mistake = key?.mistakes.first { $0.id == s.mistakeID }
                let id = [documentID, concept, claim, mistake?.id ?? s.wrong!.rawValue].joined(separator: "|")
                let evidence = Evidence(answerID: answerID, learnerText: s.text, at: at)
                if let index = records.firstIndex(where: { $0.id == id }) {
                    records[index].evidence.append(evidence)
                    records[index].confidence = min(0.99, records[index].confidence + (1 - records[index].confidence) / 2)
                    records[index].reconfirmations.append(Reconfirmation(at: at, answerID: answerID, outcome: .stillHeld))
                    records[index].repair = .open
                } else {
                    records.append(Record(id: id, documentID: documentID, concept: concept, claimID: claim, claimRole: role,
                                          familyID: s.familyID ?? claim, misconception: mistake?.text ?? s.text, mistakeID: mistake?.id,
                                          kind: s.wrong!.rawValue, confusedWith: s.confusedWith?.value, question: mistake?.question,
                                          confidence: judged.confidence, evidence: [evidence], detectedAt: at,
                                          detectedVersion: Self.version, repair: .open, reconfirmations: []))
                }
                touched.append(id)
            }
        } else if judged.recordsCredit, !judged.asksProbe {
            // Firm credit on a family that holds an open wrong idea: the learner now states it correctly.
            let corrected = Set(checked.segments.filter { $0.credit != nil && $0.creditFirm }.compactMap { $0.familyID ?? $0.claimID })
            for index in records.indices where records[index].documentID == documentID && records[index].concept == concept
                && records[index].repair != .repaired && corrected.contains(records[index].familyID) {
                records[index].reconfirmations.append(Reconfirmation(at: at, answerID: answerID, outcome: .corrected))
                records[index].repair = .repaired
                records[index].confidence = records[index].confidence / 2
                touched.append(records[index].id)
            }
        }
        return touched
    }

    /// The wrong ideas to test again in a new context for one concept: unrepaired, most confident first.
    func transferTargets(documentID: String, concept: String) -> [Record] {
        records.filter { $0.documentID == documentID && $0.concept == concept && $0.repair != .repaired }
            .sorted { $0.confidence > $1.confidence }
    }

    /// A transfer question about the record was asked (its answer is observed like any other).
    mutating func markProbed(_ id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }), records[index].repair == .open else { return }
        records[index].repair = .probed
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decoded(_ data: Data) throws -> SpikeMisconceptionMemory {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SpikeMisconceptionMemory.self, from: data)
    }
}

/// What one answer shows, as three independent facets (dev13): the state of each claim family, the state of
/// the reasoning, and the wrong ideas held. They coexist: a learner can state a claim correctly, justify it
/// with an invalid mechanism, and hold a separate misconception, all in one answer. The judge still gives one
/// state for the scorer; these facets are what a learner model can keep apart.
struct SpikeFacets: Codable, Equatable {
    enum Reasoning: String, Codable { case none, sound, unsettled, faulty }
    /// Core-claim family → covered · partial · contradicted, with whether it may be written now.
    var claims: [String: String] = [:]
    var firm: Set<String> = []
    var reasoning: Reasoning = .none
    /// Claims a wrong idea is firmly held about (the exact claim, core or supporting).
    var misconceptions: [String] = []

    init(_ checked: SpikeChecked) {
        for s in checked.segments {
            guard let family = s.familyID ?? s.claimID else { continue }
            if s.wrong != nil {
                claims[family] = "contradicted"
                if s.wrongFirm { firm.insert(family); if let claim = s.claimID { misconceptions.append(claim) } }
            } else if let credit = s.credit, claims[family] != "contradicted" {
                if claims[family] != "covered" { claims[family] = credit == .covered ? "covered" : "partial" }
                if s.creditFirm { firm.insert(family) }
            }
        }
        let reasons = checked.segments.filter { $0.reasonOf != nil }
        if reasons.contains(where: { $0.reasonConfirmed }) { reasoning = .faulty }
        else if reasons.contains(where: { !$0.reasonSupported }) { reasoning = .unsettled }
        else if !reasons.isEmpty || checked.links.contains(where: { checked.segments[$0.conclusion - 1].credit != nil }) { reasoning = .sound }
    }
}
