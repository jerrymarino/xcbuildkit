import Foundation
import XCBProtocol

/// Interact with XCBBuildService
public class XCBBuildServiceProcess {
    private static let bsPath = "/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"
    private static let bsPathDefault = bsPath + ".default"

    private var path: String?
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let process = Process()

    public init() {}

    /// Write `data` to the build service.
    /// This has the effect that the XCBBuildService will respond normally to
    /// the request.
    ///
    /// This isn't safe and should be called seraially during a response handler
    public func write(_ data: Data) {
        guard self.process.isRunning else {
            fatalError("called write when build service isn't running")
        }
        // writes aren't serial here ( rational it already is via stdin )
        self.stdin.fileHandleForWriting.write(data)
    }

    /// An XCBResponseHandler
    /// To implement a hybrid build service, call after a CreateSessionRequest
    public func startIfNecessary(xcode: String) {
        guard self.process.isRunning == false else {
            return
        }

        // In the case we've replaced Xcode's build service then start that
        let defaultPath = xcode + "/" + XCBBuildServiceProcess.bsPathDefault
        if FileManager.default.fileExists(atPath: defaultPath) {
            self.start(path: defaultPath)
        } else {
            self.start(path: xcode + "/" + XCBBuildServiceProcess.bsPath)
        }
    }

    private func start(path: String) {
        log("Starting build service:" + path)
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
