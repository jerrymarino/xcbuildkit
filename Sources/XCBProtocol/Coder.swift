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

public extension Data {
    public var readableString: String {
        return self.bytes.readableString
    }

    private var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Array where Element == UInt8 {
    var readableString: String {
        guard let bytesAsString = self.utf8String ?? self.asciiString else {
            fatalError("Failed to encode bytes")
        }
        return bytesAsString
    }

    private var utf8String: String? {
        return String(bytes: self, encoding: .utf8)
    }

    private var asciiString: String? {
        return String(bytes: self, encoding: .ascii)
    }
}

extension XCBDecoder {
    /// Decodes a message
    public func decodeMessage() -> XCBProtocolMessage? {
        // log("foo-buffer-3.0: \(self.input.data.readableString)")
        do {
            let msg = try decodeMessageImpl()
            log("foo-buffer-3.1: decoded \(String(describing: msg))")
            // log("foo-buffer-3.1.1: msg \(msg)")
            return msg
        } catch {
            log("foo-buffer-3.2: decoding failed \(error)\nfoo-buffer-3.2.data: \(self.input.data.readableString)")
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
                // } else if str == "TRANSFER_SESSION_PIF_REQUEST" {
                //     return try TransferSessionPIFRequest(input: minput)
                // } else if str == "TRANSFER_SESSION_PIF_OBJECTS_LEGACY_REQUEST" {
                //     return try TransferSessionPIFObjectsLegacyRequest(input: minput)
                // } else if str == "SET_SESSION_SYSTEM_INFO" {
                //     return try SetSessionSystemInfoRequest(input: minput)
                // } else if str == "SET_SESSION_USER_INFO" {
                //     return try SetSessionUserInfoRequest(input: minput)
                // } else if str == "CREATE_BUILD" {
                //     return try CreateBuildRequest(input: minput)
                // } else if str == "BUILD_START" {
                //     return try BuildStartRequest(input: minput)
                } else if str == "INDEXING_INFO_REQUESTED" {
                    log("foo-buffer-4.1")
                    return try IndexingInfoRequested(input: minput)
                // } else if str == "BUILD_DESCRIPTION_TARGET_INFO" {
                //     return try BuildDescriptionTargetInfo(input: minput)
                // } else if str == "DOCUMENTATION_INFO_REQUESTED" {
                //     return try DocumentationInfoRequested(input: minput)
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
