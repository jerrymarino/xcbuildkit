import BKBuildService
import Foundation
import MessagePack
import XCBProtocol

struct BasicMessageContext {
    let bkservice: BKBuildService
}

/// This message handler is a *minimal* but complete implementation of an
/// XCBBuildService. All messages from Xcode are handled internally and XCBuild
/// is not used
enum BasicMessageHandler {
    static func respond(input: XCBInputStream, data _: Data, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input)
        if let msg = decoder.decodeMessage() {
            if msg is CreateSessionRequest {
                bkservice.write(try! CreateSessionResponse().encode(encoder))
            } else if msg is TransferSessionPIFRequest {
                bkservice.write(try! TransferSessionPIFResponse().encode(encoder))
            } else if msg is SetSessionSystemInfoRequest {
                bkservice.write(try! SetSessionSystemInfoResponse().encode(encoder))
            } else if msg is SetSessionUserInfoRequest {
                bkservice.write(try! SetSessionUserInfoResponse().encode(encoder))
            } else if msg is CreateBuildRequest {
                bkservice.write(try! CreateBuildResponse().encode(encoder))
            } else if msg is BuildStartRequest {
                bkservice.write(try! BuildStartResponse().encode(encoder))

                // Planning is optional
                bkservice.write(try! PlanningOperationWillStartResponse().encode(encoder))
                bkservice.write(try! BuildProgressUpdatedResponse().encode(encoder))
                bkservice.write(try! PlanningOperationWillEndResponse().encode(encoder))

                bkservice.write(try! BuildOperationEndedResponse().encode(encoder))
            } else if msg is IndexingInfoRequested {
                // Indexing only works in hybrid mode
                // ( Examples/HybridBuildService )
                fatalError("""
                indexing unsupported in static mode set
                defaults write com.apple.dt.XCode IDEIndexDisable 1
                """)
            }
        }
    }
}

// main
log("Start service - BSBuildService")
let bkservice = BKBuildService()
let context = BasicMessageContext(bkservice: bkservice)
bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
