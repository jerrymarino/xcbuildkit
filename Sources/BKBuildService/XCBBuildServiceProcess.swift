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

    public init() {}

    public func write(_ data: Data) {
        guard self.process.isRunning else {
            fatalError("called write when build service isn't running")
        }
        self.serialQueue.async {
            self.stdin.fileHandleForWriting.write(data)
        }
    }

    /// An XCBResponseHandler
    /// To implement a hybrid build service, call after a CreateSessionRequest
    public func startIfNecessary(xcode: String) {
        guard self.process.isRunning == false else {
            return
        }

        let path = xcode + "/" + XCBBuildServiceProcess.bsPath
        self.start(path: path)
    }

    private func start(path: String) {
        self.stdout.fileHandleForReading.readabilityHandler = {
            handle in
            let data = handle.availableData
            // Dump stdout to the current standard output
            BKBuildService.writeQueue.sync {
                FileHandle.standardOutput.write(data)
            }
        }
        self.process.environment = ProcessInfo.processInfo.environment
        self.process.standardOutput = self.stdout
        self.process.standardError = self.stderr
        self.process.standardInput = self.stdin
        self.process.launchPath = path
        self.process.launch()
    }
}
