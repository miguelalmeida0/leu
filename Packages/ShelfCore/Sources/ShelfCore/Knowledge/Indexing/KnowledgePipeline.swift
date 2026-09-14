import Foundation

public struct KnowledgeDocumentBundle: Sendable {
    public var assembly: PassageAssembly
    public var index: KnowledgeIndexBuild
    public var importState: ImportAnalysisState
    public init(assembly: PassageAssembly, index: KnowledgeIndexBuild, importState: ImportAnalysisState) {
        self.assembly = assembly; self.index = index; self.importState = importState
    }
}

public struct KnowledgePipeline: Sendable {
    private let assembler = PassageAssembler()
    private let indexBuilder = KnowledgeIndexBuilder()
    public init() {}

    public func index(analysis: DocumentAnalysis, concepts: [KnowledgeConcept], aliases: [ConceptAlias]) -> KnowledgeDocumentBundle {
        let assembly = assembler.assemble(analysis)
        let index = indexBuilder.build(passages: assembly.passages, concepts: concepts, aliases: aliases)
        let state = ImportAnalysisState(documentID: analysis.documentID, fingerprint: analysis.fingerprint,
                                        versions: .current, passageCount: assembly.passages.count)
        return KnowledgeDocumentBundle(assembly: assembly, index: index, importState: state)
    }
}
