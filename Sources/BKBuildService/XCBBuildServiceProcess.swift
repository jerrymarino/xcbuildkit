import Foundation

/// Interact with XCBBuildService
public class XCBBuildServiceProcess {
    private static let bsPath = "/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"

    private var path: String?
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let process = Process()
    private let serialQueue = DispatchQueue(label: "com.bkbuildservice.xcbuildservicewrite")

    public init() { }

    public func write(_ data: Data) {
        guard process.isRunning else {
            fatalError("called write when build service isn't running")
        }
        serialQueue.async {
            self.stdin.fileHandleForWriting.write(data)
        }
    }

    /// An XCBResponseHandler
    /// To implement a hybrid build service, call after a CreateSessionRequest
    public func startIfNecessary(xcode: String) {
        guard process.isRunning == false else {
            return
        }

        let path = xcode + "/"  + XCBBuildServiceProcess.bsPath
        self.start(path: path)
    }

    private func start(path: String) {
        stdout.fileHandleForReading.readabilityHandler = {
            handle in
            let data = handle.availableData
            // Dump stdout to the current standard output
            BKBuildService.writeQueue.sync {
                FileHandle.standardOutput.write(data)
            }
        }
        process.environment = ProcessInfo.processInfo.environment
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin
        process.launchPath = path
        process.launch()
    }

}
