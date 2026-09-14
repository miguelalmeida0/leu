import Foundation
import ShelfCore

@MainActor extension LearningModel {
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
