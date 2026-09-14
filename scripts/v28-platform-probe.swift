import Foundation
import NaturalLanguage
import Darwin

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
func check(_ name: String, _ body: () throws -> Void) {
    do { try body(); print("\(name): PASS") }
    catch { print("\(name): FAIL \(String(reflecting: error)) \((error as NSError).userInfo)") }
}
let bytes = Data("owned diagnostic scratch data".utf8)
check("ordinary write") { try bytes.write(to: root.appendingPathComponent("ordinary")) }
check("Foundation atomic write") { try bytes.write(to: root.appendingPathComponent("atomic"), options: .atomic) }
check("same-directory synchronized rename") {
    let staged = root.appendingPathComponent("staged")
    let destination = root.appendingPathComponent("committed")
    try bytes.write(to: staged)
    let handle = try FileHandle(forWritingTo: staged)
    try handle.synchronize()
    try handle.close()
    guard rename(staged.path, destination.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    guard try Data(contentsOf: destination) == bytes else { throw NSError(domain: "checksum", code: 1) }
}
for (name, embedding) in [("sentence", NLEmbedding.sentenceEmbedding(for: .english)), ("word", NLEmbedding.wordEmbedding(for: .english))] {
    guard let embedding else { print("\(name) embedding: unavailable"); continue }
    print("\(name) embedding: dimension=\(embedding.dimension) revision=\(embedding.revision)")
    let a = "A stable key helps React match an item to its previous instance."
    for b in ["React needs a consistent ID to recognize the same thing after the list moves.", "React never needs an ID to recognize the same item.", "Retries are appropriate for transient failures."] {
        print("\(name) distance \(embedding.distance(between: a, and: b)) :: \(b)")
    }
}
