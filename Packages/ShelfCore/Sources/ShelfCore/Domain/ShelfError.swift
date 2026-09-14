import Foundation

public enum ShelfError: LocalizedError, Equatable {
    case notFound
    case emptyTitle
    case duplicateCollection
    case invalidPDF(String)
    case tooLarge
    case corruptLibrary(String)
    case unsupportedVersion(Int)
    case invalidBackup(String)
    case missingOriginal(String)
    case invalidAnnotation
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notFound: return "This item is no longer in the library."
        case .emptyTitle: return "Please enter a name."
        case .duplicateCollection: return "A collection with that name already exists."
        case .invalidPDF(let reason): return "This PDF could not be imported. " + reason
        case .tooLarge: return "This file exceeds Shelf's 1 GB per-document safety limit."
        case .corruptLibrary(let reason):
            return "Shelf could not safely open its library. Your PDFs were not deleted. " + reason
        case .unsupportedVersion(let version):
            return "This library uses format \(version). Open it with a newer version of Shelf."
        case .invalidBackup(let reason): return "This backup cannot be restored. " + reason
        case .missingOriginal(let title): return "The original PDF is missing: " + title
        case .invalidAnnotation: return "That annotation does not belong to a valid PDF page."
        case .cancelled: return "The operation was cancelled."
        }
    }
}
