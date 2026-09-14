import XCTest
@preconcurrency import AVFoundation
@testable import Shelf

final class VoiceCatalogTests: XCTestCase {
    func testEnglishVoicesAreRankedByInstalledQuality() throws {
        let voices = VoiceCatalog().voices()
        guard !voices.isEmpty else { throw XCTSkip("No English AVSpeechSynthesisVoice assets are exposed by this simulator runtime.") }
        for pair in zip(voices, voices.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.0.quality.rawValue, pair.1.quality.rawValue)
        }
    }

    func testExplicitInstalledVoiceIdentifierWins() throws {
        guard let descriptor = VoiceCatalog().voices().last else { throw XCTSkip("No English voices installed.") }
        let selected = VoiceCatalog().bestVoice(identifier: descriptor.id)
        XCTAssertEqual(selected?.identifier, descriptor.id)
    }
}
