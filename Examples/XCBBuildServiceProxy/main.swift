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
import BKBuildService
import Foundation
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

let writeQueue = DispatchQueue(label: "com.xcbuildkit.bkbuildservice-bzl")

private var gChunkNumber = 0
// FIXME: get this from the other paths
private var gXcode = ""

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    /// Proxying response handler
    /// Every message is written to the XCBBuildService
    /// This simply injects Progress messages from the BEP
    static func respond(input: XCBInputStream, data: Data, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input)
        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                gXcode = createSessionRequest.xcode
                xcbbuildService.startIfNecessary(xcode: createSessionRequest.xcode)
            } else if !XCBBuildServiceProcess.MessageDebuggingEnabled() && msg is IndexingInfoRequested {
                // Example of a custom indexing service
                let reqMsg = msg as! IndexingInfoRequested
                let clangXMLData = XCBBuildServiceProxyStub.getASTArgs(targetID: reqMsg.targetID, outputFilePath: reqMsg.filePath)
                let message = IndexingInfoReceivedResponse(
                    targetID: reqMsg.targetID,
                    data: reqMsg.outputPathOnly ? Data() : nil,
                    responseChannel: UInt64(reqMsg.responseChannel),
                    clangXMLData: reqMsg.outputPathOnly ? nil : clangXMLData)
                if let encoded: XCBResponse = try? message.encode(encoder) {
                    bkservice.write(encoded, msgId:message.responseChannel)
                    return
                }
            }
        }
        
        log("ProxyRequest \(data.count)")

        // TODO: Consider moving this into the process directly
        if XCBBuildServiceProcess.MessageDebuggingEnabled() {
            writeQueue.sync {
                gChunkNumber += 1
                try? data.write(to: URL(fileURLWithPath: "/tmp/in-stubs/xcbuild.og.stdin.\(gChunkNumber).bin"))
            }
        }
        // writes input data to original service
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService(indexingEnabled: true)

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

log("Start service - XCBBuildServiceProxy")
bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
