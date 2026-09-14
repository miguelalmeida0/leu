import Foundation

public enum ContentsLocation {
    /// Stable document order breaks ties at the same page in favor of the deepest
    /// following entry. No explicit selection can outlive natural reading progress.
    public static func activeEntryID(entries: [(id: String, page: Int)], pageIndex: Int) -> String? {
        entries.enumerated().filter { $0.element.page <= pageIndex }.max {
            $0.element.page == $1.element.page ? $0.offset < $1.offset : $0.element.page < $1.element.page
        }?.element.id ?? entries.first?.id
    }
}
