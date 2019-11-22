import BKBuildService
import Foundation
import MessagePack
import XCBProtocol
import BEP
import SwiftProtobuf

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
    static func startStream(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startStream " + String(describing: startBuildInput))
        // FIXME: find a better solution to not delete the BEP first!
        try? FileManager.default.removeItem(atPath: bepPath)
        let stream = try BEPStream(path: bepPath)
        var lastProgress: Int32 = 0
        try stream.read {
            info in
            let count = info.id.progress.opaqueCount
            if count != 0 {
                // We cannot notify for the same progress more than once.
                // If the build has completed, then we need to stop sending progress
                // Under a hybrid BuildService, we don't govern that last message
                // and may need to parse the output
                let progress = max(lastProgress, count)
                if progress == lastProgress {
                    return
                }
                log("BEPNotifyProgress" + String(describing: count))
                let message = "Built \(progress) tasks"
                let encoder = XCBEncoder(input: startBuildInput)
                let response = BuildProgressUpdatedResponse(message: message)
                lastProgress = progress
                bkservice.write(try! response.encode(encoder))
            }
        }
        gStream = stream
    }

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
