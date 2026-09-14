import Foundation
import ShelfCore

@MainActor
final class PronunciationPreferenceStore {
    private let defaults: UserDefaults
    private let key = "voice.pronunciationOverrides"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func dictionary() -> PronunciationDictionary {
        PronunciationDictionary(userEntries: entries())
    }

    func entries() -> [PronunciationEntry] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([PronunciationEntry].self, from: data) else { return [] }
        return values
    }

    func save(display: String, spoken: String) {
        let cleanDisplay = display.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanDisplay.count >= 2, cleanSpoken.count >= 1 else { return }
        var values = entries()
        values.removeAll { $0.display.compare(cleanDisplay, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        values.append(PronunciationEntry(display: cleanDisplay, spoken: cleanSpoken, origin: .user))
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: key) }
    }

    func remove(_ entry: PronunciationEntry) {
        let values = entries().filter { $0.id != entry.id }
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: key) }
    }
}
