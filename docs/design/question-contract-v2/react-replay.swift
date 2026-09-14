import Foundation
import PDFKit
import ShelfCore
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("docs/design/question-contract-v2")
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let analysis = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/design/model-p0-audit/same-pdf-analysis.json")))
let page = analysis.pages.first { $0.pageIndex == 2 }!
let packet = LearningSourcePacket(analysis: analysis, page: page)!
let pdf = PDFDocument(url: root.appendingPathComponent("Shelf/Resources/Samples/React Notes.pdf"))!
precondition(pdf.page(at: 2)!.string == packet.sourceText)
let preflight = GroundedQuestionCompiler().compile(packet)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(preflight).write(to: out.appendingPathComponent("react-page3-preflight.json"))
try encoder.encode(packet).write(to: out.appendingPathComponent("react-page3-packet.json"))
print("Actual PDFKit page text equals saved canonical analysis: true")
print("Status:", preflight.status, "meaningful:", preflight.meaningfulClaims.count, "selectable:", preflight.selectableClaims.count)
for claim in preflight.meaningfulClaims { print("CLAIM:", claim.concept, claim.cognitiveOperation, "RANGE:",claim.evidence.range, "PROMPT:",claim.prompt, "ANSWER:",claim.canonicalAnswer) }
precondition(preflight.status == .representable)
let existing = SemanticQuestionCompiler().compile(index: SemanticCompiler().compile(analysis), analysis: analysis)
print("Existing question bank count:", existing.count)
for c in preflight.questions {
 let q = try LearningCandidateValidator().validate(c, packet: packet, analysis: analysis, existing: existing).get()
 let r = q.source.range!
 precondition(pdf.page(at: 2)!.selection(for: NSRange(location:r.location,length:r.length))!.string == q.source.sourceText)
 let data = try encoder.encode(q)
 let reopened = try JSONDecoder().decode(LearningQuestion.self, from: data)
 precondition(reopened.modelProvenance?.selectedClaimID == c.selection?.claimID)
 precondition(reopened.source == q.source)
 let envelope: [String: Any] = ["verificationKind": "deterministic-host-replay-no-model-inference",
     "question": try JSONSerialization.jsonObject(with: data)]
 try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("react-admitted-" + c.skill + ".json"))
 print("ADMITTED:",q.prompt,"OPTIONS:",c.choices,"CORRECT:",c.correctChoice)
}
let old = try JSONDecoder().decode(LearningModelCandidate.self, from: Data(contentsOf: root.appendingPathComponent("docs/design/session-convergence/native-20260913-121148/unit-attachments/FDE50E47-D5B9-4825-9755-467E41335F97.json")))
print("Old mismatched candidate:",LearningCandidateValidator().validate(old,packet:packet,analysis:analysis,existing:[]))
print("PASS: actual PDF grounded representability, all selectable candidates admitted, all ranges match PDFKit selection.")
