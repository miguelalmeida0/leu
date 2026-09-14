import XCTest
@testable import ShelfCore

final class DigestTests: XCTestCase {
    func testEmptyDigest() {
        var h = PortableSHA256(); h.update(Data())
        XCTAssertEqual(h.finalize(), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
    func testABC() {
        var h = PortableSHA256(); h.update(Data("abc".utf8))
        XCTAssertEqual(h.finalize(), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func testMultiBlockVector() {
        var h = PortableSHA256()
        h.update(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8))
        XCTAssertEqual(h.finalize(), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }
    func testMillionAs() {
        var h = PortableSHA256()
        for _ in 0..<1_000 { h.update(Data(repeating: 97, count: 1_000)) }
        XCTAssertEqual(h.finalize(), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }
    func testChunkBoundariesAgree() {
        let bytes = Data((0..<10_000).map { UInt8(truncatingIfNeeded: $0) })
        var one = PortableSHA256(); one.update(bytes); let expected = one.finalize()
        for size in [1, 7, 31, 63, 64, 65, 127, 128, 257, 1024] {
            var h = PortableSHA256()
            for offset in stride(from: 0, to: bytes.count, by: size) {
                h.update(bytes.subdata(in: offset..<min(bytes.count, offset+size)))
            }
            XCTAssertEqual(h.finalize(), expected, "Chunk size \(size)")
        }
    }
    func testFileDigestStreamsCorrectly() throws {
        let dir = try TestDirectory(); let url = try dir.file("a", content: Data("abc".utf8))
        XCTAssertEqual(try FileDigest.sha256(url: url), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func testMissingFileThrows() throws {
        let dir = try TestDirectory()
        XCTAssertThrowsError(try FileDigest.sha256(url: dir.url.appendingPathComponent("missing")))
    }
}
