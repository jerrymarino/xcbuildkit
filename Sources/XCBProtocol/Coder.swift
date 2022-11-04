import Foundation // For log()

public class XCBEncoder {
    let input: XCBInputStream

    public init(input: XCBInputStream) {
        self.input = input
    }

    /// This is state of protocol messages, and perhaps it would be encapsulated in a
    /// better way. Xcode uses this internally
    func getMsgId() throws -> UInt64 {
        var v = self.input
        guard let next = v.next(),
            case let .uint(id) = next else {
            // This happens when there is unexpected input. There is an
            // unimplemented where this does happen, triggered by
            // BazelBuildService.
            log("missing id for msg: " + String(describing: self.input))
            throw XCBProtocolError.unexpectedInput(for: self.input)
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
    case unexpectedInput(for: XCBInputStream)
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
        do {
            let msg = try decodeMessageImpl()
            log("decoded: " + String(describing: msg))
            return msg
        } catch {
            log("decoding failed \(error)")
            return nil
        }
    }

    private func decodeMessageImpl() throws -> XCBProtocolMessage? {
        var minput = self.input
        while let value = minput.next() {
            switch value {
            case let XCBRawValue.string(str):
                if str == "CREATE_SESSION" {
                    return try CreateSessionRequest(input: minput)
                } else if str == "TRANSFER_SESSION_PIF_REQUEST" {
                    return try TransferSessionPIFRequest(input: minput)
                } else if str == "TRANSFER_SESSION_PIF_OBJECTS_LEGACY_REQUEST" {
                    return try TransferSessionPIFObjectsLegacyRequest(input: minput)
                } else if str == "SET_SESSION_SYSTEM_INFO" {
                    return try SetSessionSystemInfoRequest(input: minput)
                } else if str == "SET_SESSION_USER_INFO" {
                    return try SetSessionUserInfoRequest(input: minput)
                } else if str == "CREATE_BUILD" {
                    return try CreateBuildRequest(input: minput)
                } else if str == "BUILD_START" {
                    return try BuildStartRequest(input: minput)
                } else if str == "INDEXING_INFO_REQUESTED" {
                    return try IndexingInfoRequested(input: minput)
                } else if str == "BUILD_DESCRIPTION_TARGET_INFO" {
                    return try BuildDescriptionTargetInfo(input: minput)
                } else if str == "DOCUMENTATION_INFO_REQUESTED" {
                    return try DocumentationInfoRequested(input: minput)
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
        if let data = entry.data(using: .utf8) {
            fileUpdater.write(data)
        }
        fileUpdater.closeFile()
    } catch {
        try? entry.write(to: url, atomically: false, encoding: .utf8)
    }
}
