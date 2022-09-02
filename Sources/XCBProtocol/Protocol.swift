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

/// Implements a XCBProtocol Messages
/// Many of these types are synthetic, high level representations of messages
/// derived from Xcode
import Foundation
import MessagePack

/// This protocol version represents the _Major_ version of Xcode that it was
/// tested with. Minor and Fix versions are unaccounted for due to excellent
/// compatibility across releases
let XCBProtocolVersion = "11"

/// Current build number. None of this is expected to be thread safe and Xcode
/// is forced to use J=1 ( IDEBuildOperationMaxNumberOfConcurrentCompileTasks )
/// for debugging and development purposes
/// -1 means we haven't built yet
///
// TODO: this isn't really useful to make public, but it's super hacky
/// find a better solution
private var gBuildNumber: Int64 = -1

private extension XCBEncoder {
    func getResponseMsgId(subtracting  offset: UInt64) throws -> UInt64 {
        // Consider finding ways to mitigate unexpected input in upstream code.
        // There may be possible ways that unexpected messages will make it this
        // far. Guard against possible integer underflow
        let id = try getMsgId()
        guard id >= offset else {
            log("bad offset for msg: " + String(describing: self.input))
            throw XCBProtocolError.unexpectedInput(for: self.input)
        }
        return id - offset
    }
}

public struct CreateSessionRequest: XCBProtocolMessage {
    public let workspace: String
    public let workspaceName: String
    public let workspaceHash: String
    public let xcode: String
    public let xcbuildDataPath: String

    init(input: XCBInputStream) throws {
        var minput = input

        /// Perhaps this shouldn't fatal error
        guard let next = minput.next(),
            case let .array(msgInfo) = next,
            msgInfo.count > 2 else {
            throw XCBProtocolError.unexpectedInput(for: input)
        }

        if case let .string(workspaceInfo) = msgInfo[0] {
            self.workspace = workspaceInfo
        } else {
            self.workspace = ""
        }

        if case let .string(xcode) = msgInfo[1] {
            self.xcode = xcode
        } else {
            self.xcode = ""
        }

        if case let .string(xcbuildDataPath) = msgInfo[2] {
            self.xcbuildDataPath = xcbuildDataPath
        } else {
            self.xcbuildDataPath = ""
        }

        // TODO: This is hacky, just an initial approach for better DX for now. Find a better way.
        //
        // `self.xcbuildDataPath` looks something like this (not that `/path/to/DerivedData` can also be a custom path):
        //
        // /path/to/DerivedData/iOSApp-frhmkkebaragakhdzyysbrsvbgtc/Build/Intermediates.noindex/XCBuildData
        //
        var componentsByDash = self.xcbuildDataPath.components(separatedBy: "-")
        let wHash = componentsByDash.last!.components(separatedBy: "/").first!
        self.workspaceHash = wHash
        var componentsByForwardSlash = self.xcbuildDataPath.components(separatedBy: "/")
        var workspaceNameComponent = componentsByForwardSlash.filter { $0.contains(wHash) }.first as! String
        var workspaceNameComponentsByDash = workspaceNameComponent.components(separatedBy: "-")
        workspaceNameComponentsByDash.removeLast()
        self.workspaceName = String(workspaceNameComponentsByDash.joined(separator: "-"))

        log("Found XCBuildData path: \(self.xcbuildDataPath)")
        log("Parsed workspaceHash: \(self.workspaceHash)")
        log("Parsed workspaceName: \(self.workspaceName)")
    }
}

/// Input "Request" Messages
public struct TransferSessionPIFRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct TransferSessionPIFObjectsLegacyRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct SetSessionSystemInfoRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct SetSessionUserInfoRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct CreateBuildRequest: XCBProtocolMessage {
    public let configuredTargets: [String]
    public init(input: XCBInputStream) throws {
        var minput = input
        guard let next = minput.next(),
            case let .binary(jsonData) = next else {
            throw XCBProtocolError.unexpectedInput(for: input)
        }
         guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw XCBProtocolError.unexpectedInput(for: input)
         }
         let requestJSON = json["request"] as? [String: Any] ?? [:]
         if let ct = requestJSON["configuredTargets"] as? [[String: Any]] { 
             self.configuredTargets = ct.compactMap { ctInfo in
                 return ctInfo["guid"] as? String
             }
             log("info: got configured targets \(self.configuredTargets)")
         } else {
             log("warning: malformd configured targets\(json["configuredTargets"])")
             self.configuredTargets = []
         }
    }
}

public struct BuildStartRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct BuildDescriptionTargetInfo: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct DocumentationInfoRequested: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}
extension Data {
    /// Same as ``Data(base64Encoded:)``, but adds padding automatically
    /// (if missing, instead of returning `nil`).
    public static func fromBase64(_ encoded: String) -> Data? {
        // Prefixes padding-character(s) (if needed).
        var encoded = encoded;
        let remainder = encoded.count % 4
        if remainder > 0 {
            encoded = encoded.padding(
                toLength: encoded.count + 4 - remainder,
                withPad: "=", startingAt: 0);
        }

        // Finally, decode.
        return Data(base64Encoded: encoded);
    }
}
public struct IndexingInfoRequested: XCBProtocolMessage {
    /// These messages are virtually JSON blob
    ///
    /// From a higher level they mean different things.
    /// code directly here for now, consider adding an enum object or other rep
    
    public let responseChannel: Int64
    public let targetID: String
    public let outputPathOnly: Bool
    public let filePath: String
    public let derivedDataPath: String
    public let workingDir: String
    public let sdk: String
    public let platform: String

    public init(input: XCBInputStream) throws {
        var minput = input
        var jsonDataOg: Data?

        while let fooNext = minput.next() {
            if jsonDataOg != nil {
                break
            }

            switch fooNext {
                case let .binary(jsonDataFoo):
                    jsonDataOg = jsonDataFoo
                default:
                    continue
            }            
        }

        guard let jsonData = jsonDataOg else {
            // Hack - fix upstream code
            self.targetID = "_internal_stub_"
            self.filePath = "_internal_stub_"
            self.outputPathOnly = false
            self.responseChannel = -1
            self.derivedDataPath = ""
            self.workingDir = ""
            self.sdk = ""
            self.platform = ""
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw XCBProtocolError.unexpectedInput(for: input)
        }
        guard let targetID = json["targetID"] else {
           throw XCBProtocolError.unexpectedInput(for: input)
        }
        // Assigning this to garbage as a debug mechanism
        self.targetID = targetID as? String ?? "<garbage>"
        self.responseChannel = json["responseChannel"] as? Int64 ?? 0
        self.filePath = json["filePath"] as? String ?? "<garbage>"
        self.outputPathOnly = json["outputPathOnly"] as? Bool ?? false

        let requestJSON = json["request"] as? [String: Any] ?? [:]

        // Remove last word of `$PWD/iOSApp/iOSApp.xcodeproj` to get `workingDir`
        let containerPath = requestJSON["containerPath"] as? String ?? ""
        // self.workingDir = Array(containerPath.components(separatedBy: "/").dropLast()).joined(separator: "/")
        if self.filePath.contains("main.m") {
            self.workingDir = "/private/var/tmp/_bazel_thiago/122885c1fe4a2c6ed7635584956dfc9d/execroot/build_bazel_rules_ios"
        } else {
            self.workingDir = "/private/var/tmp/_bazel_thiago/122885c1fe4a2c6ed7635584956dfc9d/execroot/build_bazel_rules_ios"
        }
        
        let jsonRep64Str = requestJSON["jsonRepresentation"] as? String ?? ""
        let jsonRepData = Data.fromBase64(jsonRep64Str) ?? Data()
        guard let jsonJSON = try JSONSerialization.jsonObject(with: jsonRepData, options: []) as? [String: Any] else {
            log("warning: missing rep str")
            self.derivedDataPath = ""
            self.sdk = ""
            self.platform = ""
            log("RequestReceived \(self)")
            return
        }
        log("jsonRepresentation \(jsonJSON)")

        let parameters = jsonJSON["parameters"] as? [String: Any] ?? [:]
        let arenaInfo = parameters["arenaInfo"] as? [String: Any] ?? [:]
        self.derivedDataPath = arenaInfo["derivedDataPath"] as? String ?? ""

        let activeRunDestination = parameters["activeRunDestination"] as? [String: Any] ?? [:]
        self.sdk = activeRunDestination["sdk"] as? String ?? ""
        self.platform = activeRunDestination["platform"] as? String ?? ""

        log("RequestReceived \(self)")
        log("Parsed derivedDataPath \(self.derivedDataPath)")
        log("Parsed sdk \(self.sdk)")
        log("Parsed platform \(self.platform)")
    }
}

/// Output "Response" messages
/// These are high level representations of how XCBuild responds to requests.

public struct CreateSessionResponse: XCBProtocolMessage {
    public init() throws {}

    /// Responses take an input from the segement of an input stream
    /// containing the input message
    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(1),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(11),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("STRING"),
            XCBRawValue.array([XCBRawValue.string("S0")]),
        ]
    }
}

public struct TransferSessionPIFResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(2),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(32),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.string("TRANSFER_SESSION_PIF_RESPONSE"),
            XCBRawValue.array([XCBRawValue.array([])]),
            XCBRawValue.uint(3),
        ]
    }
}

public struct SetSessionSystemInfoResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(6),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("PING"),
            XCBRawValue.nil,
            XCBRawValue.uint(4),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
        ]
    }
}

public struct SetSessionUserInfoResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(6),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("PING"),
            XCBRawValue.nil,
            XCBRawValue.uint(try encoder.getMsgId() + 1),
        ]
    }
}

public struct CreateBuildResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        gBuildNumber += 1

        return [
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(24),

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("BUILD_CREATED"),
            [Int64(gBuildNumber)],
        ]
    }
}

public struct BuildStartResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        return [
            // Begin prefix
            XCBRawValue.uint(try encoder.getMsgId()),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.uint(0),
            XCBRawValue.int(7),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("BOOL"),
            XCBRawValue.array([XCBRawValue.bool(true)]),
            XCBRawValue.uint(try encoder.getMsgId()),
            // END

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.uint(0),
            XCBRawValue.uint(7),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("BOOL"),
            XCBRawValue.array([XCBRawValue.bool(true)]),
            XCBRawValue.uint(try encoder.getResponseMsgId(subtracting: 3)),
            // END
        ]
    }
}

/// Note: this is assumed to be used during a build
/// responding to a StartBuild request.
public struct BuildProgressUpdatedResponse: XCBProtocolMessage {
    let progress: Double
    let taskName: String
    let message: String
    let showInActivityLog: Bool

    public init(progress: Double = -1.0, taskName: String = "", message: String = "Updated 1 task", showInActivityLog: Bool = false) {
        self.progress = progress
        self.taskName = taskName
        self.message = message
        self.showInActivityLog = showInActivityLog
    }

    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        let padding = 14 // sizeof messages, random things
        let length = "BUILD_PROGRESS_UPDATED".utf8.count + self.taskName.utf8.count + self.message.utf8.count
        return [
            XCBRawValue.uint(try encoder.getResponseMsgId(subtracting: 3)),

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(UInt64(length + padding)),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("BUILD_PROGRESS_UPDATED"),
            XCBRawValue.array([.string(taskName), .string(self.message), .double(self.progress), .bool(self.showInActivityLog)]),
        ]
    }
}

public struct PlanningOperationWillStartResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
            XCBRawValue.uint(72),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("PLANNING_OPERATION_WILL_START"),
            XCBRawValue.array([XCBRawValue.string("S0"), XCBRawValue.string("FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0")]),
            XCBRawValue.uint(try encoder.getResponseMsgId(subtracting: 3)),
        ]
    }
}

public struct PlanningOperationWillEndResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
            XCBRawValue.uint(70),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("PLANNING_OPERATION_FINISHED"),
            XCBRawValue.array([XCBRawValue.string("S0"), XCBRawValue.string("FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0")]),
            XCBRawValue.uint(try encoder.getResponseMsgId(subtracting: 3)),
        ]
    }
}

public struct BuildOperationEndedResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),

            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(42),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("BUILD_OPERATION_ENDED"),
            [Int64(gBuildNumber), Int64(0), XCBRawValue.nil],
        ]
    }
}

public struct IndexingInfoReceivedResponse: XCBProtocolMessage {
    let targetID: String
    let data: Data?
    public let responseChannel: UInt64
    let clangXMLData: Data?

    public init(targetID: String = "", data: Data? = nil, responseChannel: UInt64, clangXMLData: Data? = Data()) {
        self.targetID = targetID
        self.data = data
        //self.responseChannel = 40
        self.responseChannel = responseChannel
        self.clangXMLData = clangXMLData
    }

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        var inputs: [XCBRawValue] = [XCBRawValue.string(self.targetID)]
        if let data = self.data {
            inputs += [XCBRawValue.binary(data)]
        }

        if let clangXMLData =  self.clangXMLData {
            inputs +=  [XCBRawValue.binary(clangXMLData)]
        }
        return [
             XCBRawValue.string("INDEXING_INFO_RECEIVED"),
             XCBRawValue.array(inputs)
        ]

    }
}

public struct BuildTargetPreparedForIndex: XCBProtocolMessage {
    let targetGUID: String

    public init(targetGUID: String) {
        self.targetGUID = targetGUID
    }

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.string("BUILD_TARGET_PREPARED_FOR_INDEX"),
            XCBRawValue.array([
                XCBRawValue.string(self.targetGUID),
                XCBRawValue.array([
                    XCBRawValue.double( Date().timeIntervalSince1970),
                ]),
            ]),
        ]
    }
}

public struct DocumentationInfoReceived: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(59),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(30),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("DOCUMENTATION_INFO_RECEIVED"),
            XCBRawValue.array([
                XCBRawValue.array([
                ]),
            ]),
        ]
    }
}
