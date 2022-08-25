import Foundation
import XCBProtocol

class PrettyPrinter {
  static func prettyPrintRecursively(_ result: Array<XCBRawValue>) {
      parseIterator(result).forEach{ print($0) }
  }

  // Attempts to convert data into human readable format
  // This is not supposed to be a perfect mapping but just reasonable
  // guesses on how one could convert each type into something readable
  // and it's only supposed to be used during development to inspect
  // input/output from MessagePack while running `debug_*` action from `Makefile`
  static private func parseBasicTypes(_ rawValue: XCBRawValue) -> Any {
        switch rawValue {
        case let .uint(value):
            return value.uint8
        case let .array(value):
            return "array(\(self.parseIterator(value)))"
        case .extended(let type, let data):
            return "extended(\(type), \(data.readableString))"
        case let .map(value):
            var dict: [String: Any] = [:]
            for (k,v) in value {
                dict["\(self.parseBasicTypes(k))"] = self.parseBasicTypes(v)
            }
            return "map(\(dict))"
        case let .binary(value):
            return "binary(\(value.readableString))"
        default:
            return String(describing: rawValue)
        }
    }

    // Special treatment for `.uint` type:
    //
    // The `.uint` type from MessagePack will repeat many times in the stream,
    // this func accumulates the bytes and only when that chunk is complete attempts
    // to convert it to something readable and adds that to the result
    static private func parseIterator(_ result: Array<XCBRawValue>) -> [Any] {
        var iterator = result.makeIterator()
        var accumulatedBytes: [UInt8] = []
        var result: [Any] = []

        while let next = iterator.next() {
            let nextParsed = self.parseBasicTypes(next)
            if let nextParsedAsBytes = nextParsed as? UInt8 {
                accumulatedBytes.append(nextParsedAsBytes)
            } else {
                if accumulatedBytes.count > 0 {
                    result.append("uint(\(accumulatedBytes.readableString)))")
                    accumulatedBytes = []
                }
                result.append(nextParsed)
            }
        }

        if accumulatedBytes.count > 0 {
            result.append("uint(\(accumulatedBytes.readableString))")
            accumulatedBytes = []
        }

        return result
    }
}

public extension Data {
    public var readableString: String {
        if let bplist = self.bplist {
            return "bplist(\(bplist))"
        }
        return self.bytes.readableString
    }

    private var bplist: String? {
        return BPlistConverter(binaryData: self)?.convertToXML()
    }

    private var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Array where Element == UInt8 {
    var readableString: String {        
        do {
            guard let bytesAsString = self.asciiString ?? self.utf8String else {
                fatalError("Failed to encode bytes")
            }
            return bytesAsString
        } catch let e {
            log("foo-aaa-ext-data-1: \(e)")
        }
    }

    private var utf8String: String? {
        return String(bytes: self, encoding: .utf8)
    }

    private var asciiString: String? {
        return String(bytes: self, encoding: .ascii)
    }
}

extension UInt64 {
    var uint8: UInt8 {
        var x = self.bigEndian
        let data = Data(bytes: &x, count: MemoryLayout<UInt64>.size)
        let mapping = data.map{$0}
        // This is supposed to be used only when debugging input/output streams
        // at the time of writing grabbing the last bit here was enough to compose sequences of bytes that can be encoded into `String`
        //
        // Grabbs the significant value here only from the mapping, which looks like this: [0, 0, 0, 0, 0, 0, 0, 105]
        guard let last = mapping.last else {
            print("warning: Failed to get last UInt8 from UInt64 mapping \(mapping)")
            return 0
        }
        return last
    }
}