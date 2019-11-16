import MessagePack
import Foundation

extension FixedWidthInteger {
    init(bytes: [UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee
            }
        }.bigEndian
    }
    
    var bytes: [UInt8] {
        let capacity = MemoryLayout<Self>.size
        var mutableValue = self.bigEndian
        return withUnsafePointer(to: &mutableValue) {
            return $0.withMemoryRebound(to: UInt8.self, capacity: capacity) {
                return Array(UnsafeBufferPointer(start: $0, count: capacity))
            }
        }
    }
}

extension Data {
    // This prints data in the form of hex bytes and ASCII characters
    func hbytes() -> String {
        return map {
            b in
                return "\\x" + String(format: "%02hhx", b)
        }.joined()
    }

    func bbytes() -> String {
        return map {
            b in
                if b > 0 && b < 128 {
                    return String(format: "%c", b)
                }
                return "\\x" + String(format: "%02hhx", b)
        }.joined()
    }
}

extension Character {
    var isAscii: Bool {
        return unicodeScalars.allSatisfy { $0.isASCII }
    }
    var ascii: UInt32? {
        return isAscii ? unicodeScalars.first?.value : nil
    }
}
extension StringProtocol {
    var ascii: [UInt32] {
        return compactMap { $0.ascii }
    }
}

func encodeString(_ string: String) -> MessagePackValue {
    let utf8 = string.utf8
    let count = UInt64(utf8.count)
    precondition(count <= 0xffff_ffff as UInt32)

    let prefix: Data
    if count <= 0x19 {
        prefix = Data([0xa0 | UInt8(count)])
    } else if count <= 0xff {
        prefix = Data([0xd9, UInt8(count)])
    } else if count <= 0xffff {
        prefix = Data([0xda]) + packInteger(UInt64(count), parts: 2)
    } else {
        prefix = Data([0xdb]) + packInteger(UInt64(count), parts: 4)
    }
    return .binary(Data() + utf8)
}


public protocol XCBValue {
    func toXCB() -> Data
}

public typealias XCBRawValue = MessagePackValue
public typealias XCBInputStream = IndexingIterator<[MessagePackValue]>
public typealias XCBResponse = [XCBValue]

/// Workaround for an issue in MessagePack, this xbd prefix
/// https://github.com/msgpack/msgpack/blob/master/spec.md
class MsgPackStringXbd : XCBValue {
    let value: String

    public init(_ value: String) {
        self.value = value
    }

    public func toXCB() -> Data {
        let utf8 = value.utf8
        let count = UInt32(utf8.count)
        let prefix = Data([0xbd])
        return prefix + utf8
    }
}


// TODO: Complete protocol implementation
extension MessagePackValue : XCBValue {
    public func toXCB() -> Data {
        //if case let .string(string) = self {
        //    return encodeString(string)
        //}
        return MessagePack.pack(self)
    }
}


extension Int : XCBValue {
    public func toXCB() -> Data {
        return MessagePack.pack(.int(Int64(self)))
    }
}


extension Int64 : XCBValue {
    public func toXCB() -> Data {
        return Data([0xd3]) + self.bytes
    }
}

func packInteger(_ value: UInt64, parts: Int) -> Data {
    precondition(parts > 0)
    let bytes = stride(from: (8 * (parts - 1)), through: 0, by: -8).map { shift in
        return UInt8(truncatingIfNeeded: value >> UInt(shift))
    }
    return Data(bytes)
}

extension Array : XCBValue  where Element == XCBValue {
    public func toXCB() -> Data {
        let count = UInt32(self.count)
        precondition(count <= 0xffff_ffff as UInt32)

        let prefix: Data
        if count < 15 {
            prefix = Data([0x90 | UInt8(count)])
        } else if count <= 0xffff {
            prefix = Data([0xdc]) + packInteger(UInt64(count), parts: 2)
        } else {
            prefix = Data([0xdd]) + packInteger(UInt64(count), parts: 4)
        }
        return prefix + self.flatMap{ $0.toXCB() }
    }
}

enum XCBPacker {
    public static func pack(_ value: XCBValue) -> Data {
        return value.toXCB()
    }
}

