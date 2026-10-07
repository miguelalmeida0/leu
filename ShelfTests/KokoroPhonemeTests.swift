import XCTest
@testable import Shelf

/// The Kokoro front end without a model: Misaki's lexicon rules, the phonemizer's word
/// order and context, number reading, the vocabulary and the chunking.
final class KokoroPhonemeTests: XCTestCase {
    private func lexicon() -> KokoroLexicon {
        KokoroLexicon(golds: [
            "the": .word("ði"), "sky": .word("skˈI"), "is": .word("ɪz"), "blue": .word("blˈu"),
            "cat": .word("kˈæt"), "walk": .word("wˈɔk"), "jump": .word("ʤˈʌmp"), "apple": .word("ˈæpəl"),
            "read": .tagged(["DEFAULT": "ɹˈid", "VBD": "ɹˈɛd"]), "to": .word("tu"),
            "A": .word("ˈA"), "B": .word("bˈi"), "C": .word("sˈi"),
        ], silvers: [:], british: false)
    }

    func testStressRulesMatchMisaki() {
        XCTAssertEqual(KokoroLexicon.applyStress("kˈæt", -1), "kˌæt")
        XCTAssertEqual(KokoroLexicon.applyStress("kˈæt", -2), "kæt")
        XCTAssertEqual(KokoroLexicon.applyStress("kæt", 2), "kˈæt")
        XCTAssertEqual(KokoroLexicon.applyStress("kæt", 0.5), "kˌæt")
        XCTAssertEqual(KokoroLexicon.applyStress("kˌæt", 1), "kˈæt")
        XCTAssertEqual(KokoroLexicon.applyStress("st", 2), "st", "no vowel, no stress")
    }

    func testSuffixesFollowTheLastSound() {
        let lexicon = lexicon(), context = KokoroLexicon.Context()
        XCTAssertEqual(lexicon.phonemes(for: "cats", tag: nil, context: context), "kˈæts")
        XCTAssertEqual(lexicon.phonemes(for: "walked", tag: nil, context: context), "wˈɔkt")
        XCTAssertEqual(lexicon.phonemes(for: "jumping", tag: nil, context: context), "ʤˈʌmpɪŋ")
        XCTAssertEqual(lexicon.phonemes(for: "apples", tag: nil, context: context), "ˈæpəlz")
    }

    func testPartOfSpeechAndContextChooseTheSound() {
        let lexicon = lexicon()
        XCTAssertEqual(lexicon.phonemes(for: "read", tag: "VBD", context: .init()), "ɹˈɛd")
        XCTAssertEqual(lexicon.phonemes(for: "read", tag: "NN", context: .init()), "ɹˈid")
        XCTAssertEqual(lexicon.phonemes(for: "the", tag: "DT", context: .init(futureVowel: true)), "ði")
        XCTAssertEqual(lexicon.phonemes(for: "the", tag: "DT", context: .init(futureVowel: false)), "ðə")
        XCTAssertEqual(lexicon.phonemes(for: "to", tag: "TO", context: .init(futureVowel: false)), "tə")
        XCTAssertEqual(lexicon.spell("ABC"), "ˌAbˌisˈi")
    }

    func testSentenceReadsRightToLeftWithPunctuation() {
        let phonemizer = KokoroPhonemizer(lexicon: lexicon())
        XCTAssertEqual(phonemizer.phonemize("The sky is blue."), "ðə skˈI ɪz blˈu.")
        XCTAssertEqual(phonemizer.phonemize("The apple, the cat!"), "ði ˈæpəl, ðə kˈæt!")
    }

    func testNumbersAreSpokenAsWords() {
        let text = KokoroPhonemizer.normalize("In 1984 I paid $3.50 for 2nd place, 40% of 1,200.")
        XCTAssertTrue(text.contains("nineteen eighty four"), text)
        XCTAssertTrue(text.contains("three dollars and fifty cents"), text)
        XCTAssertTrue(text.contains("second place"), text)
        XCTAssertTrue(text.contains("forty percent"), text)
        XCTAssertTrue(text.contains("one thousand two hundred"), text)
        XCTAssertEqual(KokoroPhonemizer.year(2005), "two thousand five")
        XCTAssertEqual(KokoroPhonemizer.year(1907), "nineteen oh seven")
    }

    func testUnknownWordsAreSplitOrSoundedOut() {
        XCTAssertEqual(KokoroPhonemizer.split("useEffect"), ["use", "Effect"])
        XCTAssertEqual(KokoroPhonemizer.split("snake_case-word"), ["snake", "case", "word"])
        XCTAssertEqual(KokoroLetterSounds.sound("zorb"), "zˈɔɹb")
        XCTAssertEqual(KokoroLetterSounds.sound("--"), "")
    }

    func testVocabularyAndChunkingStayInsideTheModel() {
        XCTAssertEqual(KokoroVocabulary.encode("ðə"), [81, 83])
        XCTAssertEqual(KokoroVocabulary.encode("ɡ g"), [92, 16], "ASCII g is not in Kokoro's alphabet")
        let sentence = String(repeating: "ðə kˈæt ɪz blˈu, ", count: 60) + "ðə ˈɛnd."
        let chunks = KokoroVocabulary.chunks(sentence)
        XCTAssertGreaterThan(chunks.count, 2)
        XCTAssertTrue(chunks.allSatisfy { KokoroVocabulary.encode($0).count <= 510 })
        XCTAssertLessThanOrEqual(KokoroVocabulary.encode(chunks[0]).count, 160, "the first piece is short so speech starts quickly")
        XCTAssertEqual(KokoroVocabulary.chunks("ðə ˈɛnd."), ["ðə ˈɛnd."])
    }

    func testWavHeaderIsValid() {
        let data = KokoroSpeechEngine.wav([0, 0.5, -0.5, 1], sampleRate: 24_000)
        XCTAssertEqual(data.count, 44 + 8)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
    }
}
