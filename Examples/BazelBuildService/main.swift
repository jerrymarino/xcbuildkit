import BKBuildService
import Foundation
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

/// FIXME: support multiple workspaces
var gStream: BEPStream?

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

    static func fakeIndexingInfoRes() -> Data {
        let xml = """
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <array>
                <dict>
                    <key>outputFilePath</key>
                    <string>/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
                    <key>sourceFilePath</key>
                    <string>/Users/thiago/Development/xcbuildkit/iOSApp/CLI/main.m</string>
                </dict>
            </array>
        </plist>
        """
        guard let converter = BPlistConverter(xml: xml) else {
            fatalError("Failed to allocate converter")
        }
        guard let fakeData = converter.convertToBinary() else {
            fatalError("Failed to convert XML to binary plist data")
        }

        return fakeData
    }

    static let fakeTargetID = "a218dfee841498f4d1c86fb12905507da6b8608e8d79fa8addd22be62fee6ac8"

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
                xcbbuildService.startIfNecessary(xcode: createSessionRequest.xcode)
            } else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }
            } else if msg is IndexingInfoRequested {
                let message = IndexingInfoReceivedResponse(targetID: fakeTargetID, data: fakeIndexingInfoRes())
                if let responseData = try? message.encode(encoder) {
                    bkservice.write(responseData)
                }
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
