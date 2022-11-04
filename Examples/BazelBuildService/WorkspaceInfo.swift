import XCBProtocol
import BEP

// Holds information about a workspace, encapsulates many aspects relevant for
// build service implementation.
//
// Exposes a method to define a key for this workspace
class WorkspaceInfo {
  // Values expected to be set during initialization (e.g. on `CreateSessionRequest`)
  let xcode: String
  let workspaceHash: String
  let workspaceName: String
  let xcodeprojPath: String
  let config: BazelBuildServiceConfig

  // Values expected to be update later (e.g. on `CreateBuildRequest`, `IndexingInfoRequested`, etc.)
  var workingDir: String = ""
  var derivedDataPath: String = ""
  var indexDataStoreFolderPath: String = ""
  var bepStream: BEPStream?

  // Dictionary that holds mapping from source file to respective `.o` file under `bazel-out`. Used to respond to indexing requests.
  //
  // Example:
  //
  // "Test-XCBuildKit-cdwbwzghpxmnfadvmmhsjcdnjygy": [
  //     "App_source_output_file_map.json": [
  //         "/tests/ios/app/App/main.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/main.o",
  //         "/tests/ios/app/App/Foo.m": "bazel-out/ios-x86_64-min10.0-applebin_ios-ios_x86_64-dbg-ST-0f1b0425081f/bin/tests/ios/app/_objs/App_objc/arc/Foo.o",
  //     ],
  // ],
  var outputFileForSource: [String: [String: String]] = [:]


  init(xcode: String, workspaceName: String, workspaceHash: String, xcodeprojPath: String) {
    // Fail early if key values are not present
    guard xcode.count > 0 else { fatalError("[ERROR] Xcode path should not be empty.") }
    self.xcode = xcode

    guard xcodeprojPath.count > 0 else { fatalError("[ERROR] Xcode project path should not be empty.") }
    self.xcodeprojPath = xcodeprojPath

    guard workspaceName.count > 0 && workspaceHash.count > 0 else {
        fatalError("[ERROR] Workspace info not found. Both workspace name and hash should not be empty: workspaceName=\(workspaceName), workspaceHash=\(workspaceHash)")
    }
    self.workspaceName = workspaceName
    self.workspaceHash = workspaceHash

    // Hard coded value for now for the expected config path
    // TODO: Find a way to pass this from Xcode
    self.config = BazelBuildServiceConfig(configPath: "\(self.xcodeprojPath)/xcbuildkit.config")
  }

  // Key to uniquely identify a workspace
  // The reason this is a static method is for other components to be able to call it
  // without duplicating key generation code
  static func workspaceKey(workspaceName: String, workspaceHash: String) -> String {
    return "\(workspaceName)-\(workspaceHash)"
  }
}