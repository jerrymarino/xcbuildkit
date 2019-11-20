import Foundation // For log()

public class XCBEncoder {
    let input: XCBInputStream

    public init(input: XCBInputStream) {
        self.input = input
    }

    /// This is state of protocol messages, and perhaps it would be encapsulated in a
    /// better way. Xcode uses this internally
    var msgId: UInt64 {
        var v = input
        guard case let .uint(id) = v.next() else {
            fatalError("missing id")
        }
        return id + 1
    }
}

public protocol XCBProtocolMessage {
    func encode(_ encoder: XCBEncoder) throws -> XCBResponse
}

extension XCBProtocolMessage {
    public func encode(_: XCBEncoder) throws -> XCBResponse {
        throw XCBProtocolError.unimplementedCoder
    }
}

enum XCBProtocolError: Error {
    case unimplementedCoder
}

public class XCBDecoder {
    let input: XCBInputStream

    public init(input: XCBInputStream) {
        self.input = input
    }
}

extension XCBDecoder {
    /// Decodes a message
    public func decodeMessage() -> XCBProtocolMessage? {
        let msg = decodeMessageImpl()
        log("decoded" + String(describing: msg))
        return msg
    }

    private func decodeMessageImpl() -> XCBProtocolMessage? {
        var v = input
        while var value = v.next() {
            switch value {
            case let XCBRawValue.string(str):
                if str == "CREATE_SESSION" {
                    return CreateSessionRequest(input: input)
                } else if str == "TRANSFER_SESSION_PIF_REQUEST" {
                    return TransferSessionPIFRequest(input: input)
                } else if str == "TRANSFER_SESSION_PIF_OBJECTS_LEGACY_REQUEST" {
                    return TransferSessionPIFObjectsLegacyRequest(input: input)
                } else if str == "SET_SESSION_SYSTEM_INFO" {
                    return SetSessionSystemInfoRequest(input: input)
                } else if str == "SET_SESSION_USER_INFO" {
                    return SetSessionUserInfoRequest(input: input)
                } else if str == "CREATE_BUILD" {
                    return CreateBuildRequest(input: input)
                } else if str == "BUILD_START" {
                    return BuildStartRequest(input: input)
                } else if str == "INDEXING_INFO_REQUESTED" {
                    return IndexingInfoRequested(input: input)
                }
            default:
                continue
            }
        }
        return nil
    }
}

public func log(_ str: String) {
    let url = URL(fileURLWithPath: "/tmp/xcbuild.log")
    let entry = str + "\n"
    do {
        let fileUpdater = try FileHandle(forWritingTo: url)
        fileUpdater.seekToEndOfFile()
        fileUpdater.write(entry.data(using: .utf8)!)
        fileUpdater.closeFile()
    } catch {
        try! entry.write(to: url, atomically: false, encoding: .utf8)
    }
}
