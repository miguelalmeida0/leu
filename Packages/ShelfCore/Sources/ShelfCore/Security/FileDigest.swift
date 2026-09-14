import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum FileDigest {
    /// Streams in 1 MB chunks. Memory usage is independent of PDF size.
    public static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        #if canImport(CryptoKit)
        var hasher = SHA256()
        #else
        var hasher = PortableSHA256()
        #endif
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            try Task.checkCancellation()
            #if canImport(CryptoKit)
            hasher.update(data: data)
            #else
            hasher.update(data)
            #endif
        }
        #if canImport(CryptoKit)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        #else
        return hasher.finalize()
        #endif
    }
}
