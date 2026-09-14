import SwiftUI

@MainActor
struct PrivacySheet: View {
    var body: some View {
        ShelfSheet(title: "Your library belongs to you") {
            List {
                Section("On this iPhone") {
                    Text("Leu stores its own copies of your PDFs in its private app storage. Originals are kept separately from notes and highlights.")
                    Text("Reading, local PDF analysis, deterministic study questions, scheduling, search, organization and annotations do not require an internet connection. Importing from a cloud file provider can require that provider to download a file first.")
                }
                Section("Nothing sent by Leu") {
                    Text("No analytics, ads, model calls, account system or app-owned servers are included. Leu requests microphone access only when you explicitly record a self-explanation. Recordings stay in Leu on this iPhone unless you export them yourself.")
                }
                Section("Exports and backups") {
                    Text("Sharing or saving an export sends the selected file to the app or location you choose. Leu library backups are portable but not separately encrypted. Learning sessions, memory state and explanation recordings are not yet included in Leu's custom backup file.")
                    Text("iOS device backups may include Leu's app data, depending on your system settings. Leu does not promise its own cloud sync or end-to-end encryption service.")
                }
                Section("Keep a recovery copy") {
                    Text("Deleting Leu can delete its local library and learning history. Export a library backup before uninstalling, and rely on an appropriate iOS device backup if you also need to preserve Learning OS state in this release. Re-signing with the same identity is not a substitute for a recovery copy.")
                }
            }
        }
    }
}
