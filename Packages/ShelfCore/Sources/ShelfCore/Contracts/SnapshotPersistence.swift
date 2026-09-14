import Foundation

public struct SnapshotLoad: Sendable {
    public var snapshot: LibrarySnapshot
    public var recoveredFromPrevious: Bool
    public init(snapshot: LibrarySnapshot, recoveredFromPrevious: Bool = false) {
        self.snapshot = snapshot
        self.recoveredFromPrevious = recoveredFromPrevious
    }
}

/// Implementations must commit atomically: an unsuccessful save must keep the old snapshot.
public protocol SnapshotPersistence: Sendable {
    func load() throws -> SnapshotLoad
    func save(_ snapshot: LibrarySnapshot) throws
}
