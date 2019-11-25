import BEP
import Foundation
import SwiftProtobuf
import XCBProtocol

public typealias BEPReadHandler = (BuildEventStream_BuildEvent) -> Void

public class BEPStream {
    private let readQueue = DispatchQueue(label: "com.bkbuildservice.bepstream")
    private let path: String
    private var input: InputStream!
    private var lastMTime: TimeInterval?
    private var hitLastMessage: Bool = false

    /// @param path - Binary BEP file
    /// this is passed to Bazel via --build_event_binary_file
    public init(path: String) throws {
        self.path = path
    }

    /// Reads data from a BEP stream
    /// @param eventAvailableHandler - this is called with _every_ BEP event
    /// available
    public func read(eventAvailableHandler handler: @escaping BEPReadHandler) throws {
        input = InputStream(fileAtPath: path)!
        readQueue.async {
            self.input.open()
            self.readLoop(eventAvailableHandler: handler)
        }
    }

    private func readLoop(eventAvailableHandler handler: @escaping BEPReadHandler) {
        while !hitLastMessage {
            if input.hasBytesAvailable {
                do {
                    let info = try BinaryDelimited.parse(messageType:
                        BuildEventStream_BuildEvent.self, from: input)
                    handler(info)

                    // When we hit the last message close the stream and end
                    if info.lastMessage {
                        hitLastMessage = true
                        input.close()
                        break
                    }
                } catch {
                    log("BEPReadError" + error.localizedDescription)
                    input.close()
                }
            } else {
                // Wait until the BEP file is available
                // FIXME: replace polling with kqueue or better
                if hasChanged() {
                    try! read(eventAvailableHandler: handler)
                    return
                }
                sleep(1)
            }
        }
    }

    private func hasChanged() -> Bool {
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
}
