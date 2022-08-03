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

private let serializerToken = 4096

public class BKBuildService {
    let shouldDump: Bool
    let shouldDumpHumanReadable: Bool

    // This needs to be serial in order to serialize the messages / prevent
    // crossing streams.
    internal static let writeQueue = DispatchQueue(label: "com.xcbuildkit.bkbuildservice")

    private var readLen: Int32 = -1
    private var buffer = Data()

    // This is highly experimental
    private var indexingEnabled: Bool

    // TODO: Move record mode out
    private var chunkId = 0

    public init(indexingEnabled: Bool=false) {
        self.indexingEnabled = indexingEnabled
        self.shouldDump = CommandLine.arguments.contains("--dump")
        self.shouldDumpHumanReadable = CommandLine.arguments.contains("--dump_h")
    }

    /// Starts a service on standard input
    public func start(messageHandler: @escaping XCBMessageHandler, context:
        Any?) {
        let file = FileHandle.standardInput
        file.readabilityHandler = { [self]
            h in
            let aData = h.availableData
            guard aData.count > 0 else {
                exit(0)
            }
            var data = aData
            guard data.count >= MemoryLayout<UInt64>.size + MemoryLayout<UInt32>.size else {
               self.buffer.append(data)
               return
            }

            // The buffering code is still WIP - short circuit for now
            guard self.indexingEnabled else {
                let result = Unpacker.unpackAll(aData)
                messageHandler(XCBInputStream(result: result, data: data), aData, context)
                return
            }
            let gotMsgId: UInt64
            let startSize = self.readLen
            if self.buffer.count == 0 {
                let readSizeFirst = MemoryLayout<UInt64>.size
                let msgIdData = data[0 ..< readSizeFirst]
                let msgId = msgIdData.withUnsafeBytes { $0.load(as: UInt64.self) }
                data = data.advanced(by: readSizeFirst)
                gotMsgId = msgId

                let readSizeSecond = MemoryLayout<UInt32>.size
                let sizeD = data[0 ..< readSizeSecond]
                let sizeB = sizeD.withUnsafeBytes { $0.load(as: UInt32.self) }
                let size = Int32(sizeB)
                data = data.advanced(by: readSizeSecond)

                log("Header.msgId \(msgId)")
                log("Header.size \(size)")
                self.readLen = size
                self.buffer = data
            } else {
                gotMsgId = 0
                self.buffer.append(data)
                self.readLen = 0
            }

            if self.readLen > serializerToken {
                let result = Unpacker.unpackAll(aData)
                let decoder = XCBDecoder(input: XCBInputStream(result: result,
                                                               data: aData))
                guard !XCBBuildServiceProcess.MessageDebuggingEnabled() else {
                    messageHandler(XCBInputStream(result: [], data: data), aData, context)
                    return
                }

                let msg = decoder.decodeMessage() 
                if msg is IndexingInfoRequested {
                    write([
                        XCBRawValue.string("PING"),
                        XCBRawValue.nil,
                    ], msgId: gotMsgId)
                    return
                }
                messageHandler(XCBInputStream(result: [], data: data), aData, context)
                return
            } else {
                data = self.buffer
                self.readLen = 0
                self.buffer = Data()
            }
            log("Header.Parse \(data)")
            log("Header.Size \(self.readLen) - \(startSize) ")
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
                messageHandler(XCBInputStream(result: result, data: data), aData, context)
            }
        }
        repeat {
            sleep(1)
        } while true
    }

    public func write(_ v: XCBResponse, msgId: UInt64 = 0) {
        // print("Datas", datasmap { $0.hbytes() }.joined())
        BKBuildService.writeQueue.sync {
            let msgData = v.reduce(into: Data()) { accum, mm in
                accum.append(XCBPacker.pack(mm))
            }

            let msgIdData = withUnsafeBytes(of: msgId) { Data($0) }
            let sizeData = withUnsafeBytes(of: UInt32(msgData.count)) { Data($0) }

            var header = Data()
            header.append(msgIdData)
            header.append(sizeData)

            var debugData = Data()
            var writeData = Data()
            debugData.append(header)
            writeData.append(header)
            writeData.append(msgData)
            [writeData].forEach { idata in
                var data = idata
                // For now this only handles 1 buffer
                // Possibly a better way - this should loop N > 1
                if data.count >= serializerToken {
                    let currChunk = data[0..<serializerToken]
                    FileHandle.standardOutput.write(currChunk)
                    try? currChunk.write(to: URL(fileURLWithPath: "/tmp/x-stubs/xcbuild.pack.stdout.\(chunkId).bin"))
                    debugData.append(currChunk)
                    chunkId += 1


                    // TODO: conditionally add these here
                    data = data.advanced(by: serializerToken)
                }
                debugData.append(data)
                try? debugData.write(to: URL(fileURLWithPath: "/tmp/x-stubs/xcbuild.pack.stdout.\(chunkId).debugData"))
                FileHandle.standardOutput.write(data)
            }
        }
    }
    public func writeRaw(_ msgData: Data, msgId: UInt64 = 0) {
        BKBuildService.writeQueue.sync {
            let msgIdData = withUnsafeBytes(of: msgId) { Data($0) }
            let sizeData = withUnsafeBytes(of: UInt32(msgData.count)) { Data($0) }

            var header = Data()
            header.append(msgIdData)
            header.append(sizeData)

            var debugData = Data()
            var writeData = Data()
            debugData.append(header)
            /* This needs further analysis here - when does this actually need
            * to get written
            writeData.append(header)
            */
            writeData.append(msgData)
            [writeData].forEach { idata in
                var data = idata
                // For now this only handles 1 buffer
                // Possibly a better way - this should loop N > 1
                if data.count >= serializerToken {
                    let currChunk = data[0..<serializerToken]
                    FileHandle.standardOutput.write(currChunk)
                    try? currChunk.write(to: URL(fileURLWithPath: "/tmp/x-stubs/xcbuild.pack.stdout.\(chunkId).bin"))
                    debugData.append(currChunk)
                    chunkId += 1
                    data = data.advanced(by: serializerToken)
                }
                debugData.append(data)
                try? debugData.write(to: URL(fileURLWithPath: "/tmp/x-stubs/xcbuild.pack.stdout.\(chunkId).debugData"))
                FileHandle.standardOutput.write(data)
            }
        }
    }

    public func writeRaw(_ data: Data) {
        BKBuildService.writeQueue.sync {
            FileHandle.standardOutput.write(data)
        }
    }
}

public typealias Chunk = (XCBRawValue, Data)

// This is mostly an implementation detail for now
public enum Unpacker {
    public static func unpackOne(_ data: Data) -> Chunk? {
        return try? unpack(data)
    }

    public static func unpackAll(_ data: Data) -> [XCBRawValue] {
        var unpacked = [XCBRawValue]()

        var sdata = Subdata(data: data)
        while !sdata.isEmpty {
            let value: XCBRawValue
            if let res = try? unpack(sdata) {
                let (value, remainder) = res
                unpacked.append(value)
                sdata = remainder
            } else {
                // Note: likely an error condition, but deal with what we can
                return unpacked
            }
        }
        return unpacked
    }
}
