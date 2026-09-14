import Foundation

@MainActor
struct VoicePreferenceStore {
    private let preferences: AppPreferences
    init(preferences: AppPreferences) { self.preferences = preferences }

    var voiceIdentifier: String? {
        get { preferences.speechVoiceIdentifier }
        nonmutating set { preferences.speechVoiceIdentifier = newValue }
    }

    var speed: Double {
        get { preferences.speechSpeed }
        nonmutating set { preferences.speechSpeed = min(max(newValue, 0.8), 2.0) }
    }
    var voiceWasChosen: Bool {
        get { preferences.speechVoiceWasChosen }
        nonmutating set { preferences.speechVoiceWasChosen = newValue }
    }
}
