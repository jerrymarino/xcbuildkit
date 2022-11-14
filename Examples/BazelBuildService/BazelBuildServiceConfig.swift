// Encapsulates the config file used to control xcbuildkit's behaviour.
//
// Format is:
//
// KEY1=VALUE1
// KEY2=VALUE2
//
// so one config per line. This is intentionally simple at the moment but we can add more validation or a more reliable file format later.
//
// TODO: Codable?
// TODO: Not load from disk all the time but still detect changes in the file and refresh in-memory values?
struct BazelBuildServiceConfig: CustomDebugStringConvertible {
  private enum ConfigKeys: String {
    case indexingEnabled = "BUILD_SERVICE_INDEXING_ENABLED"
    case indexStorePath = "BUILD_SERVICE_INDEX_STORE_PATH"
    case xcbuildkitDataDir = "BUILD_SERVICE_INDEXING_DATA_DIR"
    case progressBarEnabled = "BUILD_SERVICE_PROGRESS_BAR_ENABLED"
    case configBEPPath = "BUILD_SERVICE_BEP_PATH"
    case sourceOutputFileMapSuffix = "BUILD_SERVICE_SOURCE_OUTPUT_FILE_MAP_SUFFIX"
    case bazelWorkingDir = "BUILD_SERVICE_BAZEL_EXEC_ROOT"
  }

  var indexingEnabled: Bool {  return self.value(for: .indexingEnabled) == "YES" }
  var indexStorePath: String? {  return self.value(for: .indexStorePath) }
  var xcbuildkitDataDir: String? {  return self.value(for: .xcbuildkitDataDir) }
  var progressBarEnabled: Bool {  return self.value(for: .progressBarEnabled) == "YES" }
  var configBEPPath: String? {  return self.value(for: .configBEPPath) ?? "/tmp/bep.bep" }
  var sourceOutputFileMapSuffix: String? {  return self.value(for: .sourceOutputFileMapSuffix) }
  var bazelWorkingDir: String? {  return self.value(for: .bazelWorkingDir) }

  let configPath: String

  init(configPath: String) {
    self.configPath = configPath
  }

  var debugDescription: String {
    return "\(self.loadConfigFile ?? [:])"
  }

  private var loadConfigFile: [String: Any]? {
      guard let data = try? String(contentsOfFile: self.configPath, encoding: .utf8) else {
        return nil
      }

      let lines = data.components(separatedBy: .newlines)
      var dict: [String: Any] = [:]
      for line in lines {
          let split = line.components(separatedBy: "=")
          guard split.count == 2 else { continue }
          dict[split[0]] = split[1]
      }
      return dict
  }

  private func value(for config: ConfigKeys) -> String? {
    return loadConfigFile?[config.rawValue] as? String
  }
}