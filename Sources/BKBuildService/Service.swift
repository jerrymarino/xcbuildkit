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

public typealias XCBMessageHandler = (XCBInputStream, Data, Any?) -> Void

public class BKBuildService {
    let shouldDump: Bool
    let shouldDumpHumanReadable: Bool

    // This needs to be serial in order to serialize the messages / prevent
    // crossing streams.
    internal static let writeQueue = DispatchQueue(label: "com.xcbuildkit.bkbuildservice")

    public init() {
        self.shouldDump = CommandLine.arguments.contains("--dump")
        self.shouldDumpHumanReadable = CommandLine.arguments.contains("--dump_h")
    }

    /// Starts a service on standard input
    public func start(messageHandler: @escaping XCBMessageHandler, context:
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
            if let first = result.first, case let .uint(id) = first {
                let msgId = id + 1
                log("respond.msgId" + String(describing: msgId))
            } else {
                log("missing id")
            }

            if self.shouldDump {
                // Dumps out the protocol
                // useful for debuging, code gen'ing protocol messages, and
                // upgrading Xcode versions
                result.forEach{ $0.prettyPrint() }
            } else if self.shouldDumpHumanReadable {
                // Same as above but dumps out the protocol in human readable format
                PrettyPrinter.prettyPrintRecursively(result)
            } else {
                messageHandler(result.makeIterator(), data, context)
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
        if data.count > 1 {
            // If there is remaining bytes, try to strip out unparseable bytes
            // and continue down the stream

            // Note: the first element is some length? This is not handled by
            // MessagePack.swift
            // FIXME: subdata is copying over and over?
            var mdata = data
            mdata = mdata.subdata(in: 1 ..< mdata.count)
            return mdata
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
