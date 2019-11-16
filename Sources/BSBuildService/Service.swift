import Foundation
import MessagePack

public typealias XCBResponseHandler = (XCBInputStream, Any?) -> Void

public enum XCBService {
    /// Starts a service on standard input
    public static func readFromStandardInput(responseHandler:@escaping
                                             XCBResponseHandler, debug: Bool,
                                             context: Any?) {
        let file = FileHandle.standardInput
        file.readabilityHandler = {
            h in
            let data = h.availableData
            guard data.count > 0 else {
                exit(0)
            } 

            /// Once the 
            let result = Unpacker.unpackAll(data).makeIterator()
            if debug {
                // Effectively, this is used to parse a stream
                result.forEach { print("." + String(describing: $0) + ",") }
            } else {
                responseHandler(result, context)
            }
        }
        repeat {
            sleep(1)
        } while true
    }

    public static func write(_ v: XCBResponse) {
        let datas = v.map {
            mm -> Data in
            return XCBPacker.pack(mm)
        }
        //print("Datas", datasmap { $0.hbytes() }.joined())
        datas.forEach { FileHandle.standardOutput.write($0) }
    }
}


typealias Chunk = (XCBRawValue, Data)

// This is mostly an implementation detail for now
enum Unpacker {
    public static func unpackOne(_ data: Data) -> Chunk? {
        return try? unpack(data)
    }

    static func startNext(_ data: Data) -> Data? {
        // If there is remaining bytes, try to strip out unparseable bytes
        // and continue down the stream
        var curr = data
        if (curr.count > 1) {
            let streamLength = Int(curr[0])
            // FIXME: subdata is copying over and over?
            curr = curr.subdata(in: 1..<curr.count - 1)
            return curr
        } else {
            return nil
        }
    }

    public static func unpackAll(_ data: Data) -> [XCBRawValue] {
        var unpacked = [XCBRawValue]()
        var curr = data

        repeat {
            if let res = try? unpack(curr) {
                let (value, remainder) = res
                curr = remainder
                unpacked.append(value)
                continue
            }

            // At the end of a segment, there will be no more input
            if let next = startNext(curr) {
                curr = next
            } else {
                // print("INFO: Break")
                break
            }
        } while true
        return unpacked
    }
}

