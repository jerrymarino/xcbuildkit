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

    var identifier: String?
    var identifierDatas: [Data] = []
    var isCollecting: Bool = false
    var gotMsgId: UInt64 = 0

    var supportedIdentifiers: [String] = [
        "INDEXING_INFO_REQUESTED",        
    ]

    var unsupportedIdentifiers: [String] = [
        "CREATE_SESSION",
        "CREATE_BUILD",
        "SET_SESSION_SYSTEM_INFO",
        "SET_SESSION_USER_INFO",
        "BUILD_START",
        "BUILD_DESCRIPTION_TARGET_INFO",
    ]

    /// Starts a service on standard input
    public func start(messageHandler: @escaping XCBMessageHandler, context:
        Any?) {
        let file = FileHandle.standardInput
        file.readabilityHandler = { [self]
            h in
            var aData = h.availableData
            guard aData.count > 0 else {
                exit(0)
            }
            var data = aData
            log("foo-buffer-6.0: \(data.readableString)")


            let fooResult = Unpacker.unpackAll(aData)
            var fooInput = XCBInputStream(result: fooResult, data: aData)
            var justStartedCollecting: Bool = false
            let idxData = "INDEXING_INFO_REQUESTED".data(using: .utf8)!
            var idxRange: Range<Int>?
            var prefixData: Data = Data()

            while let next = fooInput.next() {
                switch next {
                    case let .string(str):
                        if supportedIdentifiers.contains(str) {
                            isCollecting = true
                            justStartedCollecting = true
                            self.identifier = str
                            idxRange = data.range(of: idxData)
                            log("foo-ccc-1: \(idxRange)")
                        } else if unsupportedIdentifiers.contains(str) {
                            isCollecting = false
                        } else {
                            continue
                        }
                    
                    default:
                        continue
                }
            }

            if isCollecting && self.identifier != nil {
                var idxJSONData = data

                if justStartedCollecting {
                    // let xFactor: Int = 0
                    let xFactor: Int = 13
                    // var xFactor = serializerToken - (data.count - idxRange!.lowerBound)

                    if xFactor > 13 {
                        log("foo-ccc-2.1.1 will:")
                        log("foo-ccc-2.1.1 data: \(data.readableString)")
                        let xxFactor = 13
                        let fooPrefixData = data[0..<idxRange!.lowerBound-xxFactor]
                        log("foo-ccc-2.1.1 fooPrefixData: \(fooPrefixData.readableString)")
                    }
                    log("foo-ccc-2 xFactor : \(xFactor)")
                    
                    prefixData = data[0..<idxRange!.lowerBound-xFactor]
                    log("foo-ccc-2 prefixData : \(prefixData.readableString)")
                    log("foo-ccc-2 prefixData size: \(prefixData.count)")

                    idxJSONData = data[idxRange!.lowerBound-xFactor..<data.count]
                    log("foo-ccc-3 idxJSONData : \(idxJSONData.readableString)")
                    log("foo-ccc-3 idxJSONData size: \(idxJSONData.count)")

                    // var foo = idxJSONData
                    // log("foo-aaa-0 idxJSONData unpacked: \(Unpacker.unpackAll(foo))")

                    log("foo-aaa-9.0")

                    let readSizeFirst = MemoryLayout<UInt64>.size
                    log("foo-aaa-9.0.1: readSizeFirst \(readSizeFirst)")
                    log("foo-aaa-9.0.1.2: idxJSONData \(idxJSONData.prefix(10))")
                    log("foo-aaa-9.0.1.3: idxJSONData \(idxJSONData.readableString)")
                    // let msgIdData = idxJSONData[0 ..< readSizeFirst]
                    let msgIdData = idxJSONData.prefix(readSizeFirst)
                    log("foo-aaa-9.0.2")
                    let msgId = msgIdData.withUnsafeBytes { $0.load(as: UInt64.self) }
                    log("foo-aaa-9.0.3")

                    // data = data.advanced(by: readSizeFirst)
                    log("foo-aaa-9.1")
                    if prefixData.count > 0 {
                        log("foo-aaa-9.2")
                        data = prefixData
                        aData = data
                    }
                    self.gotMsgId = msgId
                }                
                self.identifierDatas.append(idxJSONData)
                log("foo-aaa-1")
                log("foo-aaa-1 self.identifier: \(self.identifier)")
                var dd = Data()
                for d in self.identifierDatas {
                    dd.append(d)
                }
                log("foo-aaa-1 self.identifierDatas: \(dd.readableString)")
                if prefixData.count == 0 {
                    log("foo-aaa-9.3")
                    return
                } 
            }

            log("foo-aaa-9.4")
            if !isCollecting && self.identifier != nil && self.identifierDatas.count > 0 {
                log("foo-aaa-9.5")
                var allData: Data = Data()
                for d in self.identifierDatas {
                    allData.append(d)
                }

                log("foo-aaa-2 allData: \(allData.readableString)")
                let idxResult = Unpacker.unpackAll(allData)
                let idxInput = XCBInputStream(result: idxResult, data: allData)
                let decoder = XCBDecoder(input: idxInput)
                let msg = decoder.decodeMessage()

                log("foo-aaa-3")
                if msg is IndexingInfoRequested {
                    log("foo-aaa-4 PING: self.gotMsgId \(self.gotMsgId)")
                    log("foo-aaa-4.1: \(aData.count)")
                    
                    write([
                        XCBRawValue.string("PING"),
                        XCBRawValue.nil,
                    ], msgId: self.gotMsgId)

                    // log("foo-buffer-6.1: \(msg)")
                    log("foo-buffer-6.1: \(allData.readableString)")
                    messageHandler(idxInput, allData, context)

                    self.identifier = nil
                    self.identifierDatas = []
                    self.gotMsgId = 0

                    return
                }
            }

            // guard data.count >= MemoryLayout<UInt64>.size + MemoryLayout<UInt32>.size else {
            //    self.buffer.append(data)
            //    return
            // }

            // // The buffering code is still WIP - short circuit for now
            // guard self.indexingEnabled else {
            //     let result = Unpacker.unpackAll(aData)
            //     log("foo-buffer-6.1: \(aData.readableString)")
            //     messageHandler(XCBInputStream(result: result, data: data), aData, context)
            //     return
            // }
            // let gotMsgId: UInt64
            // let startSize = self.readLen
            // if self.buffer.count == 0 {
            //     let readSizeFirst = MemoryLayout<UInt64>.size
            //     let msgIdData = data[0 ..< readSizeFirst]
            //     let msgId = msgIdData.withUnsafeBytes { $0.load(as: UInt64.self) }
            //     data = data.advanced(by: readSizeFirst)
            //     gotMsgId = msgId

            //     let readSizeSecond = MemoryLayout<UInt32>.size
            //     let sizeD = data[0 ..< readSizeSecond]
            //     let sizeB = sizeD.withUnsafeBytes { $0.load(as: UInt32.self) }
            //     let size = Int32(sizeB)
            //     data = data.advanced(by: readSizeSecond)

            //     log("Header.msgId \(msgId)")
            //     log("Header.size \(size)")
            //     self.readLen = size
            //     self.buffer = data
            // } else {
            //     gotMsgId = 0
            //     self.buffer.append(data)
            //     self.readLen = 0
            // }

            // if self.readLen > serializerToken {
            //     let result = Unpacker.unpackAll(aData)
            //     let decoder = XCBDecoder(input: XCBInputStream(result: result,
            //                                                    data: aData))
            //     // guard !XCBBuildServiceProcess.MessageDebuggingEnabled() else {
            //     //     messageHandler(XCBInputStream(result: [], data: data), aData, context)
            //     //     return
            //     // }

            //     let msg = decoder.decodeMessage() 
            //     if msg is IndexingInfoRequested {
            //         write([
            //             XCBRawValue.string("PING"),
            //             XCBRawValue.nil,
            //         ], msgId: gotMsgId)
            //         return
            //     }
            //     log("foo-buffer-6.2: \(aData.readableString)")
            //     // log("foo-buffer-6.2.1: \(Unpacker.unpackAll(aData))")
            //     messageHandler(XCBInputStream(result: [], data: data), aData, context)
            //     return
            // } else {
            //     data = self.buffer
            //     self.readLen = 0
            //     self.buffer = Data()

            //     // let subStr = String(data.readableString.prefix(25))
            //     // if subStr.contains("INDEXING_INFO_REQUESTED") {
            //     //     var unpacked = Unpacker.unpackAll(data)
            //     //     // unpacked.remove(at: 0)
            //     //     // var fooData = data.dropFirst(1)
            //     //     var fooData = data
            //     //     let decoder = XCBDecoder(input: XCBInputStream(result: unpacked, data: fooData))
            //     //     let msg = decoder.decodeMessage()
            //     //     // log("foo-buffer-1.1: \(data.readableString)")
            //     //     // log("foo-buffer-1.2: \(unpacked)")
            //     //     // log("foo-buffer-1.3: \(msg)")
            //     //     return
            //     // }
            // }
            // log("Header.Parse \(data)")
            // log("Header.Size \(self.readLen) - \(startSize) ")
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
                log("foo-buffer-6.2: \(aData.readableString)")
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
                log("Failed to unpack with err: \(e)")
                // Note: likely an error condition, but deal with what we can
                return unpacked
            }
        }
        return unpacked
    }
}
