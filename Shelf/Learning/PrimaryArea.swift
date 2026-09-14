import Foundation

enum PrimaryArea: String, CaseIterable, Identifiable {
    case shelf, learn, trails
    var id: Self { self }
    var title: String {
        switch self {
        case .shelf: return "Library"
        case .learn: return "Study"
        case .trails: return "Trails"
        }
    }
    var symbol: String {
        switch self {
        case .shelf: return "books.vertical"
        case .learn: return "graduationcap"
        case .trails: return "point.3.connected.trianglepath.dotted"
        }
    }
}
