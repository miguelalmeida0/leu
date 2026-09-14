import Foundation

public struct TechnicalSpeechNormalizer: Sendable {
    private let acronyms = AcronymSpeechNormalizer()
    private let math = MathSpeechNormalizer()
    private let urls = URLSpeechNormalizer()
    private let typescript = TypeScriptSpeechNormalizer()
    private let networking = NetworkingSpeechNormalizer()
    private let operators = OperatorSpeechNormalizer()

    public init() {}

    public func normalize(_ input: String, dictionary: PronunciationDictionary = PronunciationDictionary()) -> String {
        var text = input
        text = urls.normalize(text)
        text = applyPronunciations(text, entries: dictionary.userEntries)
        text = applyPronunciations(text, entries: dictionary.systemEntries)
        text = typescript.normalize(text)
        text = networking.normalize(text)
        text = math.normalize(text)
        text = operators.normalize(text)
        text = acronyms.normalize(text)
        return SpeechRegex.collapseWhitespace(text)
    }

    private func applyPronunciations(_ input: String, entries: [PronunciationEntry]) -> String {
        entries.sorted { $0.display.count > $1.display.count }.reduce(input) { current, entry in
            SpeechRegex.escapedBoundaryReplace(entry.display, in: current, with: entry.spoken)
        }
    }

}
