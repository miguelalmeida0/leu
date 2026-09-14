import Foundation

/// On a Debug launch, opening a real library PDF opens the explanation sheet.
/// There is no synthetic source or test provider in this path.
enum ExplainLikeTenHarness {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--explain-like-ten-harness")
        #else
        false
        #endif
    }
}
