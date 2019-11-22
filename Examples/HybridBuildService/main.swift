import BKBuildService
import Foundation
import MessagePack
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

// This is an example build service that implements the build portion
// all other messages and operations are handled by XCBuild
enum BasicMessageHandler {
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
                bkservice.write(try! BuildStartResponse().encode(encoder))

                // Planning is optional
                bkservice.write(try! PlanningOperationWillStartResponse().encode(encoder))
                bkservice.write(try! BuildProgressUpdatedResponse().encode(encoder))
                bkservice.write(try! PlanningOperationWillEndResponse().encode(encoder))

                bkservice.write(try! BuildOperationEndedResponse().encode(encoder))
            } else {
                xcbbuildService.write(data)
            }
        } else {
            xcbbuildService.write(data)
        }
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
