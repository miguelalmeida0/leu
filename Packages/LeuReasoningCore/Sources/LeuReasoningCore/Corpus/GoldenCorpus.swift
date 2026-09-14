import Foundation

/// The hand-curated certification corpus.
///
/// It is not training data. It is a fixed set of source claims, expected
/// chains, learner explanations and cross-source pairs whose outcomes are
/// asserted exactly, so any change in engine behaviour shows up as a diff.
public struct GoldenCorpus: Codable, Sendable {
    public struct Document: Codable, Sendable {
        public var id: String
        public var title: String
        public var note: String
    }

    public struct ConditionSpec: Codable, Sendable {
        public var text: String
        public var isPositive: Bool
    }

    public struct QualifierSpec: Codable, Sendable {
        public var kind: Qualifier.Kind
        public var text: String
    }

    public struct AtomSpec: Codable, Sendable {
        public var key: String
        public var doc: String
        public var page: Int
        public var role: SourceRole
        public var claimType: ClaimType
        public var subject: String
        public var relation: String
        public var object: String
        public var conditions: [ConditionSpec]
        public var qualifiers: [QualifierSpec]
        public var isNegated: Bool
        public var span: String
    }

    public struct ChainSpec: Codable, Sendable {
        public var key: String
        public var start: String
        public var labels: [String]
    }

    public struct LearnerCase: Codable, Sendable {
        public var key: String
        public var concept: String
        public var text: String
        public var expectedVerdict: AlignmentVerdict
        public var expectedMisconceptions: [MisconceptionType]
        public var note: String
    }

    public struct CrossSourceCandidate: Codable, Sendable {
        public var key: String
        public var first: String
        public var second: String
        public var expected: String
    }

    public var schemaVersion: Int
    public var extractionVersion: String
    public var documents: [Document]
    public var atoms: [AtomSpec]
    public var chains: [ChainSpec]
    public var learnerCases: [LearnerCase]
    public var crossSourceCandidates: [CrossSourceCandidate]

    public static func load(from url: URL) throws -> GoldenCorpus {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GoldenCorpus.self, from: data)
    }

    /// Builds the atoms, keeping the mapping from corpus key to the engine's
    /// content-derived id so expectations can be written in readable terms.
    public func buildAtoms() -> (atoms: [KnowledgeAtom], byKey: [String: KnowledgeAtom]) {
        var built: [KnowledgeAtom] = []
        var byKey: [String: KnowledgeAtom] = [:]
        for spec in atoms_specsSorted {
            let span = SourceSpan(documentID: spec.doc,
                                  page: spec.page,
                                  canonicalSpan: spec.span,
                                  sourceRole: spec.role,
                                  extractionVersion: extractionVersion)
            let atom = KnowledgeAtom(claimType: spec.claimType,
                                     subject: spec.subject,
                                     relation: GoldenCorpus.canonicalRelation(spec.relation),
                                     object: spec.object,
                                     concepts: [TextScanning.conceptSlug(spec.subject),
                                                TextScanning.conceptSlug(spec.object)].filter { !$0.isEmpty },
                                     qualifiers: spec.qualifiers.map { Qualifier(kind: $0.kind, text: $0.text) },
                                     isNegated: spec.isNegated,
                                     numbers: TextScanning.numbers(in: spec.span),
                                     identifiers: TextScanning.identifiers(in: spec.span),
                                     conditions: spec.conditions.map {
                                         ClaimCondition(text: $0.text,
                                                        isPositive: $0.isPositive,
                                                        concepts: [TextScanning.conceptSlug($0.text)])
                                     },
                                     sourceIntegrity: .normalized,
                                     provenance: Provenance.stated(span))
            built.append(atom)
            byKey[spec.key] = atom
        }
        return (built, byKey)
    }

    private var atoms_specsSorted: [AtomSpec] { atoms.sorted { $0.key < $1.key } }

    public func buildGraph() -> KnowledgeGraph {
        let built = buildAtoms()
        return KnowledgeGraphBuilder().build(atoms: built.atoms)
    }

    /// Corpus relations are written in source wording ("trades off",
    /// "is an example of"); the lexicon maps them onto the fixed vocabulary.
    public static func canonicalRelation(_ surface: String) -> String {
        if RelationKind(rawValue: surface) != nil { return surface }
        if let cue = RelationLexicon.cues.first(where: { $0.phrase == surface.lowercased() }) {
            return cue.kind.rawValue
        }
        return surface
    }
}
