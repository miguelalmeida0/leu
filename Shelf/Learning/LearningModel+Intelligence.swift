import Foundation
import ShelfCore

@MainActor extension LearningModel {
    func prepareV4Questions() async {
        if let task = v4PreparationTask { await task.value; return }
        isPreparingV4Questions = true
        defer { isPreparingV4Questions = false }
        let task = Task { [weak self] in
            guard let self else { return }
            for book in library.snapshot.activeBooks {
                guard !Task.isCancelled, let analysis = snapshot.analyses[book.id] else { continue }
                let version = "\(book.id)|\(analysis.fingerprint)|\(analysis.extractionVersion ?? 0)|v4"
                guard !preparedV4Versions.contains(version) else { continue }
                if snapshot.questions.contains(where: { $0.v4?.claim.card.documentID == book.id && $0.v4?.claim.card.fingerprint == analysis.fingerprint }) {
                    preparedV4Versions.insert(version); continue
                }
                let topics = snapshot.manualDocumentTopics[book.id] ?? Set(analysis.topicScores.filter { $0.value >= 0.18 }.map(\.key))
                let questions = await Task.detached(priority: .utility) { V4StudyBank.build(analysis, topicIDs: topics) }.value
                guard !Task.isCancelled, library.snapshot.activeBooks.contains(where: { $0.id == book.id }),
                      snapshot.analyses[book.id]?.fingerprint == analysis.fingerprint else { continue }
                do {
                    if !questions.isEmpty { try await repository.storeV4Questions(questions); snapshot = try await repository.snapshot() }
                    preparedV4Versions.insert(version)
                    StudyInteractionTrace.record("v4.bank document=\(book.id) accepted=\(questions.count) backend=deterministic-v4")
                } catch { notice = "Source questions could not be saved. Your library is unchanged." }
            }
        }
        v4PreparationTask = task
        await task.value
        v4PreparationTask = nil
    }

    func prepareIntelligence(for source: LearningSource? = nil) {
        guard intelligenceTask == nil else {
            if let source { pendingIntelligenceSource = source }
            return
        }
        intelligenceTask = Task { [weak self] in
            guard let self else { return }
            defer {
                intelligenceTask = nil
                if let pending = pendingIntelligenceSource {
                    pendingIntelligenceSource = nil
                    prepareIntelligence(for: pending)
                }
            }
            await prepareV4Questions()
            modelAvailability = await intelligenceProvider.availability()
            modelState = modelAvailability
            intelligenceCapability = IntelligenceCapabilityReport(availability: modelAvailability)
            lastModelError = nil
            let cache = LearningIntelligenceCache(root: recordingsDirectory.deletingLastPathComponent())
            let analyses = library.snapshot.activeBooks.sorted {
                ($0.lastOpenedAt ?? $0.importedAt) > ($1.lastOpenedAt ?? $1.importedAt)
            }.compactMap { self.snapshot.analyses[$0.id] }
            let packets = analyses.flatMap { analysis in
                analysis.pages.compactMap { LearningSourcePacket(analysis: analysis, page: $0) }
            }.filter { packet in
                source.map { packet.documentID == $0.documentID && packet.pageIndex == $0.pageIndex } ?? true
            }
            var generatedThisRun = 0
            for packet in packets {
                if snapshot.questions.contains(where: { $0.v4 != nil && $0.source.documentID == packet.documentID && $0.source.pageIndex == packet.pageIndex }) { continue }
                guard !Task.isCancelled, generatedThisRun < 3 else { return }
                guard ProcessInfo.processInfo.thermalState != .serious,
                      ProcessInfo.processInfo.thermalState != .critical,
                      !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
                let preflight = QuestionV3Contract().compile(packet)
                guard preflight.status == .representable else {
                    lastModelError = "noRepresentableQuestion: " + preflight.status.rawValue
                    StudyInteractionTrace.record("model.preflight noRepresentableQuestion document=\(packet.documentID) page=\(packet.pageIndex) claims=\(preflight.meaningfulClaims.count) inferenceCalled=false")
                    continue
                }
                if let cached = await cache.load(packet.cacheKey) { recordGeneration(cached); continue }
                guard let analysis = snapshot.analyses[packet.documentID] else { continue }
                if modelAvailability != .available {
                    // Same source and surface admission, explicitly deterministic.
                    // No inference counter, model progress, or Apple provenance.
                    await storeDeterministicQuestions(preflight, packet: packet, analysis: analysis)
                    continue
                }
                do {
                    modelState = .loading
                    let start = Date()
                    lastModelPacket = packet
                    modelInferenceAttempts += 1
                    StudyInteractionTrace.record("model.attempt backend=\(intelligenceProvider.backend) document=\(packet.documentID) page=\(packet.pageIndex) extraction=\(packet.extractionVersion) cacheKey=\(packet.cacheKey)")
                    let candidate = try await intelligenceProvider.generateQuestion(from: packet)
                    intelligenceCapability = IntelligenceCapabilityReport(availability: .available, generationVerified: true)
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    try Task.checkCancellation()
                    generatedThisRun += 1; modelGenerated += 1
                    lastModelGeneration = Date()
                    var record = LearningGenerationRecord(cacheKey: packet.cacheKey, backend: intelligenceProvider.backend,
                        timestamp: Date(), candidate: candidate, acceptedQuestionID: nil, rejection: nil,
                        inferenceMilliseconds: elapsed, sourcePacket: packet, validatedQuestion: nil)
                    recordGeneration(record)
                    let result = LearningCandidateValidator().validate(candidate, packet: packet,
                        analysis: analysis, existing: snapshot.questions)
                    switch result {
                    case .success(let question):
                        record.validatedQuestion = question
                        modelAccepted += 1
                        recordGeneration(record)
                        try await repository.storeModelQuestion(question)
                        snapshot = try await repository.snapshot()
                        record.acceptedQuestionID = question.id
                    case .failure(let rejection):
                        record.rejection = rejection.rawValue
                        modelRejections[rejection.rawValue, default: 0] += 1
                    }
                    recordGeneration(record)
                    try await cache.save(record)
                    modelState = .available
                    StudyInteractionTrace.record("model.inference backend=\(intelligenceProvider.backend) generated=1 accepted=\(record.validatedQuestion != nil) persisted=\(record.acceptedQuestionID != nil) rejection=\(record.rejection ?? "none") milliseconds=\(elapsed)")
                } catch is CancellationError { modelState = .cancelled; return }
                catch LearningIntelligenceError.timedOut {
                    modelState = .timedOut
                    intelligenceCapability = IntelligenceCapabilityReport(availability: modelAvailability, error: LearningIntelligenceError.timedOut)
                    await storeDeterministicQuestions(preflight, packet: packet, analysis: analysis)
                    return
                }
                catch {
                    modelState = .failed
                    intelligenceCapability = IntelligenceCapabilityReport(availability: modelAvailability, error: error)
                    lastModelError = String(describing: error)
                    StudyInteractionTrace.record("model.failed backend=\(intelligenceProvider.backend) error=\(error)")
                    await storeDeterministicQuestions(preflight, packet: packet, analysis: analysis)
                    return
                }
            }
        }
    }

    private func storeDeterministicQuestions(_ preflight: QuestionRepresentability, packet: LearningSourcePacket,
                                              analysis: DocumentAnalysis) async {
        for candidate in preflight.questions.prefix(3) {
            guard !Task.isCancelled else { return }
            if let question = try? LearningCandidateValidator().validate(candidate, packet: packet,
                analysis: analysis, existing: snapshot.questions, backend: "deterministic-v3").get() {
                do { try await repository.storeModelQuestion(question); snapshot = try await repository.snapshot() }
                catch { lastModelError = "Could not save the source question: \(error)" }
            }
        }
    }

    private func recordGeneration(_ record: LearningGenerationRecord) {
        modelGenerations.removeAll { $0.cacheKey == record.cacheKey }
        modelGenerations.append(record)
        modelGenerations = Array(modelGenerations.suffix(20))
    }
}
