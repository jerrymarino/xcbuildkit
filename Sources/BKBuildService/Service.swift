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

public typealias XCBMessageHandler = (XCBInputStream, Data, UInt64, Any?) -> Void

private let serializerToken = 4096

public class BKBuildService {
    let shouldDump: Bool
    let shouldDumpHumanReadable: Bool

    // This needs to be serial in order to serialize the messages / prevent
    // crossing streams.
    internal static let writeQueue = DispatchQueue(label: "com.xcbuildkit.bkbuildservice")

    private var buffer = Data()
    private var bufferMsgId = Data()
    private var bufferContentSize = Data()
    private var bufferNext = Data()
    private var readLen: Int32 = 0
    private var msgId: UInt64 = 0

    // TODO: Move record mode out
    private var chunkId = 0

    public init() {
        self.shouldDump = CommandLine.arguments.contains("--dump")
        self.shouldDumpHumanReadable = CommandLine.arguments.contains("--dump_h")
    }

    // Once a buffer is ready to write to stdout and respond to Xcode invoke this
    func handleRequest(messageHandler: @escaping XCBMessageHandler, context: Any?) {
        let result = Unpacker.unpackAll(self.buffer)
        let input = XCBInputStream(result: result)
        let decoder = XCBDecoder(input: input)
        let msg = decoder.decodeMessage()

        // The original complete message received should be passed to `messageHandler`
        // in case the proxy implementation does not handle a particular message, in that case
        // we need the complete original message to be written to stdin so Xcode's build service can
        // pick it up and process it
        var ogData = Data()
        ogData.append(self.bufferMsgId)
        ogData.append(self.bufferContentSize)
        ogData.append(self.buffer)

        // Indexing msgs require a PING on the msgId before passing the payload
        // doing this here so build service writers don't have to worry about this impl detail
        if msg is IndexingInfoRequested  {
            write([
                XCBRawValue.string("PING"),
                XCBRawValue.nil,
            ], msgId: self.msgId)
        }

        // This propagates the message to the build service
        // In there messages should be either handled or proxied
        messageHandler(input, ogData, self.msgId, context)

        // Reset all the things
        self.buffer = Data()
        self.bufferMsgId = Data()
        self.bufferContentSize = Data()
        self.readLen = 0
        self.msgId = 0

        // See `appendToBuffer`. If the end of a message and the beginning of the next
        // come in the same package we need to handle it and initilize the buffer with the
        // new data before the next cycle so things continue to be processed continuously
        //
        // This is done below, if the leftover is a complete message just handle it right away
        // otherwise return so the buffer continue to be populated in the next cycle
        if self.bufferNext.count > 0 {
            let readyToProcess = initializeBuffer(data: self.bufferNext)
            self.bufferNext = Data()

            guard readyToProcess else { return }
            handleRequest(messageHandler: messageHandler, context: context)
        }
    }

    // Collect msgId and size of content to be collected at the beginning of a stream
    func collectHeaderInfo(data: Data) -> (Int32, Data) {
        var tmpData = data
        let readSizeFirst = MemoryLayout<UInt64>.size
        let msgIdData = tmpData[0 ..< readSizeFirst]
        self.bufferMsgId = msgIdData
        let msgId = msgIdData.withUnsafeBytes { $0.load(as: UInt64.self) }
        tmpData = tmpData.advanced(by: readSizeFirst)
        self.msgId = msgId

        let readSizeSecond = MemoryLayout<UInt32>.size
        let sizeD = tmpData[0 ..< readSizeSecond]
        self.bufferContentSize = sizeD
        let sizeB = sizeD.withUnsafeBytes { $0.load(as: UInt32.self) }
        let size = Int32(sizeB)
        tmpData = tmpData.advanced(by: readSizeSecond)

        return (size, tmpData)
    }

    // Initialize the buffer, if it's a small message and all content comes in one packet it
    // can be processed instantly in the call site
    func initializeBuffer(data: Data) -> Bool {
        // Collect msgId and size to be collected first, then initialize the buffer
        var (size, bufferData) = collectHeaderInfo(data: data)

        // If all data for this message is in `data` just store that and return
        // a 'buffer is ready to be processed' response
        if size <= Int32(bufferData.count) {
            self.buffer = bufferData
            self.readLen = 0

            return true
        }

        // If data needs to be accumulated append to buffer and calculate the length
        // of the message to be collected in the next messages
        //
        // Returns `false` meaning that the buffer is still not ready to be processed
        self.buffer.append(bufferData)
        self.readLen = size - Int32(bufferData.count)

        return false
    }

    // If `initializeBuffer` detects that a buffer is not ready yet and more info needs to be collected
    // do this work here and append to the buffer until the message is complete.
    //
    // More often than not the end of a message is going to come with the beginning of another message
    // in that case the data will be partitioned and store in `self.bufferNext` to be picked up in the next cycle
    //
    // Returns the state of 'buffer is ready to be processed'
    func appendToBuffer(data: Data) -> Bool {
        if self.readLen > serializerToken {
            self.buffer.append(data)
            // Remaining length left after appending
            self.readLen = self.readLen - Int32(data.count)
            return false
        } else if self.readLen > 0 {
            var nextData = data

            var finalData = nextData[0 ..< Int(self.readLen)]
            self.buffer.append(finalData)

            nextData = nextData.advanced(by: Int(self.readLen))

            if nextData.count > 0 {
                self.bufferNext = nextData
            } else {
                self.bufferNext = Data()
            }
            self.readLen = 0
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

            guard !self.shouldDump else {
                // Dumps out the protocol
                // useful for debuging, code gen'ing protocol messages, and
                // upgrading Xcode versions
                Unpacker.unpackAll(data).forEach{ $0.prettyPrint() }
                return
            }

            guard !self.shouldDumpHumanReadable else {
                // Same as above but dumps out the protocol in human readable format
                PrettyPrinter.prettyPrintRecursively(Unpacker.unpackAll(data))
                return
            }

            // Initialize or append to buffer, return value is the state of 'buffer is ready to be processed or not'
            let readyToProcess = self.buffer.count == 0 ? initializeBuffer(data: data) : appendToBuffer(data: data)
            guard readyToProcess else { return }

            // Buffer is ready, just handle it
            handleRequest(messageHandler: messageHandler, context: context)
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
