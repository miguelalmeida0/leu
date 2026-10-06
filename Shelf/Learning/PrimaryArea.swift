import Foundation

/// Leu's one persistent navigation level.
///
/// Home is the reading corner you arrive in. Reading is not an area: it opens the book you
/// were in the middle of, so the navigation never strands you on an empty reader.
enum PrimaryArea: String, CaseIterable, Identifiable {
    case home, shelf, learn, trails
    var id: Self { self }
    var title: String {
        switch self {
        case .home: return "Home"
        case .shelf: return "Library"
        case .learn: return "Study"
        case .trails: return "Trails"
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .shelf: return "books.vertical"
        case .learn: return "graduationcap"
        case .trails: return "point.3.connected.trianglepath.dotted"
        }
    }
}
