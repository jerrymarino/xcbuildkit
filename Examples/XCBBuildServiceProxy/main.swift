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

// TODO: Make this part of an API to be consumed from callers
//
// "source file" => "output file" map, hardcoded for now, will be part of the API in the future
// Should match your local path and the values set in `Makefile > generate_custom_index_store`
private let outputFileForSource: [String: [String: String]] = [
    "iOSApp-frhmkkebaragakhdzyysbrsvbgtc": [
        "/CLI/main.m": "/tmp/xcbuild-out/CLI/main.o",
        "/iOSApp/main.m": "/tmp/xcbuild-out/iOSApp/main.o",
        "/iOSApp/Test.swift": "/tmp/xcbuild-out/iOSApp/Test.o",
    ],

    // TODO: Should come from an aspect in Bazel
    // Examples of what Bazel mappings would look like
    //
    // "Test-XCBuildKit/Users/thiago/Development/rules_ios/tests/ios/app/App/main.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/main.o",
    // "Test-XCBuildKit/Users/thiago/Development/rules_ios/tests/ios/app/App/Foo.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/Foo.o",
]

// Experimental, enables indexing buffering logic
// Make sure indexing is enabled first, i.e., run `make enable_indexing`
private let indexingEnabled: Bool = true
// Used when debugging msgs are enabled, see `XCBBuildServiceProcess.MessageDebuggingEnabled()`
private var gChunkNumber = 0
// FIXME: get this from the other paths
private var gXcode = ""
// TODO: parsed in `CreateSessionRequest`, consider a more stable approach instead of parsing `xcbuildDataPath` path there
private var workspaceHash = ""
// TODO: parsed in `CreateSessionRequest`, consider a more stable approach instead of parsing `xcbuildDataPath` path there
private var workspaceName = ""
// TODO: parsed in `IndexingInfoRequested`, there's probably a less hacky way to get this.
// Effectively `$PWD/iOSApp`
private var workingDir = ""
// Target config, e.g. 'Debug'/'Release'
private var targetConfiguration = ""
// Path to derived data for the current workspace
private var derivedDataPath = ""
// TODO: parsed in `IndexingInfoRequested` and it's lowercased there, might not be stable in different OSes
private var sdk = ""
// TODO: parsed in `IndexingInfoRequested` and it's lowercased there, might not be stable in different OSes
private var platform = ""
// TODO: parse the relative path to the SDK from somewhere
var sdkPath: String {
    guard gXcode.count > 0 else {
        fatalError("Failed to build SDK path, Xcode path is empty.")
    }
    guard sdk.count > 0 else {
        fatalError("Failed to build SDK path, sdk name is empty.")
    }
    guard platform.count > 0 else {
        fatalError("Failed to build SDK path, platform is empty.")
    }

    return "\(gXcode)/Contents/Developer/Platforms/\(platform).platform/Developer/SDKs/\(sdk).sdk"
}

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
    static func respond(input: XCBInputStream, data: Data, msgId: UInt64, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input, msgId: msgId)
        let identifier = input.identifier ?? ""

        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                gXcode = createSessionRequest.xcode
                workspaceHash = createSessionRequest.workspaceHash
                workspaceName = createSessionRequest.workspaceName
                xcbbuildService.startIfNecessary(xcode: gXcode)
            } else if let createBuildRequest = msg as? CreateBuildRequest {
                // This information was not explicitly available in `CreateSessionRequest`, parse from `CreateBuildRequest` instead
                // Necessary for indexing and potentially for other things in the future. This is effectively $SRCROOT.
                workingDir = createBuildRequest.workingDir
                derivedDataPath = createBuildRequest.derivedDataPath
                targetConfiguration = createBuildRequest.configuration
            } else if !XCBBuildServiceProcess.MessageDebuggingEnabled() && indexingEnabled && msg is IndexingInfoRequested {
                // Example of a custom indexing service
                let reqMsg = msg as! IndexingInfoRequested
                platform = reqMsg.platform
                sdk = reqMsg.sdk

                let workspaceKey = "\(workspaceName)-\(workspaceHash)"
                let sourceKey = reqMsg.filePath.replacingOccurrences(of: workingDir, with: "")
                guard let outputFilePath = outputFileForSource[workspaceKey]?[sourceKey] else {
                    fatalError("[ERROR] Failed to find output file for source: \(reqMsg.filePath)")
                }
                log("[INFO] Found output file \(outputFilePath) for source \(reqMsg.filePath)")

                let compilerInvocationData = XCBBuildServiceProxyStub.getASTArgs(
                    isSwift: reqMsg.filePath.hasSuffix(".swift"),
                    targetID: reqMsg.targetID,
                    sourceFilePath: reqMsg.filePath,
                    outputFilePath: outputFilePath,
                    derivedDataPath: derivedDataPath,
                    workspaceHash: workspaceHash,
                    workspaceName: workspaceName,
                    sdkPath: sdkPath,
                    sdkName: sdk,
                    workingDir: workingDir,
                    configuration: targetConfiguration,
                    platform: platform)

                let message = IndexingInfoReceivedResponse(
                    targetID: reqMsg.targetID,
                    data: reqMsg.outputPathOnly ? outputPathOnlyData(outputFilePath: outputFilePath, sourceFilePath: reqMsg.filePath) : nil,
                    responseChannel: UInt64(reqMsg.responseChannel),
                    compilerInvocationData: reqMsg.outputPathOnly ? nil : compilerInvocationData)
                if let encoded: XCBResponse = try? message.encode(encoder) {
                    log("[INFO] Handling \(identifier) for source \(reqMsg.filePath) and output file \(outputFilePath)")
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
        log("[INFO] Proxying request with type: \(identifier)")
        // writes input data to original service
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

log("Start service - XCBBuildServiceProxy")
bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
