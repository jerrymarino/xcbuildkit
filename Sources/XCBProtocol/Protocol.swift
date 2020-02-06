/// Implements a XCBProtocol Messages
/// Many of these types are synthetic, high level representations of messages
/// derived from Xcode
import Foundation

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
            log("bad offset for msg: " String(describing: self.input))
            throw XCBProtocolError.unexpectedInput(for: self.input)
        }
        return id - offset
    }
}

public struct CreateSessionRequest: XCBProtocolMessage {
    public let workspace: String
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
    public init(input _: XCBInputStream) throws {}
}

public struct BuildStartRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
}

public struct IndexingInfoRequested: XCBProtocolMessage {
    public init(input _: XCBInputStream) throws {}
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
