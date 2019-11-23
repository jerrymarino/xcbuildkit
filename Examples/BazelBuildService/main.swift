import BEP
import BKBuildService
import Foundation
import MessagePack
import SwiftProtobuf
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

var gStream: BEPStream?

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    // Look for progress like [22/ 228]
    // reference src/main/java/com/google/devtools/build/lib/buildtool/ExecutionProgressReceiver.java
    static func extractUIProgress(progressStderr: String) -> (Int32, Int32) {
        var ranActions: Int32 = 0
        var totalActions: Int32 = 0
        if progressStderr.first == "[" {
            var numberStrings: [String] = []
            var accum = ""
            for x in progressStderr {
                if x == "[" {
                    continue
                } else if x == "]" {
                    numberStrings.append(accum)
                    break
                } else if x == " " || x == "/" {
                    if accum.count > 0 {
                        numberStrings.append(accum)
                        accum = ""
                    }
                } else {
                    accum.append(x)
                }
            }
            if numberStrings.count == 2 {
                ranActions = Int32(numberStrings[0]) ?? 0
                totalActions = Int32(numberStrings[1]) ?? 0
            }
        }

        return (ranActions, totalActions)
    }

    static func startStream(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startStream " + String(describing: startBuildInput))
        try? FileManager.default.removeItem(atPath: bepPath)
        let stream = try BEPStream(path: bepPath)

        // Track progress state here.
        var lastProgress: Int32 = 0
        var lastTotalActions: Int32 = 0
        var lastCount: Int32 = 0
        try stream.read {
            info in
            let count = info.id.progress.opaqueCount
            guard count > 0 else {
                return
            }
            let progressStderr = info.progress.stderr
            let (ranActions, totalActions) = extractUIProgress(progressStderr: progressStderr)
            var baseProgress: Int32
            if ranActions == 0 {
                // Update the base progress with the last progress. This is
                // a synthetic number. Bazel will not update for all actions
                baseProgress = lastProgress + (count - lastCount)
            } else {
                baseProgress = ranActions
            }

            let progressTotalActions = max(lastTotalActions, totalActions)
            let progress = min(progressTotalActions, max(lastProgress, baseProgress))
            // Don't notify for the same progress more than once.
            if progress == lastProgress, progressTotalActions == lastTotalActions {
                return
            }

            var message: String
            var progressPercent: Double = -1.0
            if progressTotalActions > 0 {
                message = "\(progress) of \(progressTotalActions) tasks"
                // Very early on in a build, totalActions is not fully computed, and if we set it here
                // the progress bar will jump to 100. Leave it at -1.0 until we get further along.
                // Generally, for an Xcode target there will be a codesign, link, and compile action.
                // Consider using a timestamp as an alternative?
                if progressTotalActions > 5 {
                    progressPercent = (Double(progress) / Double(progressTotalActions)) * 100.0
                }
            } else if progressStderr.count > 28 {
                // Any more than this and it crashes or looks bad.
                // If Bazel hasn't reported anything resonable yet, then it's likely
                // likely still analyzing. Render Bazels message
                message = String(progressStderr.prefix(28)) + ".."
            } else {
                // This is really undefined behavior but render the count.
                message = "Updating \(progress)"
            }

            // At the last message, update to 100%
            if info.lastMessage {
                progressPercent = 99.0
            }

            log("BEPNotifyProgress: " + message)
            lastProgress = progress
            lastTotalActions = progressTotalActions
            lastCount = count

            let encoder = XCBEncoder(input: startBuildInput)
            let response = BuildProgressUpdatedResponse(progress: progressPercent, message: message)
            bkservice.write(try! response.encode(encoder))
        }
        gStream = stream
    }

    /// Proxying response handler
    /// Every message is written to the XCBBuildService
    /// This simply injects Progress messages from the BEP
    static func respond(input: XCBInputStream, data: Data, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                xcbbuildService.startIfNecessary(xcode: createSessionRequest.xcode)
            } else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }

                let encoder = XCBEncoder(input: input)
                let message = BuildProgressUpdatedResponse()
                bkservice.write(try! message.encode(encoder))
            }
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
