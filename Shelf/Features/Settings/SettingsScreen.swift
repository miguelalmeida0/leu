import SwiftUI
import ShelfCore

@MainActor
struct SettingsScreen: View {
    @Bindable var model: LibraryModel
    @Bindable var preferences: AppPreferences
    @Bindable var knowledge: KnowledgeModel
    @Bindable var learning: LearningModel
    @State private var showTrash = false
    @State private var removeSamples = false
    @State private var showPrivacy = false
    @State private var voiceInstallProgress: Double = 0
    @State private var voiceInstallError: String?
    @State private var voiceInstalling = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Leu").leuScaledFont(38, weight: .regular, design: .serif)
                        Text("Library, reader, backup and local data controls.").foregroundStyle(ShelfTheme.secondary)
                    }.padding(.vertical, 8).listRowBackground(Color.clear)
                }
                Section("Your library") {
                    Toggle("List instead of bookshelf", isOn: $preferences.compactLibrary)
                    Toggle("Use PDF first pages as covers", isOn: $preferences.usePDFCovers)
                    Button("Manage collections") { model.showCollections = true }
                    LabeledContent("Stored on this iPhone", value: ByteCountFormatter.string(fromByteCount: model.totalBytes, countStyle: .file))
                }
                Section {
                    Picker("Page movement", selection: $preferences.pageFlow) {
                        Text("Vertical scroll").tag(PageFlow.vertical)
                        Text("Horizontal pages").tag(PageFlow.horizontal)
                    }
                    Picker("Page surround", selection: $preferences.readerSurround) {
                        ForEach(ReaderSurround.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    HStack(spacing: 12) {
                        Text("Keep screen awake while reading")
                        Spacer(minLength: 12)
                        ShelfSwitch(
                            isOn: $preferences.keepAwake,
                            identifier: "settings-global-keep-awake",
                            label: "Keep screen awake while reading"
                        )
                        .fixedSize()
                    }
                    Toggle("Occasional active-recall pause", isOn: $preferences.blindPagePromptsEnabled)
                    Toggle("Leu haptics", isOn: $preferences.hapticsEnabled)
                    if preferences.hapticsEnabled {
                        HStack {
                            Text("Haptic intensity")
                            Slider(value: $preferences.hapticIntensity, in: 0.1...1.0)
                        }
                    }
                } header: { Text("Reading") } footer: {
                    Text("Page surrounds change the space around the PDF. Original page colors, fonts, code and diagrams are preserved.")
                }
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Connected library")
                            Text(knowledge.isIndexing ? (knowledge.status ?? "Connecting your books…") : "Passages, connections and trails stay on this iPhone.")
                                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                        }
                        Spacer()
                        if knowledge.isIndexing { ProgressView().controlSize(.small) }
                    }
                    Button("Rebuild connection index") { Task { await knowledge.rebuildDerivedIndex() } }
                        .disabled(knowledge.isIndexing)
                        .accessibilityIdentifier("rebuild-knowledge-index")
                } header: { Text("Connected library") } footer: {
                    Text("Rebuilding removes only derived search/ranking data. Your confirmed links and saved trails are preserved and re-anchored whenever possible.")
                }
                Section {
                    Button { Task { await model.exportBackup() } } label: { Label("Export library & reading backup", systemImage: "square.and.arrow.up") }
                        .disabled(model.busy).accessibilityIdentifier("export-backup")
                    Button { model.showBackupImporter = true } label: { Label("Restore a Leu backup", systemImage: "arrow.counterclockwise") }
                        .disabled(model.busy)
                    if let label = model.operationLabel { HStack { ProgressView(); Text(label).font(.callout) } }
                } header: { Text("Backup & ownership") } footer: {
                    Text("Leu backup files contain PDFs, collections, reading positions, bookmarks and notes, including Trash. Learning sessions, connected-library knowledge, memory state and explanation recordings remain in local app data in this release and are not yet included in this export. Backups are not encrypted.")
                }
                Section("Housekeeping") {
                    Button { showTrash = true } label: { LabeledContent("Trash", value: String(model.trashedBooks.count)) }
                    Button("Remove bundled sample PDFs") { removeSamples = true }
                        .disabled(model.busy || !model.snapshot.activeBooks.contains(where: { $0.isSample }))
                }
                Section {
                    LabeledContent("Reading voice", value: SupertonicAssets.isInstalled ? "Leu Neural · Supertonic 3" : "Apple fallback")
                        .accessibilityIdentifier("settings-voice-status")
                    if voiceInstalling { ProgressView(value: voiceInstallProgress) }
                    Button(SupertonicAssets.isInstalled ? "Neural voice installed" : "Install neural voice (~400 MB)") {
                        installNeuralVoice()
                    }
                    .disabled(voiceInstalling || SupertonicAssets.isInstalled)
                    .accessibilityIdentifier("settings-install-voice")
                    if let voiceInstallError {
                        Text(voiceInstallError).font(.caption).foregroundStyle(ShelfTheme.danger)
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("The neural voice is downloaded once from the pinned open-weight Supertonic 3 archive and then runs locally with ONNX Runtime. Reading falls back to Apple speech if the model is not installed.")
                }
                Section("Emotional check-ins") {
                    Picker("Check-ins", selection: Binding(
                        get: { learning.snapshot.emotionalCheckInPreference },
                        set: { value in Task { await learning.setEmotionalCheckInPreference(value) } }
                    )) {
                        Text("On").tag(EmotionalCheckInPreference.on)
                        Text("Reduced").tag(EmotionalCheckInPreference.reduced)
                        Text("Off").tag(EmotionalCheckInPreference.off)
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("settings-check-ins")
                    Button("Delete emotional check-in history", role: .destructive) {
                        Task { await learning.deleteEmotionalCheckIns() }
                    }
                    .disabled(learning.snapshot.emotionalCheckIns.isEmpty)
                    .accessibilityIdentifier("settings-delete-check-ins")
                }
                Section {
                    Button("Privacy & data ownership") { showPrivacy = true }
                    LabeledContent("Version", value: "24.5 · Semantic & Emotional Learning")
                    Text("No account. No ads. No subscription. No generative AI. Learning and reading data stay local unless you export a file yourself.")
                        .font(.footnote).foregroundStyle(ShelfTheme.secondary)
                }
            }.scrollContentBackground(.hidden).background(ShelfTheme.background)
                .background { UITestFrameProbe(identifier: "settings-form-frame") }
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Library") { model.selectedTab = .library }
                    }
                }
                .sheet(isPresented: $showTrash) { TrashSheet(model: model) }
                .sheet(isPresented: $showPrivacy) { PrivacySheet() }
                .leuDialog("Move the bundled samples to Trash?", isPresented: $removeSamples, titleVisibility: .visible) {
                    Button("Remove sample PDFs", role: .destructive) { Task { await model.removeSamples() } }
                } message: { Text("Your imported documents will not be changed.") }
        }
    }

    private func installNeuralVoice() {
        voiceInstalling = true; voiceInstallError = nil; voiceInstallProgress = 0
        Task {
            do {
                try await SupertonicAssets.install { value in
                    Task { @MainActor in voiceInstallProgress = value }
                }
            } catch { voiceInstallError = error.localizedDescription }
            voiceInstalling = false
        }
    }

}
