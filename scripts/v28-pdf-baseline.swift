import Foundation
import PDFKit
import AppKit
@testable import ShelfCore

/// Calls the production extractor. This is host PDF evidence, never iOS/model evidence.
@main struct V28PDFBaselineReplay {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("docs/v28/docs/internal/evidence/baseline")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let names = ["React Notes", "System Design", "JavaScript Deep Dive"]
        var urls = names.map { root.appendingPathComponent("Shelf/Resources/Samples/\($0).pdf") }
        if let path = ProcessInfo.processInfo.environment["LEU_MOBILE_MASTERY_PDF"] {
            let url = URL(fileURLWithPath: path)
            guard url.lastPathComponent == "javascript_midlevel_interview_mobile_mastery.pdf" else {
                throw NSError(domain: "V27", code: 1, userInfo: [NSLocalizedDescriptionKey: "mobile_mastery is required; no substitute"])
            }
            urls.append(url)
        }
        var analyses: [UUID: DocumentAnalysis] = [:], sources: [IntelligenceSource] = [], total = 0
        var report: [[String: Any]] = []
        for url in urls {
            let id = StableIdentity.uuid(url.lastPathComponent), bytes = try Data(contentsOf: url)
            let fingerprint = String(StableIdentity.hash64(bytes.base64EncodedString()))
            let extraction = try await PDFKitTextExtractor().extract(documentID: id, fingerprint: fingerprint, url: url) { _ in }
            var analysis = DocumentAnalyzer().analyze(documentID: id, fingerprint: fingerprint, pages: extraction.pages)
            analysis.extractionVersion = SourceExtractionVersion.current
            for i in analysis.pages.indices { analysis.pages[i].canonicalText = extraction.canonicalPages[analysis.pages[i].pageIndex] }
            analyses[id] = analysis
            try encoder.encode(analysis).write(to: output.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-analysis.json"))
            let pdf = PDFDocument(url: url)!
            for page in analysis.pages {
                guard let packet = LearningSourcePacket(analysis: analysis, page: page) else { continue }
                let old = GroundedQuestionCompiler().compile(packet), current = QuestionV3Contract().compile(packet)
                var accepted: [LearningQuestion] = [], failures: [String] = []
                for candidate in current.questions {
                    switch LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis, existing: accepted, backend: "deterministic-v3") {
                    case .success(let question):
                        accepted.append(question)
                        let range = question.source.range!
                        precondition(pdf.page(at: page.pageIndex)!.selection(for: NSRange(location: range.location, length: range.length))?.string == question.source.sourceText)
                    case .failure(let reason): failures.append(reason.rawValue)
                    }
                }
                total += accepted.count
                let prefix = url.deletingPathExtension().lastPathComponent + "-p\(page.pageIndex + 1)"
                try encoder.encode(current).write(to: output.appendingPathComponent(prefix + "-proposals.json"))
                try encoder.encode(accepted).write(to: output.appendingPathComponent(prefix + "-accepted.json"))
                var activity: String = "none", teach: Any = NSNull()
                if let citation = IntelligenceSource(source: LearningSource(documentID: id, pageIndex: page.pageIndex, sourceText: packet.sourceText), analysis: analysis) {
                    sources.append(citation)
                    activity = ActivityValidator.definition(for: citation)?.contract.rawValue ?? "none"
                    if url.lastPathComponent == "React Notes.pdf" && page.pageIndex == 2 {
                        let result = TeachLeuValidator.evaluate("Keys tell React which item is which when a list changes.", source: citation)
                        teach = try JSONSerialization.jsonObject(with: encoder.encode(result))
                        precondition(!result.supported.isEmpty && !result.omitted.isEmpty)
                        precondition(activity == "stableKeys")
                    }
                    if url.lastPathComponent == "System Design.pdf" && page.pageIndex == 2 { precondition(activity == "cachedCopy") }
                }
                report.append(["document": url.lastPathComponent, "page": page.pageIndex + 1,
                    "verified": page.spatialIntegrityPassed == true, "claims": current.meaningfulClaims.count,
                    "generated": current.questions.count, "accepted": accepted.count, "rejections": failures,
                    "beforeStems": old.questions.map(\.prompt), "afterStems": accepted.map(\.prompt), "activity": activity, "teach": teach])
                print(prefix, "claims", current.meaningfulClaims.count, "accepted", accepted.count, "rejections", failures, "activity", activity)
                if page.pageIndex == 2 {
                    let thumbnail = pdf.page(at: page.pageIndex)!.thumbnail(of: NSSize(width: 900, height: 1300), for: .cropBox)
                    if let tiff = thumbnail.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                       let png = bitmap.representation(using: .png, properties: [:]) { try png.write(to: output.appendingPathComponent(prefix + "-PDF-reference.png")) }
                }
            }
        }
        let cold = Date(); let index = GroundedConnectionIndex(analyses: analyses)
        let coldMS = Date().timeIntervalSince(cold) * 1000
        var times: [Double] = [], connections: [GroundedConnection] = []
        for _ in 0..<5 { for source in sources {
            let start = Date(); let found = index.connections(from: source)
            times.append(Date().timeIntervalSince(start) * 1000); connections.append(contentsOf: found)
        } }
        times.sort()
        var benchmark = analyses
        for copy in 1...1 { for original in analyses.values {
            var clone = original
            clone.documentID = UUID()
            clone.fingerprint += "-benchmark-copy-\(copy)"
            benchmark[clone.documentID] = clone
        } }
        let largeStart = Date(); let largeIndex = GroundedConnectionIndex(analyses: benchmark)
        let largeBuild = Date().timeIntervalSince(largeStart) * 1000
        var largeTimes: [Double] = [], admissionTimes: [Double] = []
        for source in sources {
            let start = Date(); _ = largeIndex.connections(from: source)
            largeTimes.append(Date().timeIntervalSince(start) * 1000)
            let admit = Date()
            _ = IntelligenceSource(source: source.passage, analysis: analyses[source.packet.documentID]!)
            _ = ActivityValidator.definition(for: source)
            admissionTimes.append(Date().timeIntervalSince(admit) * 1000)
        }
        largeTimes.sort(); admissionTimes.sort()
        let envelope: [String: Any] = ["proof": "production PDF extraction + deterministic host execution; no model inference or iOS UI",
            "mobileMasteryProvided": urls.count == 4, "totalAccepted": total, "pages": report,
            "connectionCount": Set(connections.map(\.id)).count, "indexBuildMilliseconds": coldMS,
            "retrievalMedianMilliseconds": times[times.count / 2],
            "sourceAdmissionMedianMilliseconds": admissionTimes[admissionTimes.count / 2],
            "syntheticBenchmark": ["kind": "Repeated sample documents; not additional source certification",
                "documentCount": benchmark.count, "indexBuildMilliseconds": largeBuild,
                "retrievalMedianMilliseconds": largeTimes[largeTimes.count / 2]]]
        try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("real-pdf-report.json"))
        print("TOTAL", total, "CONNECTIONS", Set(connections.map(\.id)).count, "RETRIEVAL MEDIAN MS", times[times.count / 2])
    }
}
