import Foundation
import ShelfCore

/// One idea from the page that Leu is listening for, and how far the reader has got it across.
struct TeachIdea: Identifiable, Equatable {
    enum State: Equatable { case listening, across, loose }
    let id: String
    let label: String
    let state: State

    var status: String {
        switch state {
        case .listening: "listening"
        case .across: "got across"
        case .loose: "still a loose end"
        }
    }
}

/// How the reader's explanation lights the snow globe. Pure, so it is tested directly.
enum TeachGlobeProgress {
    /// The ideas on this page, in reading order, each marked once a comparison has run.
    static func ideas(claims: [GroundedQuestionClaim], result: TeachLeuResult?) -> [TeachIdea] {
        let captured = Set(result?.supported.map(\.claimID) ?? [])
        return claims.map { claim in
            let state: TeachIdea.State = result == nil ? .listening : captured.contains(claim.id) ? .across : .loose
            return TeachIdea(id: claim.id, label: label(for: claim), state: state)
        }
    }

    /// Three windows share the page's ideas. Getting any idea across lights at least one;
    /// only getting every idea across lights the last.
    static func windows(captured: Int, of total: Int) -> Int {
        guard total > 0, captured > 0 else { return 0 }
        if captured >= total { return 3 }
        return min(2, max(1, 3 * captured / total))
    }

    static func windows(claims: [GroundedQuestionClaim], result: TeachLeuResult?) -> Int {
        let ideas = ideas(claims: claims, result: result)
        return windows(captured: ideas.filter { $0.state == .across }.count, of: ideas.count)
    }

    /// The small heading over Leu's reply.
    static func heading(windows: Int) -> String {
        switch windows {
        case 0: "No windows lit yet"
        case 1: "One window lit"
        case 2: "Two windows lit"
        default: "Every window lit"
        }
    }

    /// What Leu is listening for, in one plain sentence.
    static func listening(ideaCount: Int, page: Int) -> String {
        let ideas = ideaWord(ideaCount).capitalizedFirst
        switch ideaCount {
        case 0: "Page \(page) has no idea Leu can check yet. Your words are still kept."
        case 1: "One idea from page \(page). Get it across and the whole cottage lights up."
        case 3: "Three ideas from page \(page). Each one you get across lights a window."
        default: "\(ideas) from page \(page). Get them all across and every window is lit."
        }
    }

    /// "one idea", "three ideas", "12 ideas".
    static func ideaWord(_ count: Int) -> String {
        let names = ["no", "one", "two", "three", "four", "five", "six"]
        let number = count < names.count ? names[count] : "\(count)"
        return number + (count == 1 ? " idea" : " ideas")
    }

    /// A short label for an idea: the claim in the source's own words, without its qualifier.
    static func label(for claim: GroundedQuestionClaim) -> String {
        let phrase = [claim.concept, claim.predicate, claim.object]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return phrase.isEmpty ? claim.evidence.text : phrase
    }
}

private extension String {
    var capitalizedFirst: String { self.prefix(1).uppercased() + self.dropFirst() }
}
