import Foundation

public enum LabCatalog {
    public static var defaultLab: ReconstructionLab { eventLoop() }

    public static func all() -> [ReconstructionLab] {
        [defaultLab, reactIdentity(), httpCaching(), structuralTyping(), databaseTransaction()]
    }

    private static func lab(_ kind: ReconstructionLabKind, _ title: String, _ instruction: String,
                            _ titles: [String], setup: [String], prompt: String,
                            choices: [String], correctIndex: Int, explanation: String) -> ReconstructionLab {
        let elements = titles.enumerated().map { index, title in
            LabElement(id: StableIdentity.uuid("lab|\(kind.rawValue)|element|\(index)|\(title)"), title: title)
        }
        let options = choices.enumerated().map { index, text in
            LabChoice(id: StableIdentity.uuid("lab|\(kind.rawValue)|choice|\(index)|\(text)"), text: text)
        }
        let safeIndex = min(max(0, correctIndex), max(0, options.count - 1))
        let scenario = LabScenario(setup: setup, prompt: prompt, choices: options,
                                   correctChoiceID: options[safeIndex].id, explanation: explanation)
        return ReconstructionLab(id: StableIdentity.uuid("lab|" + kind.rawValue), kind: kind, title: title,
                                 instruction: instruction, elements: elements,
                                 correctOrder: elements.map(\.id), scenario: scenario)
    }

    private static func eventLoop() -> ReconstructionLab {
        lab(.eventLoop, "JavaScript Event Loop", "Reconstruct the runtime path, then predict a concrete execution order.",
            ["Call Stack", "Web APIs", "Microtask Queue", "Task Queue", "Event Loop"],
            setup: ["console.log('A')", "Promise.resolve().then(() => console.log('B'))", "setTimeout(() => console.log('C'), 0)"],
            prompt: "After the synchronous script finishes, which output order is correct?",
            choices: ["A → B → C", "A → C → B", "B → A → C"], correctIndex: 0,
            explanation: "A runs synchronously. The Promise continuation enters the microtask queue, which is drained before the next timer task, so B precedes C.")
    }

    private static func reactIdentity() -> ReconstructionLab {
        lab(.reactIdentity, "React Identity / Keys", "Reconstruct the identity clues React uses, then predict what survives a reorder.",
            ["Element type", "Key", "Position among siblings", "Preserved instance"],
            setup: ["Before: [A:key='a', B:key='b', C:key='c']", "After:  [C:key='c', A:key='a', B:key='b']", "A currently owns local state = 7"],
            prompt: "After the keyed reorder, which item keeps the local state value 7?",
            choices: ["A", "C", "Whichever item remains in the first position"], correctIndex: 0,
            explanation: "Stable keys let React match A with the same component identity even though its sibling position changed.")
    }

    private static func httpCaching() -> ReconstructionLab {
        lab(.httpCaching, "HTTP Caching", "Reconstruct the cache decision path, then choose the browser's next action.",
            ["Freshness check", "Use cached response", "Revalidate", "Fetch new response"],
            setup: ["Cache-Control: max-age=60", "Cached response age: 90 seconds", "ETag: \"v7\" is available"],
            prompt: "What should the browser do before using the stale representation?",
            choices: ["Use it without contacting the server", "Revalidate with the validator", "Delete all browser cache data"], correctIndex: 1,
            explanation: "The representation is stale, but the ETag provides a validator, so the browser can revalidate rather than blindly reuse or discard the cache.")
    }

    private static func structuralTyping() -> ReconstructionLab {
        lab(.structuralTyping, "TypeScript Structural Typing", "Reconstruct assignability, then judge a concrete pair of shapes.",
            ["Required properties", "Source shape", "Property compatibility", "Assignment valid"],
            setup: ["Target: { id: number }", "Source: { id: number; name: string }", "Assignment: const target: Target = source"],
            prompt: "Is this assignment structurally valid?",
            choices: ["Yes — the source satisfies the required member", "No — the source has an extra property", "Only if both types share a class name"], correctIndex: 0,
            explanation: "Structural assignability asks whether the source supplies compatible required members. An existing source value may have additional members.")
    }

    private static func databaseTransaction() -> ReconstructionLab {
        lab(.databaseTransaction, "Database Transaction", "Reconstruct the transaction boundary, then predict failure behavior.",
            ["Begin", "Read / write", "Validate constraints", "Commit or rollback"],
            setup: ["Begin transfer", "Debit account A succeeds", "Credit account B violates a required constraint", "No commit has occurred"],
            prompt: "What outcome preserves the transaction's atomic boundary?",
            choices: ["Keep the debit and skip the credit", "Rollback the transaction", "Commit first, repair later"], correctIndex: 1,
            explanation: "Because the unit has not committed and a required operation failed, rollback prevents a partial transfer from becoming durable.")
    }
}
