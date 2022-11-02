import BEP
import Foundation
import SwiftProtobuf
import XCBProtocol

public typealias BEPReadHandler = (BuildEventStream_BuildEvent) -> Void

public class BEPStream {
    private let path: String
    private var fileHandle: FileHandle?

    /// @param path - Binary BEP file
    /// this is passed to Bazel via --build_event_binary_file
    public init(path: String) throws {
        self.path = path
    }

    deinit {
        // According to close should automatically happen, but it does't under a
        // few cases:
        // https://developer.apple.com/documentation/foundation/filehandle/3172525-close
        try? fileHandle?.close()
        fileHandle?.readabilityHandler = nil
        log("BEPStream: dealloc")
    }
    /// Reads data from a BEP stream
    /// @param eventAvailableHandler - this is called with _every_ BEP event
    /// available
    public func read(eventAvailableHandler handler: @escaping BEPReadHandler) throws {
        let fm = FileManager.default
        // Bazel works by appending content to a file, specifically,
        // Java'sBufferedOutputStream.
        // Naievely using an input stream for the path and waiting for available
        // data will simply does not work with whatever
        // BufferedOutputStream.flush() is doing internally.
        // 
        // Reference:
        // https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/buildeventstream/transports/FileTransport.java
        // Perhaps, SwiftProtobuf can come up with a better solution to read
        // from files or upstream similar code
        // https://github.com/apple/swift-protobuf/issues/130
        //
        // Logic:
        // - If there's already a file at the path remove it
        // - Create a few file
        // - When the build starts, Bazel will attempt to reuse the inode, and
        //   stream to it.
        //
        //   Then,
        // - Via NSFileHandle, wait for data to be available and read all the
        //   bytes
        try? fm.removeItem(atPath: path)
        fm.createFile(atPath: path, contents: Data())

        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            log("BEPStream: failed to allocate \(path)")
            return
        }

        self.fileHandle = fileHandle
        fileHandle.readabilityHandler = {
            handle in
            let data = fileHandle.availableData
            guard data.count > 0 else {
                return
            }

            // Wrap the file handle in an InputStream for SwiftProtobuf to read
            // we read the stream until the end of the file
            let input = InputStream(data: data)
            input.open()
            while input.hasBytesAvailable {
                do {
                    let info = try BinaryDelimited.parse(messageType:
                        BuildEventStream_BuildEvent.self, from: input)
                    handler(info)
                    if info.lastMessage {
                        handle.closeFile()
                        handle.readabilityHandler = nil
                    }
                    log("BEPStream read event \(fileHandle.offsetInFile)")
                } catch {
                    log("BEPStream read error: " + error.localizedDescription)
                    break
                }
            }
        }

        // The file handle works without this in debug mode (i.e. manually launching xcbuildkit),
        // but when installed on a machine as a pkg this call is necessary to get events in the `readabilityHandler` block above.
        fileHandle.waitForDataInBackgroundAndNotify()
    }
}
