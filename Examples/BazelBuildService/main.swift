import BKBuildService
import Foundation
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

/// FIXME: support multiple workspaces
var gStream: BEPStream?
// Experimental, enables indexing buffering logic
// Make sure indexing is enabled first, i.e., run `make enable_indexing`
//
// In `BazelBuildService` keep as `false` by default until this is ready to be enabled in all scenarios mostly to try to keep
// this backwards compatible with others installing this build service to get the progress bar.
private let indexingEnabled: Bool = false

// TODO: Make this part of an API to be consumed from callers
//
// "source file" => "output file" map, hardcoded for now, will be part of the API in the future
// Should match your local path and the values set in `Makefile > generate_custom_index_store`
//
// TODO: Should come from an aspect in Bazel
// Example of what source => object file under bazel-out mapping would look like:
//
// "Test-XCBuildKit-cdwbwzghpxmnfadvmmhsjcdnjygy": [
//     "/tests/ios/app/App/main.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/main.o",
//     "/tests/ios/app/App/Foo.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/Foo.o",
// ],
private let outputFileForSource: [String: [String: String]] = [
    // Vanilla Xcode mapping for debug/testing purposes
    "iOSApp-frhmkkebaragakhdzyysbrsvbgtc": [
        "/CLI/main.m": "/tmp/xcbuild-out/CLI/main.o",
        "/iOSApp/main.m": "/tmp/xcbuild-out/iOSApp/main.o",
    ],
]

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
    static func startStream(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startStream " + String(describing: startBuildInput))
        let stream = try BEPStream(path: bepPath)
        var progressView: ProgressView?
        try stream.read {
            event in
            if let updatedView = ProgressView(event: event, last: progressView) {
                let encoder = XCBEncoder(input: startBuildInput)
                let response = BuildProgressUpdatedResponse(progress:
                    updatedView.progressPercent, message: updatedView.message)
                if let responseData = try? response.encode(encoder) {
                     bkservice.write(responseData)
                }
                progressView = updatedView
            }
        }
        gStream = stream
    }

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
                workspaceHash = createSessionRequest.workspaceHash
                workspaceName = createSessionRequest.workspaceName
                xcbbuildService.startIfNecessary(xcode: gXcode)
            } else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }

                let message = BuildProgressUpdatedResponse()
                if let responseData = try? message.encode(encoder) {
                     bkservice.write(responseData)
                }
            } else if indexingEnabled && msg is IndexingInfoRequested {
                // Example of a custom indexing service
                let reqMsg = msg as! IndexingInfoRequested
                workingDir = reqMsg.workingDir
                platform = reqMsg.platform
                sdk = reqMsg.sdk

                let workspaceKey = "\(workspaceName)-\(workspaceHash)"
                let sourceKey = reqMsg.filePath.replacingOccurrences(of: workingDir, with: "")
                guard let outputFilePath = outputFileForSource[workspaceKey]?[sourceKey] else {
                    fatalError("Failed to find output file for source: \(reqMsg.filePath)")
                    return
                }
                log("Found output file \(outputFilePath) for source \(reqMsg.filePath)")

                let clangXMLData = BazelBuildServiceStub.getASTArgs(
                    targetID: reqMsg.targetID,
                    sourceFilePath: reqMsg.filePath,
                    outputFilePath: outputFilePath,
                    derivedDataPath: reqMsg.derivedDataPath,
                    workspaceHash: workspaceHash,
                    workspaceName: workspaceName,
                    sdkPath: sdkPath,
                    sdkName: sdk,
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
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService(indexingEnabled: indexingEnabled)

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
