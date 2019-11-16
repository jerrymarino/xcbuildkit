import Foundation
import MessagePack

// This is a test example of writing responses with raw types
// consider moving these to structs or something for an API
enum BasicResponseHandler {
    /// Responses take an input from the segement of an input stream
    /// containing the input message
    static func createSessionResponse(_ input: XCBInputStream) -> XCBResponse {
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
        XCBRawValue.uint(0)]
    }

    static func transferSessionPIFResponse(_ input: XCBInputStream) -> XCBResponse {
        return [
        XCBRawValue.string("TRANSFER_SESSION_PIF_RESPONSE"),
        XCBRawValue.array([XCBRawValue.array([])]),
        XCBRawValue.uint(3)]
    }

    static func setSessionSystemInfoResponse(_ input: XCBInputStream) -> XCBResponse {
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
        XCBRawValue.uint(0)]
    }

    static func setSessionUserInfoResponse(_ input: XCBInputStream) -> XCBResponse {
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
        XCBRawValue.uint(6),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(24),
        ]
    }

    // CREATE_BUILD

    // Request:
    // string(CREATE_BUILD) 1068 bytes
    // array([string(S0), uint(59), array([array([string(build), string(Debug), array([string(macosx), string(macosx10.15), string(macos), string(x86_64), array([string(x86_64h), string(x86_64)]), bool(false)]), string(x86_64), array([string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData), string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Build/Products), string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Build/Intermediates.noindex), string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Build/Intermediates.noindex/PrecompiledHeaders), string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Index/PrecompiledHeaders), string(/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Index/DataStore), bool(true)]), array([map([string(ENABLE_PREVIEWS): string(NO)]), map([:]), map([:]), map([:]), nil]), nil]), array([array([string(86b383703cee5911294a732c1f582133a6b8608e8d79fa8addd22be62fee6ac8), nil])]), bool(false), bool(false), bool(true), bool(true), bool(false), bool(true), nil, int(0), int(0), nil, bool(false), bool(false)])]) 212 bytes
    // uint(61) 211 bytes

    // Response
    // string(BUILD_CREATED) 1068 bytes
    // array([int(12)]) 1058 bytes
    // uint(61) 1057 bytes
    static func createBuildResponse(_ input: XCBInputStream) -> XCBResponse {
        return [
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("BUILD_CREATED"),
        [Int64(0)],
        XCBRawValue.int(7),
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
        XCBRawValue.uint(5)
        ]
    }

    // BUILD_START

    // Request:
    // string(BUILD_START) 1294 bytes
    // array([string(S0), int(11)]) 1281 bytes
    // uint(58) 1280 bytes
    // Note: seems to increment the request by 1
    // Response:
    // uint(59) 452 bytes
    // uint(0) 467 bytes
    // uint(0) 466 bytes
    // uint(0) 465 bytes
    // uint(0) 464 bytes
    // uint(7) 463 bytes
    // uint(0) 462 bytes
    // uint(0) 461 bytes
    // uint(0) 460 bytes
    // string(BOOL) 455 bytes
    // array([bool(true)]) 453 bytes
    // uint(59) 452 bytes

    static func buildStartResponse(_ input: XCBInputStream) -> XCBResponse {
        return [
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
        XCBRawValue.uint(5)]
    }

    static func completeResponse(_ input: XCBInputStream) -> XCBResponse {
        return [
        XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
        XCBRawValue.uint(72),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("PLANNING_OPERATION_WILL_START"),
        XCBRawValue.array([XCBRawValue.string("S0"), XCBRawValue.string("FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0")]),
        XCBRawValue.uint(5)]
    }

    static func completeResponse1(_ input: XCBInputStream) -> XCBResponse {
        return [ XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
        XCBRawValue.uint(61),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("BUILD_PROGRESS_UPDATED"),
        XCBRawValue.array([.nil, XCBRawValue.string("Getting that inspiration'"), XCBRawValue.double(-1.0), XCBRawValue.bool(true)]),
        XCBRawValue.bool(false)]
    }

    static func completeResponse2(_ input: XCBInputStream) -> XCBResponse {
        return [
        XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
        XCBRawValue.uint(70),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("PLANNING_OPERATION_FINISHED"),
        XCBRawValue.array([XCBRawValue.string("S0"), XCBRawValue.string("FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0")]),
        XCBRawValue.uint(5)]
    }
    
    // This currently fails ( couldn't decode a bool )
    static func completeResponse3n(_ input: XCBInputStream) -> XCBResponse {
        return [ XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0), XCBRawValue.uint(0),
        XCBRawValue.uint(70),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("BUILD_PROGRESS_UPDATED"),
        XCBRawValue.array([XCBRawValue.string(""), XCBRawValue.string("!to create a life you love ;)     "), XCBRawValue.double(-1.0), XCBRawValue.bool(true)]),
        XCBRawValue.uint(5)]
    }

    // This currently fails ( could not decode a string )
    static func completeResponse3(_ input: XCBInputStream) -> XCBResponse {
        return [
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(29),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.string("BUILD_PREPARATION_COMPLETED"),
        XCBRawValue.nil,
        XCBRawValue.uint(5),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(0),
        XCBRawValue.uint(34)]
    }
    
    static func completeResponse4(_ input: XCBInputStream) -> XCBResponse {
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
        [Int64(0), Int64(0), XCBRawValue.nil]]
    }

    static func respond(input: XCBInputStream, context: Any?) {
       var v = input
       while var value = v.next() {
           /// Write handler
           let write: ((XCBResponse) -> Void) = {
                v in
                if let b = context as? Bool, b == true {
                    print(v)
                } else {
                    XCBService.write(v)
                }
           }

            switch value {
            case XCBRawValue.string(let str):
                //print("Info: XCBRawValue.string(", str, ")")
                if str == "CREATE_SESSION" {
                    write(BasicResponseHandler.createSessionResponse(v))
                } else if str == "TRANSFER_SESSION_PIF_REQUEST" {
                    write(BasicResponseHandler.transferSessionPIFResponse(v))
                } else if str == "SET_SESSION_SYSTEM_INFO" {
                    write(BasicResponseHandler.setSessionSystemInfoResponse(v))
                } else if str == "SET_SESSION_USER_INFO" {
                    write(BasicResponseHandler.setSessionUserInfoResponse(v))
                } else if str == "CREATE_BUILD" {
                    write(BasicResponseHandler.createBuildResponse(v))
                } else if str == "BUILD_START" {
                    write(BasicResponseHandler.buildStartResponse(v))
                    write(BasicResponseHandler.completeResponse(v))
                    write(BasicResponseHandler.completeResponse1(v))
                    write(BasicResponseHandler.completeResponse2(v))
                    write(BasicResponseHandler.completeResponse4(v))
                }
            default:
                continue
           }
       }
    }
}

let debug = CommandLine.arguments.contains("--dump")
let raw = CommandLine.arguments.contains("--raw")
XCBService.readFromStandardInput(responseHandler: BasicResponseHandler.respond,
                                 debug: debug, context: raw)
