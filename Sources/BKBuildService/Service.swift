import Foundation
import MessagePack
import XCBProtocol

/// (input, data, context)
///
/// @param input is only useful for encoder
/// e.g. XCBDecoder(input: input).decodeMessage()
///
/// @param data used to forward messages
///
/// @param context is used to pass state around

public typealias XCBResponseHandler = (XCBInputStream, Data, Any?) -> Void

public class BKBuildService {
    let shouldDump: Bool
    internal static let writeQueue = DispatchQueue(label: "com.xcbuildkite.bkbuildservice")

    public init() {
        self.shouldDump = CommandLine.arguments.contains("--dump")
    }

    /// Starts a service on standard input
    public func start(responseHandler: @escaping XCBResponseHandler, context:
        Any?) {
        let file = FileHandle.standardInput
        file.readabilityHandler = {
            h in
            let data = h.availableData
            guard data.count > 0 else {
                exit(0)
            }

            /// Unpack everything
            let result = Unpacker.unpackAll(data)
            if case let .uint(id) = result.first {
                let msgId = id + 1
                log("respond.msgId" + String(describing: msgId))
            } else {
                log("missing id")
            }

            let resultItr = result.makeIterator()
            if self.shouldDump {
                // Dumps out the protocol
                // useful for shouldDumpging, code gen'ing protocol messages, and
                // upgrading Xcode versions
                result.forEach { print("." + String(describing: $0) + ",") }
            } else {
                responseHandler(resultItr, data, context)
            }
        }
        repeat {
            sleep(1)
        } while true
    }

    public func write(_ v: XCBResponse) {
        // print("Datas", datasmap { $0.hbytes() }.joined())
        BKBuildService.writeQueue.sync {
            let datas = v.map {
                mm -> Data in
                log("Write: " + String(describing: mm))
                return XCBPacker.pack(mm)
            }

            datas.forEach { FileHandle.standardOutput.write($0) }
        }
    }
}

typealias Chunk = (XCBRawValue, Data)

// This is mostly an implementation detail for now
private enum Unpacker {
    public static func unpackOne(_ data: Data) -> Chunk? {
        return try? unpack(data)
    }

    static func startNext(_ data: Data) -> Data? {
        // If there is remaining bytes, try to strip out unparseable bytes
        // and continue down the stream
        var curr = data
        if curr.count > 1 {
            let streamLength = Int(curr[0])
            // FIXME: subdata is copying over and over?
            curr = curr.subdata(in: 1 ..< curr.count - 1)
            return curr
        } else {
            return nil
        }
    }

    public static func unpackAll(_ data: Data) -> [XCBRawValue] {
        var unpacked = [XCBRawValue]()
        var curr = data

        repeat {
            if let res = try? unpack(curr) {
                let (value, remainder) = res
                curr = remainder
                unpacked.append(value)
                continue
            }

            // At the end of a segment, there will be no more input
            if let next = startNext(curr) {
                curr = next
            } else {
                break
            }
        } while true
        return unpacked
    }
}
