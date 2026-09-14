import Foundation
import Observation
import ShelfCore

struct KnowledgeDestination: Equatable {
    var documentID: UUID
    var pageIndex: Int
    var sourceText: String
    var restoreLens: LearningSource? = nil
}

/// Observable projection over the local connected-library repository.
/// Persistence, ranking, search and navigation are split into focused extensions.
@MainActor @Observable
final class KnowledgeModel {
    let repository: KnowledgeRepository
    let learning: LearningModel
    let library: LibraryModel
    private let pipeline = KnowledgePipeline()
    let ranker = ConnectionRanker()
    let searchEngine = KnowledgeSearchEngine()

    var snapshot = KnowledgeSnapshot()
    var isReady = false
    var isIndexing = false
    var progress: Double = 0
    var status: String?
    var errorMessage: String?
    var searchText = ""
    var searchResult = KnowledgeSearchResult()
    var pendingDestination: KnowledgeDestination?
    var backStack: [KnowledgeDestination] = []
    @ObservationIgnored var indexingTask: Task<Void, Never>?

    init(repository: KnowledgeRepository, learning: LearningModel, library: LibraryModel) {
        self.repository = repository
        self.learning = learning
        self.library = library
    }

    func bootstrap() async {
        guard !isReady else { return }
        do {
            snapshot = try await repository.open()
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await syncLibrary()
    }

    func syncLibrary() async {
        indexingTask?.cancel()
        indexingTask = Task { [weak self] in
            guard let self else { return }
            await learning.bootstrap()
            do { snapshot = try await repository.snapshot() }
            catch { errorMessage = error.localizedDescription; return }

            let activeBooks = library.snapshot.activeBooks
            let activeIDs = Set(activeBooks.map(\.id))
            for indexed in snapshot.importStates.keys where !activeIDs.contains(indexed) {
                try? await repository.markDocumentUnavailable(indexed)
            }

            let analyses = learning.snapshot.analyses.values
                .filter { activeIDs.contains($0.documentID) }
                .sorted { lhs, rhs in
                    let left = activeBooks.first(where: { $0.id == lhs.documentID })?.lastOpenedAt ?? .distantPast
                    let right = activeBooks.first(where: { $0.id == rhs.documentID })?.lastOpenedAt ?? .distantPast
                    return left > right
                }
            var pending: [DocumentAnalysis] = []
            for analysis in analyses where (try? await repository.needsIndex(
                documentID: analysis.documentID, fingerprint: analysis.fingerprint
            )) == true {
                pending.append(analysis)
            }
            guard !pending.isEmpty else {
                snapshot = (try? await repository.snapshot()) ?? snapshot
                refreshSearchIfNeeded()
                return
            }

            isIndexing = true
            progress = 0
            defer { isIndexing = false; status = nil }
            for (offset, analysis) in pending.enumerated() {
                guard !Task.isCancelled else { return }
                let title = activeBooks.first(where: { $0.id == analysis.documentID })?.title ?? "book"
                status = "Connecting \(title) to your library…"
                let seed = (try? await repository.snapshot()) ?? snapshot
                let pipeline = self.pipeline
                let bundle = await Task.detached(priority: .utility) {
                    pipeline.index(analysis: analysis, concepts: seed.concepts, aliases: seed.aliases)
                }.value
                do {
                    try await repository.replaceDocumentIndex(bundle)
                    snapshot = try await repository.snapshot()
                    refreshSearchIfNeeded()
                } catch {
                    errorMessage = error.localizedDescription
                }
                progress = Double(offset + 1) / Double(max(1, pending.count))
                await Task.yield()
            }
            if !Task.isCancelled { ShelfHaptics.shared.play(.objectConnected) }
        }
        await indexingTask?.value
    }

    private func refreshSearchIfNeeded() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        search()
    }

    func passage(for source: LearningSource) -> KnowledgePassage? {
        let candidates = snapshot.passages.filter {
            $0.documentID == source.documentID && $0.pageIndex == source.pageIndex && $0.isAvailable
        }
        guard !candidates.isEmpty else { return nil }
        let quote = canonical(source.sourceText)
        if let exact = candidates.first(where: {
            canonical($0.text).contains(quote) || quote.contains(canonical($0.text))
        }) { return exact }
        let tokenizer = TechnicalTokenizer()
        let sourceTerms = Set(tokenizer.tokens(in: source.sourceText))
        return candidates.max {
            overlap($0, sourceTerms, tokenizer) < overlap($1, sourceTerms, tokenizer)
        }
    }

    private func canonical(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    private func overlap(_ passage: KnowledgePassage, _ sourceTerms: Set<String>,
                         _ tokenizer: TechnicalTokenizer) -> Int {
        sourceTerms.intersection(Set(tokenizer.tokens(in: passage.text))).count
    }
}
