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
        if self.process.isRunning == false {
            // This has happened when attempting to build _swift_ toolchain from
            // source.
            //
            // If the binary was copied into Xcode than start using that.
            log("warning: attempted to message XCBBuildService before starting it")
            startIfNecessary(xcode: nil)
        }
        // writes aren't serial here ( rational it already is via stdin )
        self.stdin.fileHandleForWriting.write(data)
    }

    /// Start for a given Xcode
    /// If Xcode is not specified, it uses the adjacent build service ( setup by
    /// the install )
    public func startIfNecessary(xcode: String?) {
        guard self.process.isRunning == false else {
            return
        }

        guard let xcode = xcode else {
            let defaultPath = CommandLine.arguments[0] + ".default"
            guard FileManager.default.fileExists(atPath: defaultPath) else {
                fatalError("XCBBuildServiceProcess - unexpected installation.")
            }
            self.start(path: defaultPath)
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

    public func start(path: String) {
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
