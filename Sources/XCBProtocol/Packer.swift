/*
Copyright (c) 2022, XCBuildKit contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of the IDEXCBProgress project.
*/
import Foundation
import MessagePack

extension FixedWidthInteger {
    var bytes: [UInt8] {
        let capacity = MemoryLayout<Self>.size
        var mutableValue = bigEndian
        return withUnsafePointer(to: &mutableValue) {
            $0.withMemoryRebound(to: UInt8.self, capacity: capacity) {
                Array(UnsafeBufferPointer(start: $0, count: capacity))
            }
        }
    }
}

extension XCBRawValue {
    func prettyPrint(_ raw: XCBRawValue, padding: String = "") {
        if case .binary(let b) = raw {
            print("\(padding)XCBRawValue.binary(\"" + b.rawHbytes() + "\"),")
        } else if case .string(let str) = raw {
            print("\(padding)XCBRawValue.string(\"\(str)\"),")
        } else if case .array(let array) = raw {
            print("\(padding)XCBRawValue.array([")
            for arrayValue in array {
               prettyPrint(arrayValue, padding: padding + "    ") 
            }
            print("\(padding)]),")
        } else {
            print(padding + "XCBRawValue." + String(describing: raw) + ",")
        }
    }

    public func prettyPrint() {
        prettyPrint(self, padding: " ")
    }
}

extension Data {
    // This prints data in the form of hex bytes and ASCII characters
    func hbytes() -> String {
        return map {
            b in
            "\\x" + String(format: "%02hhx", b)
        }.joined()
    }

    func rawHbytes() -> String {
        return "[" + map {
            b in
            "0x" + String(format: "%02hhx", b)
        }.joined(separator: ",") + "]"
    }


    func bbytes() -> String {
        return map {
            b in
            if b > 0, b < 128 {
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
        return self.isAscii ? unicodeScalars.first?.value : nil
    }
}

extension StringProtocol {
    var ascii: [UInt32] {
        return compactMap { $0.ascii }
    }
}

public protocol XCBValue {
    func toXCB() -> Data
}

public typealias XCBRawValue = MessagePackValue

public struct XCBInputStream  {
    public let data: Data
    public var stream: IndexingIterator<[MessagePackValue]>
    public let first: MessagePackValue

    // This thing reads in a result - maybe it will not do this.
    public init (result: [MessagePackValue], data: Data) {
        self.stream = result.makeIterator()
        self.data = data
        self.first = result.first ?? .uint(0)
    }

    public mutating func next() -> MessagePackValue? {
        return self.stream.next()
    }
}

public typealias XCBResponse = [XCBValue]

// FIXME: Fix protocol implementation
// Some of the API uses Swift primitives and some uses MessagePackValue due to
// the fact that a lot of MessagePack.swift doesn't correctly handle all data
// types. This is an implementation detail of XCBProtocol and needs fixing.
// Finally, I started forking since some issues weren't possible to fix ad-hoc
// This should be patched into MessagePack.swift if it stays around
extension MessagePackValue: XCBValue {
    public func toXCB() -> Data {
        return MessagePack.pack(self)
    }
}

extension Int: XCBValue {
    public func toXCB() -> Data {
        return MessagePack.pack(.int(Int64(self)))
    }
}

extension Int64: XCBValue {
    public func toXCB() -> Data {
        return Data([0xD3]) + bytes
    }
}

func packInteger(_ value: UInt64, parts: Int) -> Data {
    precondition(parts > 0)
    let bytes = stride(from: 8 * (parts - 1), through: 0, by: -8).map { shift in
        UInt8(truncatingIfNeeded: value >> UInt(shift))
    }
    return Data(bytes)
}

extension Array: XCBValue where Element == XCBValue {
    public func toXCB() -> Data {
        let count = UInt32(self.count)
        precondition(count <= 0xFFFF_FFFF as UInt32)

        let prefix: Data
        if count < 15 {
            prefix = Data([0x90 | UInt8(count)])
        } else if count <= 0xFFFF {
            prefix = Data([0xDC]) + packInteger(UInt64(count), parts: 2)
        } else {
            prefix = Data([0xDD]) + packInteger(UInt64(count), parts: 4)
        }
        return prefix + flatMap { $0.toXCB() }
    }
}

public enum XCBPacker {
    public static func pack(_ value: XCBValue) -> Data {
        return value.toXCB()
    }
}
