import Foundation

/// One final surface gate shared by fresh compilation, model admission and stored banks.
/// Claim entailment remains the responsibility of the semantic/V2 realizer.
public enum FinalMCQAdmission {
    public static func rejectionReason(_ question: LearningQuestion, analysis: DocumentAnalysis? = nil) -> String? {
        if question.modelProvenance?.schemaVersion == 3 {
            guard let analysis else { return "v3_missing_analysis" }
            if let failure = QuestionV3Validator.persistedFailure(question, analysis: analysis) { return failure }
        }
        guard (3...4).contains(question.options.count), let answer = question.correctOption?.text else { return "invalid_options" }
        let options = question.options.map(\.text)
        guard Set(options.map(normalize)).count == options.count else { return "duplicate_options" }
        for option in options {
            let letters = option.filter { !$0.isWhitespace }.uppercased()
            if ["INONEBREATH", "MAKEITSTICK", "REALEXAMPLE"].contains(where: letters.contains) { return "section_label_option" }
            if InstructionalText.isReaderInstruction(option) { return "instruction_option" }
            if InstructionalText.isMemoryContent(option) || InstructionalText.isMemoryHook(subject: option, sentence: option) { return "mnemonic_option" }
        }
        if InstructionalText.isReaderInstruction(question.source.sourceText) { return "instruction_source" }
        let others = question.options.filter { $0.id != question.correctOptionID }.map(\.text)
        if let reason = QuestionOptionQuality.rejectionReason(prompt: question.prompt, answer: answer, alternatives: others) { return reason }
        if let analysis {
            guard let page = analysis.pages.first(where: { $0.pageIndex == question.source.pageIndex }),
                  page.isIntelligenceEligible else { return "degraded_or_missing_page" }
            let source = page.canonicalText ?? page.normalizedText
            guard !question.source.sourceText.isEmpty,
                  source.filter({ !$0.isWhitespace }).contains(question.source.sourceText.filter { !$0.isWhitespace }) else { return "source_page_boundary" }
        }
        return nil
    }
    private static func normalize(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
