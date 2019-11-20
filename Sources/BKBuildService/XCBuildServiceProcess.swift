import Foundation


/// Interact with XCBBuildService
public class XCBuildServiceProcess {
    public static let bsPath = "/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"

    let path: String
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let process = Process()

    // FIXME: determine this from CREATE_SESSION
    public init(path: String = "/Applications/Xcode-11.2.1.app/" + XCBuildServiceProcess.bsPath) {
        self.path = path
    }

    public func start() {
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

    let serialQueue = DispatchQueue(label: "com.bkbuildservice.xcbuildservicewrite")
    public func write(_ data: Data) {
        serialQueue.async {
            self.stdin.fileHandleForWriting.write(data)
        }
    }
}
