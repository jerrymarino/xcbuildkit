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

// TODO: Make this part of an API to be consumed from callers
//
// "source file" => "output file" map, hardcoded for now, will be part of the API in the future
// Should match your local path and the values set in `Makefile > generate_custom_index_store`
//
private let outputFileForSource: [String: String] = [
    // `echo $PWD/iOSApp/CLI/main.m`
    "/Users/thiago/Development/thiagohmcruz/xcbuildkit/iOSApp/CLI/main.m": "/tmp/xcbuild-out/main.o"
]

// TODO: parse from input stream or Xcode env
//
// Example: `/path/to/DerivedData/iOSApp-frhmkkebaragakhdzyysbrsvbgtc`
//
// Read more about this identifier here:
// https://pewpewthespells.com/blog/xcode_deriveddata_hashes.html
//
// Should match value in `Makefile > generate_custom_index_store`
//
let workspaceHash = "frhmkkebaragakhdzyysbrsvbgtc"

// TODO: parse this from somewhere
// To generate on the cmd line run
//
// xcrun --sdk macosx --show-sdk-path
//
// Should match value in `Makefile > generate_custom_index_store`
//
let macOSSDK = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk"

// TODO: `pwd` this and pass on the cmd line or parse from input stream (?)
//
// Effectively the result of running this from this repo root:
//
// `echo $PWD/iOSApp`
//
// Should match value in `Makefile > generate_custom_index_store`
//
let workingDir = "/Users/thiago/Development/thiagohmcruz/xcbuildkit/iOSApp"

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    // Required if `outputPathOnly` is `true` in the indexing request
    static func outputPathOnlyData(outputFilePath: String, sourceFilePath: String) -> Data {
        let xml = """
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <array>
                <dict>
                    <key>outputFilePath</key>
                    <string>\(outputFilePath)</string>
                    <key>sourceFilePath</key>
                    <string>\(sourceFilePath)</string>
                </dict>
            </array>
        </plist>
        """
        guard let converter = BPlistConverter(xml: xml) else {
            fatalError("Failed to allocate converter")
        }
        guard let bplistData = converter.convertToBinary() else {
            fatalError("Failed to convert XML to binary plist data")
        }

        return bplistData
    }

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
                guard let outputFilePath = outputFileForSource[reqMsg.filePath] else {
                    fatalError("Failed to find output file for source: \(reqMsg.filePath)")
                    return
                }

                log("Found output file \(outputFilePath) for source \(reqMsg.filePath)")

                let clangXMLData = XCBBuildServiceProxyStub.getASTArgs(
                    targetID: reqMsg.targetID,
                    sourceFilePath: reqMsg.filePath,
                    outputFilePath: outputFilePath,
                    derivedDataPath: reqMsg.derivedDataPath,
                    workspaceHash: workspaceHash,
                    macOSSDK: macOSSDK,
                    workingDir: workingDir)
                let message = IndexingInfoReceivedResponse(
                    targetID: reqMsg.targetID,
                    data: reqMsg.outputPathOnly ? outputPathOnlyData(outputFilePath: outputFilePath, sourceFilePath: reqMsg.filePath) : nil,
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
