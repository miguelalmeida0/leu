import SwiftUI

/// Semantic tokens used by the learning layer. Keep study UI expressive without
/// scattering magic numbers or turning Shelf into a dashboard.
enum LearningTokens {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 30
        static let xxl: CGFloat = 40
    }

    enum Corner {
        static let compact: CGFloat = 10
        static let control: CGFloat = 9
        static let surface: CGFloat = 10
        static let hero: CGFloat = 12
    }


    enum Typography {
        // Felt: Gabarito for the headings people scan, scaled with Dynamic Type.
        static let hero = Font.leu(.largeTitle, weight: .heavy)
        static let title = Font.leu(.title, weight: .heavy)
        static let section = Font.leu(.title2, weight: .bold)
        static let compactTitle = Font.leu(.title3, weight: .bold)
    }

    enum Motion {
        static let press = Animation.spring(response: 0.18, dampingFraction: 0.86)
        static let selection = Animation.spring(response: 0.28, dampingFraction: 0.88)
        static let reveal = Animation.easeOut(duration: 0.22)
    }

    static let success = ShelfTheme.reviewAccent
    static let difficulty = ShelfTheme.importantAccent
    static let warning = ShelfTheme.danger
}
