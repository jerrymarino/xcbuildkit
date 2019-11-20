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

public struct CreateSessionRequest: XCBProtocolMessage {
    let workspace: String
    let xcode: String
    let xcbuildDataPath: String

    init(input _: XCBInputStream) {
        workspace = ""
        xcode = ""
        xcbuildDataPath = ""
    }
}

/// Input "Request" Messages
public struct TransferSessionPIFRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

public struct TransferSessionPIFObjectsLegacyRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

public struct SetSessionSystemInfoRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

public struct SetSessionUserInfoRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

public struct CreateBuildRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {
        // guard case var .array(msg) = minput.next() else {
        //   fatalError("unexpected message")
        // }
        // This contains all info about the build see above
        // log("CREATE_BUILD.input[0] " + String(describing: msg[0]))
        // log("CREATE_BUILD.input[1] " + String(describing: msg[1]))

        // TODO: Increment the build number?
    }
}

public struct BuildStartRequest: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

public struct IndexingInfoRequested: XCBProtocolMessage {
    public init(input _: XCBInputStream) {}
}

/// Output "Response" messages
/// These are high level representations of how XCBuild responds to requests.

public struct PingResponse: XCBProtocolMessage {
    public init() {}

    /// Unused! FIXME: Determine how to reuse this.
    public func encode(_ encoder: XCBEncoder) throws -> XCBResponse {
        return [
            XCBRawValue.uint(6),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.uint(0),
            XCBRawValue.string("PING"),
            XCBRawValue.nil,
            XCBRawValue.uint(encoder.msgId + 1),
        ]
    }
}

public struct CreateSessionResponse: XCBProtocolMessage {
    public init() {}

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
            XCBRawValue.uint(encoder.msgId + 1),
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
            XCBRawValue.uint(encoder.msgId),
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
            XCBRawValue.uint(encoder.msgId),
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
            XCBRawValue.uint(encoder.msgId - 3),
            // END
        ]
    }
}

public struct BuildProgressUpdatedResponse: XCBProtocolMessage {
    public init() {}

    public func encode(_: XCBEncoder) throws -> XCBResponse {
        return [XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
                XCBRawValue.uint(61),
                XCBRawValue.uint(0),
                XCBRawValue.uint(0),
                XCBRawValue.uint(0),
                XCBRawValue.string("BUILD_PROGRESS_UPDATED"),
                XCBRawValue.array([.nil, XCBRawValue.string("Getting that inspiration'"), XCBRawValue.double(-1.0), XCBRawValue.bool(true)]),
                XCBRawValue.bool(false)]
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
            XCBRawValue.uint(encoder.msgId - 3),
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
            XCBRawValue.uint(encoder.msgId - 3),
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
