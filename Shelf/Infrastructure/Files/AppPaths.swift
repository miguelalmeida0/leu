import Foundation

struct AppPaths: Sendable {
    let root: URL
    let temporary: URL
    init(isUITesting: Bool = false) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        root = support.appendingPathComponent(isUITesting ? "Shelf-UITests" : "Shelf", isDirectory: true)
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("Shelf", isDirectory: true)
    }
    func prepare() throws {
        for directory in [root, temporary] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }
    }
    /// Only disposable exports older than one day are removed. Never touches library originals.
    func clearOldTemporaryFiles(now: Date = Date()) {
        let children = (try? FileManager.default.contentsOfDirectory(at: temporary,
            includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for child in children {
            guard let date = try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  now.timeIntervalSince(date) > 86_400 else { continue }
            try? FileManager.default.removeItem(at: child)
        }
    }
}
