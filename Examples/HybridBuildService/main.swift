/*
Copyright (c) 2022, XCBuildKit contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of the IDEXCBProgress project.
*/

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
    static func respond(input: XCBInputStream, data: Data, msgId: UInt64, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input, msgId: msgId)
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

log("Start service - HybridBuildService")
bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
