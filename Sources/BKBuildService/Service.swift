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

    private var buffer2 = Data()
    private var bufferHeader1 = Data()
    private var bufferHeader2 = Data()
    private var buffer2Next = Data()
    private var readLen2: Int32 = 0
    private var gotMsgId: UInt64 = 0

    // This is highly experimental
    private var indexingEnabled: Bool

    // TODO: Move record mode out
    private var chunkId = 0

    public init(indexingEnabled: Bool=false) {
        self.indexingEnabled = indexingEnabled
        self.shouldDump = CommandLine.arguments.contains("--dump")
        self.shouldDumpHumanReadable = CommandLine.arguments.contains("--dump_h")
    }

    func handleIdx(messageHandler: @escaping XCBMessageHandler, context: Any?) {
        let nowayResult = Unpacker.unpackAll(self.buffer2)
        let nowayInput = XCBInputStream(result: nowayResult, data: self.buffer2)
        let nowayDecoder = XCBDecoder(input: nowayInput)
        let nowayMsg = nowayDecoder.decodeMessage()

        if nowayMsg is IndexingInfoRequested {
            write([
                XCBRawValue.string("PING"),
                XCBRawValue.nil,
            ], msgId: self.gotMsgId)
            messageHandler(nowayInput, self.buffer2, context)
        } else {
            var ogData = Data()
            ogData.append(self.bufferHeader1)
            ogData.append(self.bufferHeader2)
            ogData.append(self.buffer2)

            var fooResult = [MessagePackValue]()
            var fooData = ogData
            if nowayMsg is CreateSessionRequest {
                fooResult = nowayResult
                fooData = self.buffer2
            }

            messageHandler(XCBInputStream(result: fooResult, data: fooData), ogData, context)
        }

        self.buffer2 = Data()
        self.bufferHeader1 = Data()
        self.bufferHeader2 = Data()
        self.readLen2 = 0
        self.gotMsgId = 0
    }

    func collectHeaderInfo(data: Data) -> (Int32, Data) {
        var tmpData = data
        let readSizeFirst2 = MemoryLayout<UInt64>.size
        let msgIdData2 = tmpData[0 ..< readSizeFirst2]
        self.bufferHeader1 = msgIdData2
        let msgId2 = msgIdData2.withUnsafeBytes { $0.load(as: UInt64.self) }
        tmpData = tmpData.advanced(by: readSizeFirst2)
        self.gotMsgId = msgId2

        let readSizeSecond2 = MemoryLayout<UInt32>.size
        let sizeD2 = tmpData[0 ..< readSizeSecond2]
        self.bufferHeader2 = sizeD2
        let sizeB2 = sizeD2.withUnsafeBytes { $0.load(as: UInt32.self) }
        let size2 = Int32(sizeB2)
        tmpData = tmpData.advanced(by: readSizeSecond2)        

        return (size2, tmpData)
    }

    func initializeBuffer(size: Int32, data: Data) -> Bool {
        if size <= Int32(data.count) {
            self.buffer2 = data
            self.readLen2 = 0
            return true
        }
        else {
            self.buffer2.append(data)
            self.readLen2 = min(max(size - Int32(data.count), 0), Int32(data.count))
            return false
        }        
    }

    func appendBuffer(data: Data) -> Bool {
        if self.readLen2 > serializerToken {
            self.buffer2.append(data)
            self.readLen2 = self.readLen2 - Int32(data.count)
            return false
        } else if self.readLen2 > 0 {
            var tmpData = data

            var finalData = tmpData[0 ..< Int(self.readLen2)]
            self.buffer2.append(finalData)

            tmpData = tmpData.advanced(by: Int(self.readLen2))

            if tmpData.count > 0 {
                self.buffer2Next = tmpData
            } else {
                self.buffer2Next = Data()
            }
            self.readLen2 = 0
            return true
        }

        return false
    }

    /// Starts a service on standard input
    public func start(messageHandler: @escaping XCBMessageHandler, context: Any?) {
        let file = FileHandle.standardInput
        file.readabilityHandler = { [self]
            h in
            var data = h.availableData
            guard data.count > 0 else {
                exit(0)
            }
            
            // ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ START
            var readyToProcess = false

            if self.buffer2.count == 0 {
                var (size2, tmpData) = collectHeaderInfo(data: data)
                readyToProcess = initializeBuffer(size: size2, data: tmpData)
            } else {
                readyToProcess = appendBuffer(data: data)
            }

            if readyToProcess {
                handleIdx(messageHandler: messageHandler, context: context)

                if self.buffer2Next.count > 0 {
                    var (size2, tmpData) = collectHeaderInfo(data: self.buffer2Next)
                    readyToProcess = initializeBuffer(size: size2, data: tmpData)

                    if readyToProcess {
                        handleIdx(messageHandler: messageHandler, context: context)
                        self.buffer2Next = Data()
                    }
                }
            }

            return
            // ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ END

            // var result: [MessagePackValue] = []
            // if data.readableString.contains("CREATE_SESSION") {
            //     result = Unpacker.unpackAll(data)
            //     if let first = result.first, case let .uint(id) = first {
            //         let msgId = id + 1
            //         log("respond.msgId" + String(describing: msgId))
            //     } else {
            //         log("missing id")
            //     }
            // }

            // if self.shouldDump {
            //     // Dumps out the protocol
            //     // useful for debuging, code gen'ing protocol messages, and
            //     // upgrading Xcode versions
            //     result.forEach{ $0.prettyPrint() }
            // } else if self.shouldDumpHumanReadable {
            //     // Same as above but dumps out the protocol in human readable format
            //     PrettyPrinter.prettyPrintRecursively(result)
            // } else {
            //     messageHandler(XCBInputStream(result: result, data: data), aData, context)
            // }
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
                chunkId += 1
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
                chunkId += 1
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
            do {
                let res = try unpack(sdata)
                let (value, remainder) = res
                unpacked.append(value)
                sdata = remainder
            } catch let e {
                log("Unpacker has failed to unpack with err: \(e)")
                // Note: likely an error condition, but deal with what we can
                return unpacked
            }
        }
        return unpacked
    }
}
