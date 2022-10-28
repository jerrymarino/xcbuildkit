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
// private let indexingEnabled: Bool = true

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
private var outputFileForSource: [String: [String: [String: String]]] = [
    // Vanilla Xcode mapping for debug/testing purposes
    "iOSApp-frhmkkebaragakhdzyysbrsvbgtc": [
        "foo_source_output_file_map.json": [
            "/CLI/main.m": "/tmp/xcbuild-out/CLI/main.o",
            "/iOSApp/main.m": "/tmp/xcbuild-out/iOSApp/main.o",
        ]
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
// Key to identify a workspace and find its mapping of source to object files in `outputFileForSource`
private var workspaceKey: String? {
    guard workspaceName.count > 0 && workspaceHash.count > 0 else {
        return nil
    }
    return "\(workspaceName)-\(workspaceHash)"
}
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
// Xcode project path
private var xcodeprojPath: String = ""
// Load configs
private var configValues: [String: Any]? {
    guard let data = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }

    let lines = data.components(separatedBy: .newlines)
    var dict: [String: Any] = [:]
    for line in lines {
        let split = line.components(separatedBy: "=")
        guard split.count == 2 else { continue }
        dict[split[0]] = split[1]
    }
    return dict
}
private var configPath: String {
    return "\(xcodeprojPath)/xcbuildkit.config"
}
private var bazelWorkingDir: String? {
    return configValues?["BUILD_SERVICE_BAZEL_EXEC_ROOT"] as? String
}
private var indexingEnabled: Bool {
    return (configValues?["BUILD_SERVICE_INDEXING_ENABLED"] as? String ?? "") == "YES"
}
private var progressBarEnabled: Bool {
    return (configValues?["BUILD_SERVICE_PROGRESS_BAR_ENABLED"] as? String ?? "") == "YES"
}
private var configBEPPath: String? {
    return configValues?["BUILD_SERVICE_BEP_PATH"] as? String
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

            // XCHammer generates JSON files containing source => output file mappings.
            //
            // This loop looks for JSON files with a known name pattern '_source_output_file_map.json' and extracts the mapping
            // information from it decoding the JSON and storing in-memory. We might want to find a way to pass this in instead.
            //
            // Read about the 'namedSetOfFiles' key here: https://bazel.build/remote/bep-examples#consuming-namedsetoffiles
            log("indexingEnabled: \(indexingEnabled)")
            if indexingEnabled {
                if let json = try? JSONSerialization.jsonObject(with: event.jsonUTF8Data(), options: []) as? [String: Any] {
                    if let namedSetOfFiles = json["namedSetOfFiles"] as? [String: Any] {
                        if namedSetOfFiles.count > 0 {
                            if let allPairs = namedSetOfFiles["files"] as? [[String: Any]] {
                                for pair in allPairs {
                                    guard let theName = pair["name"] as? String else {
                                        continue
                                    }
                                    guard var jsonURI = pair["uri"] as? String else {
                                        continue
                                    }
                                    guard jsonURI.hasSuffix(".json") else {
                                        continue
                                    }

                                    jsonURI = jsonURI.replacingOccurrences(of: "file://", with: "")

                                    guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath:jsonURI)) else {
                                        continue
                                    }
                                    guard jsonData.count > 0 else {
                                        continue
                                    }
                                    guard let jsonDecoded = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [String: String] else {
                                        continue
                                    }

                                    if let workspaceKey = workspaceKey, theName.contains("_source_output_file_map.json") {
                                        if outputFileForSource[workspaceKey] == nil {
                                            outputFileForSource[workspaceKey] = [:]
                                        }
                                        if outputFileForSource[workspaceKey]?[theName] == nil {
                                            outputFileForSource[workspaceKey]?[theName] = [:]
                                        }
                                        outputFileForSource[workspaceKey]?[theName] = jsonDecoded
                                    }
                                }
                            }
                        }
                    }
                }
            }            

            log("progressBarEnabled: \(progressBarEnabled)")
            if progressBarEnabled {
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

    static func shouldHandleIndexing(msg: XCBProtocolMessage) -> Bool {
        log("outputFileForSource: \(outputFileForSource)")
        log("foo-1")
        guard msg is IndexingInfoRequested else {
            log("foo-2")
            return false
        }
        guard let workspaceKey = workspaceKey else {
            log("foo-3")
            return false
        }
        guard indexingEnabled else {
            log("foo-4")
            return false
        }
        guard bazelWorkingDir != nil else {
            log("foo-5")
            return false
        }

        if outputFileForSource[workspaceKey] == nil {
            log("foo-6")
            outputFileForSource[workspaceKey] = [:]
        }

        guard (outputFileForSource[workspaceKey]?.count ?? 0) > 0 else {
            log("foo-7")
            return false
        }

        log("foo-8")
        return true
    }

    static func findOutputFileForSource(filePath: String, workingDir: String) -> String? {
        let sourceKey = filePath.replacingOccurrences(of: workingDir, with: "").replacingOccurrences(of: (bazelWorkingDir ?? ""), with: "")
        guard let workspaceKey = workspaceKey else {
            return nil
        }
        guard let workspaceMappings = outputFileForSource[workspaceKey] else {
            return nil
        }
        for (_, json) in workspaceMappings {
            if let objFilePath = json[sourceKey] {
                return objFilePath
            }
        }
        return nil
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

        log("wot: \(String(data: data, encoding: .ascii))")
        log("wot_decoded: \(decoder.decodeMessage())")
        if let msg = decoder.decodeMessage() {
            log("wot2: \(msg)")
            if let createSessionRequest = msg as? CreateSessionRequest {
                gXcode = createSessionRequest.xcode
                workspaceHash = createSessionRequest.workspaceHash
                workspaceName = createSessionRequest.workspaceName
                xcodeprojPath = createSessionRequest.xcodeprojPath
                xcbbuildService.startIfNecessary(xcode: gXcode)
            } else if msg is BuildStartRequest {
                do {
                    log("configBEPPath: \(configBEPPath)")
                    let bepPath = configBEPPath ?? "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }

                let message = BuildProgressUpdatedResponse()
                if let responseData = try? message.encode(encoder) {
                     bkservice.write(responseData)
                }
            } else if shouldHandleIndexing(msg: msg) {
                log("[INFO] Will attempt to handle indexing request")
                // Example of a custom indexing service
                let reqMsg = msg as! IndexingInfoRequested
                workingDir = bazelWorkingDir ?? reqMsg.workingDir
                platform = reqMsg.platform
                sdk = reqMsg.sdk
                
                guard let outputFilePath = findOutputFileForSource(filePath: reqMsg.filePath, workingDir: reqMsg.workingDir) else {
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
                    log("[INFO] Handle indexing request")
                    return
                }
            }
        }
        log("[INFO] Proxying request")
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
