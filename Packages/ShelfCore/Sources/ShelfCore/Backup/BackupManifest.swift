import Foundation

struct BackupManifest: Codable {
    var version = 1
    var exportedAt = Date()
    var library: LibrarySnapshot
    var originals: [BackupFile]
}
struct BackupFile: Codable {
    var id: UUID
    var size: Int64
    var fingerprint: String
}

enum BackupFormat {
    static let magic = Data("SHELF-BACKUP\n1\n".utf8)
    static let manifestLimit = 32 * 1_024 * 1_024
    static let chunkSize = 1_048_576

    static func encodeLength(_ number: UInt64) -> Data {
        Data((0..<8).map { UInt8(truncatingIfNeeded: number >> ($0 * 8)) })
    }
    static func decodeLength(_ data: Data) -> UInt64 {
        data.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << ($1.offset * 8) }
    }
    static func readExactly(_ handle: FileHandle, count: Int) throws -> Data {
        var data = Data()
        while data.count < count {
            guard let part = try handle.read(upToCount: count - data.count), !part.isEmpty else {
                throw ShelfError.invalidBackup("The file is incomplete.")
            }
            data.append(part)
        }
        return data
    }
}
