import Foundation
import XCBProtocol

public class PrettyPrinter {
    public static func allMatches(key: String, data: Data) -> Any? {
        let str = data.readableString
        if str.contains(key) {
            return PrettyPrinter.matches(for: "\(key)\":.*?,", in: str)
        }
        return nil
    }

    public static func matchExactly(key: String, data: Data) -> Any? {
        let str = data.readableString
        if str.contains(key) {
            return PrettyPrinter.matches(for: "\(key)\":.*?,", in: str).first!.components(separatedBy: ":")[1].components(separatedBy: ",")[0]
        }
        return nil
    }

    static func matches(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    public static func fooWrite(text: String, append: Bool = false, filename: String = "foo.txt") {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(filename)
            let data = "\n\(text)\n".data(using: String.Encoding.utf8)!
            if FileManager.default.fileExists(atPath: fileURL.path) && append {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL, options: .atomicWrite)
            }
        }
    }

    public static func fooSaveToFile(data: Data?, filename: String = "bar") {
        guard var dataToSave = data else {
            return
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(filename)
            try? dataToSave.write(to: fileURL, options: .atomicWrite)
        }
    }

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

    public extension String {
        var fromUTF16: String {
            let components = Array(self.utf16)
            return String(utf16CodeUnits: components, count: components.count)
        }
    }

    public extension Data {
        var readableString: String {
            if let bplist = self.bplist {
                return "bplist(\(bplist))"
            }
            // return self.bytes.readableString.fromUTF16
            return self.bytes.readableString
        }

        private var bplist: String? {
            return BPlistConverter(binaryData: self)?.convertToXML()
        }

        private var bytes: [UInt8] {
            return [UInt8](self)
        }
    }

    public extension Array where Element == UInt8 {
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