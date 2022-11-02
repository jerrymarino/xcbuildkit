import BKBuildService
import Foundation
import XCBProtocol
import BEP

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

/// FIXME: support multiple workspaces
var gStream: BEPStream?
// Example of what source => object file under bazel-out mapping should look like:
//
// "Test-XCBuildKit-cdwbwzghpxmnfadvmmhsjcdnjygy": [
//     "App_source_output_file_map.json": [
//         "/tests/ios/app/App/main.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/main.o",
//         "/tests/ios/app/App/Foo.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/Foo.o",
//     ],
// ],
private var outputFileForSource: [String: [String: [String: String]]] = [:]
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
// Path to .xcodeproj, used to load xcbuildkit config file from path/to/foo.xcodeproj/xcbuildkit.config
private var xcodeprojPath: String = ""
// Load configs from path/to/foo.xcodeproj/xcbuildkit.config
private var configValues: [String: Any]? {
    guard let data = try? String(contentsOfFile: xcbuildkitConfigPath, encoding: .utf8) else { return nil }

    let lines = data.components(separatedBy: .newlines)
    var dict: [String: Any] = [:]
    for line in lines {
        let split = line.components(separatedBy: "=")
        guard split.count == 2 else { continue }
        dict[split[0]] = split[1]
    }
    return dict
}
// File containing config values that a consumer can set, see accepted keys below.
// Format is KEY=VALUE and one config per line
// TODO: Probably better to make this a separate struct with proper validation but will do that
// once the list of accepted keys is stable
private var xcbuildkitConfigPath: String {
    return "\(xcodeprojPath)/xcbuildkit.config"
}
private var indexingEnabled: Bool {
    return (configValues?["BUILD_SERVICE_INDEXING_ENABLED"] as? String ?? "") == "YES"
}
// Directory containing data used to fast load information when initializing BazelBuildService, e.g.,
// .json files containing source => output file mappings generated during Xcode project generation
private var xcbuildkitDataDir: String? {
    return configValues?["BUILD_SERVICE_INDEXING_DATA_DIR"] as? String
}
private var progressBarEnabled: Bool {
    return (configValues?["BUILD_SERVICE_PROGRESS_BAR_ENABLED"] as? String ?? "") == "YES"
}
private var configBEPPath: String? {
    return configValues?["BUILD_SERVICE_BEP_PATH"] as? String
}
private var sourceOutputFileMapSuffix: String? {
    return configValues?["BUILD_SERVICE_SOURCE_OUTPUT_FILE_MAP_SUFFIX"] as? String
}
private var bazelWorkingDir: String? {
    return configValues?["BUILD_SERVICE_BAZEL_EXEC_ROOT"] as? String
}

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    // Read info from BEP and optionally handle events
    static func startStream(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startStream " + String(describing: startBuildInput))
        let stream = try BEPStream(path: bepPath)
        var progressView: ProgressView?
        try stream.read {
            event in
            if indexingEnabled {
                parseSourceOutputFileMappingsFromBEP(event: event)
            }

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
    // Check many conditions that need to be met in order to handle indexing and returns the respect output file,
    // the call site should abort and proxy the indexing request if this returns `nil`
    static func canHandleIndexingWithOutfile(msg: XCBProtocolMessage) -> String? {
        // Nothing to do for non-indexing request types
        guard let reqMsg = msg as? IndexingInfoRequested else {
            return nil
        }
        // Nothing to do if indexing is disabled
        guard indexingEnabled else {
            return nil
        }
        // TODO: handle Swift
        guard reqMsg.filePath.count > 0 && reqMsg.filePath != "<garbage>" && !reqMsg.filePath.hasSuffix(".swift") else {
            log("[WARNING] Unsupported filePath for indexing: \(reqMsg.filePath)")
            return nil
        }
        // In `BazelBuildService` the path to the working directory (i.e. execution_root) should always
        // exists
        guard bazelWorkingDir != nil else {
            log("[WARNING] Could not find bazel working directory. Make sure `BUILD_SERVICE_BAZEL_EXEC_ROOT` is set in the config file.")
            return nil
        }

        guard let outputFilePath = findOutputFileForSource(filePath: reqMsg.filePath, workingDir: reqMsg.workingDir) else {
            log("[WARNING] Failed to find output file for source: \(reqMsg.filePath). Indexing requests will be proxied to default build service.")
            return nil
        }

        return outputFilePath
    }
    // Initialize in memory mappings from xcbuildkitDataDir if .json mappings files exist
    static func initializeOutputFileMappingFromCache() {
        guard let xcbuildkitDataDir = xcbuildkitDataDir else { return }
        let fm = FileManager.default
        do {
            let jsons = try fm.contentsOfDirectory(atPath: xcbuildkitDataDir)

            for jsonFilename in jsons {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: "\(xcbuildkitDataDir)/\(jsonFilename)"))
                loadSourceOutputFileMappingInfo(jsonFilename: jsonFilename, jsonData: jsonData)
            }
        } catch {
            log("[ERROR] Failed to initialize from cache under \(xcbuildkitDataDir) with err: \(error.localizedDescription)")
        }
    }
    // Loads information into memory and optionally update the cache under xcbuildkitDataDir
    static func loadSourceOutputFileMappingInfo(jsonFilename: String, jsonData: Data, updateCache: Bool = false) {
        // Ensure workspace info is ready and .json can be decoded
        guard let workspaceKey = workspaceKey else { return }
        guard let xcbuildkitDataDir = xcbuildkitDataDir else { return }
        guard let jsonValues = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [String: String] else { return }

        // Load .json contents into memory
        initializeOutputFileForSourceIfNecessary(jsonFilename: jsonFilename)
        outputFileForSource[workspaceKey]?[jsonFilename] = jsonValues
        log("[INFO] Loaded mapping information into memory for file: \(jsonFilename)")

        // Update .json files cached under xcbuildkitDataDir for
        // fast load next time we launch Xcode
        if updateCache {
            do {
                guard let jsonBasename = jsonFilename.components(separatedBy: "/").last else { return }
                let jsonFilePath = "\(xcbuildkitDataDir)/\(jsonBasename)"
                let json = URL(fileURLWithPath: jsonFilePath)
                let fm = FileManager.default
                if fm.fileExists(atPath: jsonFilePath) {
                    try fm.removeItem(atPath: jsonFilePath)
                }
                try jsonData.write(to: json)
                log("[INFO] Updated cache for file \(jsonFilePath)")
            } catch {
                log("[ERROR] Failed to update cache under \(xcbuildkitDataDir) for file \(jsonFilename) with err: \(error.localizedDescription)")
            }
        }
    }
    // This loop looks for JSON files with a known suffix `BUILD_SERVICE_SOURE_OUTPUT_FILE_MAP_SUFFIX` and loads the mapping
    // information from it decoding the JSON and storing in-memory.
    //
    // Read about the 'namedSetOfFiles' key here: https://bazel.build/remote/bep-examples#consuming-namedsetoffiles
    static func parseSourceOutputFileMappingsFromBEP(event: BuildEventStream_BuildEvent) {
        // Do work only if `namedSetOfFiles` is present and contain `files`
        guard let json = try? JSONSerialization.jsonObject(with: event.jsonUTF8Data(), options: []) as? [String: Any] else { return }
        guard let namedSetOfFiles = json["namedSetOfFiles"] as? [String: Any] else { return }
        guard namedSetOfFiles.count > 0 else { return }
        guard let allPairs = namedSetOfFiles["files"] as? [[String: Any]] else { return }

        for pair in allPairs {
            // Only proceed if top level keys exist and a .json to be decoded is found
            guard let jsonFilename = pair["name"] as? String else { continue }
            guard var jsonURI = pair["uri"] as? String else { continue }
            guard jsonURI.hasSuffix(".json") else { continue }

            jsonURI = jsonURI.replacingOccurrences(of: "file://", with: "")

            // Only proceed for keys holding .json files with known pattern (i.e. `BUILD_SERVICE_SOURE_OUTPUT_FILE_MAP_SUFFIX`) in the name
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath:jsonURI)) else { continue }
            guard jsonData.count > 0 else { continue }
            guard let jsonDecoded = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [String: String] else { continue }
            guard let sourceOutputFileMapSuffix = sourceOutputFileMapSuffix else { continue }
            guard let workspaceKey = workspaceKey, jsonFilename.hasSuffix(sourceOutputFileMapSuffix) else { continue }

            // Load .json contents into memory
            log("[INFO] Parsed \(jsonFilename) from BEP.")
            loadSourceOutputFileMappingInfo(jsonFilename: jsonFilename, jsonData: jsonData, updateCache: true)
        }
    }
    // Helper to initialize in-memory mapping for workspace and give .json mappings file key
    static func initializeOutputFileForSourceIfNecessary(jsonFilename: String) {
        guard let workspaceKey = workspaceKey else { return }

        if outputFileForSource[workspaceKey] == nil {
            outputFileForSource[workspaceKey] = [:]
        }
        if outputFileForSource[workspaceKey]?[jsonFilename] == nil {
            outputFileForSource[workspaceKey]?[jsonFilename] = [:]
        }
    }
    // Finds output file (i.e. path to `.o` under `bazel-out`) in in-memory mapping
    static func findOutputFileForSource(filePath: String, workingDir: String) -> String? {
        // Create key
        let sourceKey = filePath.replacingOccurrences(of: workingDir, with: "").replacingOccurrences(of: (bazelWorkingDir ?? ""), with: "")
        // Ensure workspace info is loaded and mapping exists
        guard let workspaceKey = workspaceKey else { return nil }
        guard let workspaceMappings = outputFileForSource[workspaceKey] else { return nil }
        // Loops until found
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
        let identifier = input.identifier ?? ""

        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                // Load information from `CreateSessionRequest`
                gXcode = createSessionRequest.xcode
                workspaceHash = createSessionRequest.workspaceHash
                workspaceName = createSessionRequest.workspaceName
                xcodeprojPath = createSessionRequest.xcodeprojPath

                // Initialize build service
                xcbbuildService.startIfNecessary(xcode: gXcode)

                // Start reading from BEP as early as possible
                do {
                    let bepPath = configBEPPath ?? "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }

                // Load output file mapping information from cache if it exists
                initializeOutputFileMappingFromCache()
            } else if msg is BuildStartRequest {
                // Attempt to initialize in-memory mapping if empty
                // It's possible that indexing data is not ready yet in `CreateSessionRequest` above
                // so retry to load info into memory at `BuildStartRequest` time
                if let workspaceKey = workspaceKey {
                    if (outputFileForSource[workspaceKey]?.count ?? 0) == 0 {
                        initializeOutputFileMappingFromCache()
                    }
                }

                let message = BuildProgressUpdatedResponse()
                if let responseData = try? message.encode(encoder) {
                     bkservice.write(responseData)
                }
            } else if let outputFilePath = canHandleIndexingWithOutfile(msg: msg) {
                // Settings values needed to compose the payload below
                let reqMsg = msg as! IndexingInfoRequested
                workingDir = bazelWorkingDir ?? reqMsg.workingDir
                platform = reqMsg.platform
                sdk = reqMsg.sdk

                // Compose the indexing response payload and emit the response message
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
                    log("[INFO] Handling \(identifier) for source \(reqMsg.filePath) and output file \(outputFilePath)")
                    return
                }
            }
        }
        log("[INFO] Proxying request with type: \(identifier)")
        if indexingEnabled && identifier == "INDEXING_INFO_REQUESTED" {
            log("[WARNING] BazelBuildService failed to handle indexing request, message will be proxied instead.")
            // If we hit this means that something went wrong with indexing, logging this in-memory mapping is useful for troubleshooting
            log("[INFO] outputFileForSource: \(outputFileForSource)")
        }
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
