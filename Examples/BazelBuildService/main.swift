import BKBuildService
import Foundation
import XCBProtocol
import BEP

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
    let indexingService: IndexingService
    let bepService: BEPService
}

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    /// Proxying response handler
    /// Every message is written to the XCBBuildService
    /// This simply injects Progress messages from the BEP
    static func respond(input: XCBInputStream, data: Data, msgId: UInt64, context: Any?) {
        let ctx = context as! BasicMessageContext
        let xcbbuildService = ctx.xcbbuildService
        let bkservice = ctx.bkservice
        let indexingService = ctx.indexingService
        let bepService = ctx.bepService
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input, msgId: msgId)
        let identifier = input.identifier ?? ""

        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                // Initialize workspace info for the current workspace
                let workspaceInfo = WorkspaceInfo(
                    xcode: createSessionRequest.xcode,
                    workspaceName: createSessionRequest.workspaceName,
                    workspaceHash: createSessionRequest.workspaceHash,
                    xcodeprojPath: createSessionRequest.xcodeprojPath
                )
                indexingService.infos[createSessionRequest.workspaceKey] = workspaceInfo
                log("[INFO] Loaded xcbuildkit config: \(workspaceInfo.config)")

                // Initialize build service
                xcbbuildService.startIfNecessary(xcode: workspaceInfo.xcode)

                // Initialize indexing information
                indexingService.initializeOutputFileMappingFromCache(msg: createSessionRequest)
            } else if msg is BuildStartRequest {
                let message = BuildProgressUpdatedResponse()
                if let responseData = try? message.encode(encoder) {
                     bkservice.write(responseData)
                }
            } else if let createBuildRequest = msg as? CreateBuildRequest, let workspaceInfo = indexingService.infos[createBuildRequest.workspaceKey] {
                log("[INFO] Creating build with config: \(workspaceInfo.config)")

                // Start streaming from the BEP
                if let bepPath = workspaceInfo.config.configBEPPath {
                    do {
                        try bepService.startStream(msg: createBuildRequest, bepPath: bepPath, startBuildInput: input, msgId: msgId, ctx: ctx)
                    } catch {
                        log("[ERROR] Failed to start BEP stream with error: " + error.localizedDescription)
                    }
                } else {
                    log("[WARNING] BEP string config key 'BUILD_SERVICE_BEP_PATH' empty. Bazel information won't be available during a build.")
                }

                // This information was not explicitly available in `CreateSessionRequest`, parse from `CreateBuildRequest` instead
                // Necessary for indexing and potentially for other things in the future. This is effectively $SRCROOT.
                workspaceInfo.workingDir = createBuildRequest.workingDir
                workspaceInfo.derivedDataPath = createBuildRequest.derivedDataPath
                workspaceInfo.indexDataStoreFolderPath = createBuildRequest.indexDataStoreFolderPath
                workspaceInfo.targetConfiguration = createBuildRequest.configuration

                // Attempt to initialize in-memory mapping if empty
                // It's possible that indexing data is not ready yet in `CreateSessionRequest` above
                if workspaceInfo.outputFileForSource.count == 0 {
                    indexingService.initializeOutputFileMappingFromCache(msg: createBuildRequest)
                }

                // Setup DataStore for indexing with Bazel
                indexingService.setupDataStore(msg: createBuildRequest)
            } else if let indexingInfoRequest = msg as? IndexingInfoRequested,
                      let outputFilePath = indexingService.indexingOutputFilePath(msg: indexingInfoRequest),
                      let workspaceInfo = indexingService.infos[indexingInfoRequest.workspaceKey] {
                // Compose the indexing response payload and emit the response message
                // Note that information is combined from different places (workspace info, incoming indexing request, indexing service helper methods)
                let compilerInvocationData = BazelBuildServiceStub.getASTArgs(
                    isSwift: indexingInfoRequest.filePath.hasSuffix(".swift"),
                    targetID: indexingInfoRequest.targetID,
                    sourceFilePath: indexingInfoRequest.filePath,
                    outputFilePath: outputFilePath,
                    derivedDataPath: workspaceInfo.derivedDataPath,
                    workspaceHash: workspaceInfo.workspaceHash,
                    workspaceName: workspaceInfo.workspaceName,
                    sdkPath: ctx.indexingService.sdkPath(msg: indexingInfoRequest),
                    sdkName: indexingInfoRequest.sdk,
                    workingDir: workspaceInfo.config.bazelWorkingDir ?? workspaceInfo.workingDir,
                    configuration: workspaceInfo.targetConfiguration,
                    platform: indexingInfoRequest.platform)

                let message = IndexingInfoReceivedResponse(
                    targetID: indexingInfoRequest.targetID,
                    data: indexingInfoRequest.outputPathOnly ? BazelBuildServiceStub.outputPathOnlyData(outputFilePath: outputFilePath, sourceFilePath: indexingInfoRequest.filePath) : nil,
                    responseChannel: UInt64(indexingInfoRequest.responseChannel),
                    compilerInvocationData: indexingInfoRequest.outputPathOnly ? nil : compilerInvocationData)

                if let encoded: XCBResponse = try? message.encode(encoder) {
                    bkservice.write(encoded, msgId:message.responseChannel)
                    log("[INFO] Handling \(identifier) for source \(indexingInfoRequest.filePath) and output file \(outputFilePath)")
                    return
                }
            }
        }
        log("[INFO] Proxying request with type: \(identifier)")
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()
let indexingService = IndexingService()
let bepService = BEPService()

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice,
    indexingService: indexingService,
    bepService: bepService
)

bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
