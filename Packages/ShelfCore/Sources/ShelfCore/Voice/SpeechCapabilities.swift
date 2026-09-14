import Foundation

public protocol SpeechCompiling: Sendable {
    func compile(document: SpeechDocument, dictionary: PronunciationDictionary,
                 rate: SpeechRateProfile, codeMode: CodeSpeechMode) -> SpeechPlan
}

extension SpeechCompiler: SpeechCompiling {}
