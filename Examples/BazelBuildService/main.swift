import BKBuildService
import Foundation
import MessagePack
import XCBProtocol

struct BasicResponseContext {
    let xcbbuildService: XCBuildServiceProcess
    let bkservice: BKBuildService
}

import BEP
import SwiftProtobuf

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
/// Perhaps, we might beable to just intelligently parse bazel's stdout
/// skip the BEP altogether, which could servce as a simple
/// example, and drop in replacement for Bazel users.
///
/// e.g. [x / n] tasks

enum BasicResponseHandler {
    static func startWatcher(path _: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startWatcher " + String(describing: startBuildInput))
        let bepPath = "/tmp/bep.bep"
        // TODO: we probably can use a better solution to not dump the first build
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
        var v = input
        guard case let .uint(id) = v.next() else {
            fatalError("missing id")
        }
        let basicCtx = context as! BasicResponseContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input)

        // FIXME: move over to a switch ( and actual data types )
        // to the original build service which make
        if let msg = decoder.decodeMessage() {
            if msg is CreateSessionRequest {
                // Xcode's internal build system needs to be initialized
                // TODO: this has a dependency of CreateSessionRequest.
                xcbbuildService.start()
            } else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startWatcher(path: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init watcher" + error.localizedDescription)
                }

                /// Just dump
                let encoder = XCBEncoder(input: input)
                let response = BuildProgressUpdatedResponse()
                bkservice.write(try! response.encode(encoder))
                xcbbuildService.write(data)
                return
            }
        }
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicResponseContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(responseHandler: BasicResponseHandler.respond, context: context)
