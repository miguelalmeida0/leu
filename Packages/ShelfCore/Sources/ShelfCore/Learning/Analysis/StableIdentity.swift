import Foundation

enum StableIdentity {
    static func hash64(_ text: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    static func uuid(_ text: String) -> UUID {
        let first = hash64("a|" + text)
        let second = hash64("b|" + text)
        var bytes: [UInt8] = []
        for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8((first >> UInt64(shift)) & 0xff)) }
        for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8((second >> UInt64(shift)) & 0xff)) }
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
