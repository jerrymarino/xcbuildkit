import Foundation
import XCBProtocol

class IndexingService {
    // Holds list of `WorkspaceInfo` for each opened workspace
    var infos: [String: WorkspaceInfo] = [:]

    struct IndexingSourceMapInfo {
        let outputFilePath: String
        let cmdLineArgs: [String]
    }

    // Finds output file (i.e. path to `.o` under `bazel-out`) in in-memory mapping
    func findSourceMapInfo(msg: WorkspaceInfoKeyable, filePath: String, workingDir: String) -> IndexingSourceMapInfo? {
        guard let info = self.infos[msg.workspaceKey] else { return nil }
        guard let sourceOutputFileMapSuffix = info.config.sourceOutputFileMapSuffix else { return nil }
        // Create key
        let sourceKey = filePath.replacingOccurrences(of: workingDir, with: "").replacingOccurrences(of: (info.config.bazelWorkingDir ?? ""), with: "")
        // Loops until found
        for (key, json) in info.outputFileForSource {
            guard key.hasSuffix(sourceOutputFileMapSuffix) else { continue }
            guard let srcInfo = json[sourceKey] as? [String: Any] else { continue }
            guard let outputFilePath = srcInfo["output_file"] as? String else {
                log("[ERROR] Failed to find output file for source: \(filePath)")
                continue
            }
            guard let cmdLineArgs = srcInfo["command_line_args"] as? [String], cmdLineArgs.count > 0 else {
                log("[ERROR] Failed to find command line flags for for source: \(filePath)")
                continue
            }

            return IndexingSourceMapInfo(
                outputFilePath: outputFilePath,
                cmdLineArgs: cmdLineArgs
            )
        }
        return nil
    }

    // Initialize in memory mappings from xcbuildkitDataDir if .json mappings files exist
    func initializeOutputFileMappingFromCache(msg: WorkspaceInfoKeyable) {
        guard let info = self.infos[msg.workspaceKey] else { return }
        guard let xcbuildkitDataDir = info.config.xcbuildkitDataDir else { return }
        let fm = FileManager.default
        do {
            let jsons = try fm.contentsOfDirectory(atPath: xcbuildkitDataDir)

            for jsonFilename in jsons {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: "\(xcbuildkitDataDir)/\(jsonFilename)"))
                self.loadSourceOutputFileMappingInfo(msg: msg, jsonFilename: jsonFilename, jsonData: jsonData)
            }
        } catch {
            log("[ERROR] Failed to initialize from cache under \(xcbuildkitDataDir) with err: \(error.localizedDescription)")
        }
    }

    // Check many conditions that need to be met in order to handle indexing and returns the respect output file,
    // the call site should abort and proxy the indexing request if this returns `nil`
    func indexingSourceMapInfo(msg: IndexingInfoRequested) -> IndexingSourceMapInfo? {
        // Load workspace info
        guard let info = self.infos[msg.workspaceKey] else {
            log("[WARNING] Workspace info not found for key \(msg.workspaceKey).")
            return nil
        }
        // Nothing to do if indexing is disabled
        guard info.config.indexingEnabled else {
            return nil
        }
        // Skip unsupported/invalid `filePath` values
        guard msg.filePath.count > 0 && msg.filePath != "<garbage>" else {
            log("[WARNING] Unsupported filePath for indexing: \(msg.filePath)")
            return nil
        }
        // In `BazelBuildService` the path to the working directory (i.e. execution_root) should always
        // exists
        guard info.config.bazelWorkingDir != nil else {
            log("[WARNING] Could not find bazel working directory. Make sure `BUILD_SERVICE_BAZEL_EXEC_ROOT` is set in the config file.")
            return nil
        }
        // Find .o file under `bazel-out` for source `msg.filePath`
        guard let sourceMapInfo = self.findSourceMapInfo(msg: msg, filePath: msg.filePath, workingDir: info.workingDir) else {
            log("[WARNING] Failed to find mapping information for for source: \(msg.filePath). Indexing requests will be proxied to default build service.")
            return nil
        }

        return sourceMapInfo
    }

    // Loads information into memory and optionally update the cache under xcbuildkitDataDir
    func loadSourceOutputFileMappingInfo(msg: WorkspaceInfoKeyable, jsonFilename: String, jsonData: Data, updateCache: Bool = false) {
        guard let info = self.infos[msg.workspaceKey] else { return }
        // Ensure workspace info is ready and .json can be decoded
        guard let xcbuildkitDataDir = info.config.xcbuildkitDataDir else { return }
        guard let jsonValues = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [String: Any] else { return }

        // Load .json contents into memory
        if info.outputFileForSource[jsonFilename] == nil {
            info.outputFileForSource[jsonFilename] = [:]
        }
        info.outputFileForSource[jsonFilename] = jsonValues
        log("[INFO] Loaded \(jsonFilename) into in-memory cache")

        // Update .json files cached under xcbuildkitDataDir for
        // fast load next time we launch Xcode
        if updateCache {
            do {
                guard let jsonBasename = jsonFilename.components(separatedBy: "/").last else { return }
                let jsonFilePath = "\(xcbuildkitDataDir)/\(jsonBasename)"
                let json = URL(fileURLWithPath: jsonFilePath)
                let fm = FileManager.default
                if fm.fileExists(atPath: jsonFilePath) {
                    try fm.removeItem(atPath: jsonFilePath)
                }
                try jsonData.write(to: json)
                log("[INFO] Updated cache for file \(jsonFilePath)")
            } catch {
                log("[ERROR] Failed to update cache under \(xcbuildkitDataDir) for file \(jsonFilename) with err: \(error.localizedDescription)")
            }
        }
    }

    private func getPlatformFamily(_ platformName: String) -> String {
        let platformNamePrefix = platformName.replacingOccurrences(of: "simulator", with: "")

        switch platformNamePrefix {
            case "macosx":      return "MacOSX"
            case "iphone":      return "iPhone"
            case "appletv":     return "AppleTV"
            case "watch":       return "Watch"
            case "driverkit":   return "DriverKit"
            default:
                fatalError("[ERROR] Unsupported platform \(platformNamePrefix)")
        }
    }

    // Helper method to compose sdk path for given sdk and platform
    // This is not an instance variable because if might change for different targets under the same workspace
    func sdkPath(msg: IndexingInfoRequested) -> String {
        guard let info = self.infos[msg.workspaceKey] else {
            fatalError("[ERROR] Workspace info not found")
        }
        guard msg.sdk.count > 0 else {
            fatalError("[ERROR] Failed to build SDK path, sdk name is empty.")
        }
        guard msg.platform.count > 0 else {
            fatalError("[ERROR] Failed to build SDK path, platform is empty.")
        }

        // Capitalize words to pick up exact name on disk and prevent compiler warnings
        let sim = msg.platform.contains("simulator")
        let simStr = "\(sim ? "Simulator": "")"
        let platformName = self.getPlatformFamily(msg.platform) + simStr
        let sdkName = msg.sdk.replacingOccurrences(of: msg.platform, with: platformName).replacingOccurrences(of: "simulator", with: simStr)
        return "\(info.xcode)/Contents/Developer/Platforms/\(platformName).platform/Developer/SDKs/\(sdkName).sdk"
    }

    // Xcode will try to find the data store under DerivedData so we need to symlink it to `BazelBuildServiceConfig.indexStorePath`
    // if that value was set in the config file.
    //
    // This function manages creating a symlink if it doesn't exist and it creates a backup with the `.default` suffix before doing that. Additionally,
    // it restores the backup if it's present and indexing is disabled.
    //
    // p.s.: Maybe there's a way to trick Xcode to try to find the DataStore under a an arbitrary path but it's not clear to me how
    func setupDataStore(msg: CreateBuildRequest) {
        guard let info = self.infos[msg.workspaceKey] else {
            log("[ERROR] Failed to setup indexing data store. Workspace information not found.")
            return
        }

        let fm = FileManager.default
        let ogDataStorePath = info.indexDataStoreFolderPath
        let dataStoreBackupPath = info.indexDataStoreFolderPath + ".default"
        // Used to check if certain directories exist
        var isDirectory = ObjCBool(true)

        // Only proceed if indexing is enabled and a Bazel index store path was specified in the config file
        // Otherwise try to restore the DataStore backup if it exists
        guard info.config.indexingEnabled, let indexStorePath = info.config.indexStorePath else {
            log("[INFO] Indexing disabled. Skipping DataStore setup.")

            // DataStore restore backup code
            // If a symlink exists, remove it and restore the backup
            if let existingSymlink = try? FileManager.default.destinationOfSymbolicLink(atPath: ogDataStorePath) {
                do {
                    try fm.removeItem(atPath: ogDataStorePath)
                } catch {
                    log("[ERROR] Failed to remove existing DataStore symlink with error: \(error.localizedDescription)")
                }
                if fm.fileExists(atPath: dataStoreBackupPath, isDirectory: &isDirectory) {
                    do {
                        try fm.moveItem(atPath: dataStoreBackupPath, toPath: ogDataStorePath)
                    } catch {
                        log("[ERROR] Failed to restore DataStore backup with error: \(error.localizedDescription)")
                    }
                }
            }
            return
        }

        // Prep work before creating the symlink. Handles two scenarios:
        //
        // (1) A symlink already exists (in this case it has to match what is in the config file, it will be removed otherwise)
        // (2) A symlink does not exist, in this case a backup will be created
        if let existingSymlink = try? FileManager.default.destinationOfSymbolicLink(atPath: ogDataStorePath) {
            if existingSymlink == indexStorePath {
                // Nothing to do, a symlink already exists and points to the correct path
                log("[INFO] DataStore symlink already setup. Nothing to do.")
                return
            } else {
                do {
                    try fm.removeItem(atPath: ogDataStorePath)
                } catch {
                    log("[ERROR] Failed to remove existing DataStore symlink with error: \(error.localizedDescription)")
                    return
                }
            }
        } else {
            if fm.fileExists(atPath: ogDataStorePath, isDirectory: &isDirectory) {
                // Remove existing backup if it exists
                if fm.fileExists(atPath: dataStoreBackupPath, isDirectory: &isDirectory) {
                    do {
                        try fm.removeItem(atPath: dataStoreBackupPath)
                    } catch {
                        log("[ERROR] Failed to remove existing DataStore backup with error: \(error.localizedDescription)")
                        return
                    }
                }
                // Backup DataStore
                do {
                    try fm.moveItem(atPath: ogDataStorePath, toPath: dataStoreBackupPath)
                } catch {
                    log("[ERROR] Failed to backup DataStore with error: \(error.localizedDescription)")
                    return
                }
            }
        }

        // If all the above went fine, create a symlink using the value from the config file
        do {
            try fm.createSymbolicLink(atPath: ogDataStorePath, withDestinationPath: indexStorePath)
        } catch {
            log("[ERROR] Failed to symlink DataStore with error: \(error.localizedDescription)")
            return
        }

        log("[INFO] DataStore symlink setup complete.")
    }
}