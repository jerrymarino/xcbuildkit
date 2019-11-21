import BKBuildService
import Foundation
import MessagePack
import XCBProtocol
import BEP
import SwiftProtobuf

struct BasicResponseContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

public typealias BEPReadHandler = (BuildEventStream_BuildEvent) -> Void

public class BEPWatcher {
    private let readQueue = DispatchQueue(label: "com.bkbuildservice.bepwatcher")
    private let path: String
    private var input: InputStream!
    private var lastMTime: TimeInterval?

    public init(path: String) throws {
        self.path = path
    }

    public func read(eventAvailableHandler handler: @escaping BEPReadHandler) throws {
        input = InputStream(fileAtPath: path)!
        readQueue.async {
            self.input.open()
            self.readLoop(eventAvailableHandler: handler)
        }
    }

    func hasChanged() -> Bool {
        let url = URL(fileURLWithPath: path)
        let resourceValues = try? url.resourceValues(forKeys:
            Set([.contentModificationDateKey]))
        let mTime = resourceValues?.contentModificationDate?.timeIntervalSince1970 ?? 0
        if mTime != lastMTime {
            lastMTime = mTime
            return true
        }
        return false
    }

    public func readLoop(eventAvailableHandler handler: @escaping BEPReadHandler) {
        while true {
            if input.hasBytesAvailable {
                do {
                    let info = try BinaryDelimited.parse(messageType:
                        BuildEventStream_BuildEvent.self, from: input)
                    handler(info)
                } catch {
                    // FIXME: differentiate between failed messages and not
                    log("BEPReadError" + error.localizedDescription)
                    input.close()
                }
            } else {
                // If the stream is all done, then we'll throw it out and make a new one
                if hasChanged() {
                    /// At this point, read _must_ be working
                    try! read(eventAvailableHandler: handler)
                    return
                }
                sleep(1)
            }
        }
    }
}

var gWatcher: BEPWatcher?

/// This example listens to a BEP stream to display some output.
///
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
///
/// Perhaps, we might may instead intelligently parse bazel's stdout
/// skip the BEP altogether, which could servce as a simple
/// drop in replacement for all Bazel users.
///
/// Some people may implement this in a way to remove runscripts.
///
/// e.g. [x / n] tasks

enum BasicResponseHandler {
    static func startWatcher(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startWatcher " + String(describing: startBuildInput))
        // FIXME: find a better solution to not delete the BEP first!
        try? FileManager.default.removeItem(atPath: bepPath)
        let watcher = try BEPWatcher(path: bepPath)
        var lastProgress: Int32 = 0
        try watcher.read {
            info in
            let count = info.id.progress.opaqueCount
            if count != 0, (count % 2) == 0 {
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
        gWatcher = watcher
    }

    static func respond(input: XCBInputStream, data: Data, context: Any?) {
        let basicCtx = context as! BasicResponseContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                xcbbuildService.startIfNecessary(xcode: createSessionRequest.xcode)
            } else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startWatcher(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init watcher" + error.localizedDescription)
                }

                let encoder = XCBEncoder(input: input)
                let response = BuildProgressUpdatedResponse()
                bkservice.write(try! response.encode(encoder))
            }
        }
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicResponseContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(responseHandler: BasicResponseHandler.respond, context: context)
