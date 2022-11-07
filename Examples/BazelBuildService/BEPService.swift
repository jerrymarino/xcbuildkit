import BEP
import BKBuildService
import Foundation
import XCBProtocol

// Handles BEP related tasks for all incoming message types (progress bar, indexing, etc.).
// In the future we might want to delegate the message specific work to a diff service,
// keep all logic here now for simplicity.
class BEPService {
  // Read info from BEP and optionally handle events
  func startStream(msg: WorkspaceInfoKeyable, bepPath: String, startBuildInput: XCBInputStream, msgId: UInt64, ctx: BasicMessageContext) throws {
        guard let info = ctx.indexingService.infos[msg.workspaceKey] else { return }

        log("[INFO] Will start BEP stream at path \(bepPath) with input" + String(describing: startBuildInput))
        let bkservice = ctx.bkservice
        let stream = try BEPStream(path: bepPath)
        var progressView: ProgressView?
        try stream.read {
            event in
            if info.config.indexingEnabled {
                self.parseSourceOutputFileMappingsFromBEP(msg: msg, event: event, ctx: ctx)
            }

            if info.config.progressBarEnabled {
                if let updatedView = ProgressView(event: event, last: progressView) {
                    let encoder = XCBEncoder(input: startBuildInput, msgId: msgId)
                    let response = BuildProgressUpdatedResponse(progress:
                        updatedView.progressPercent, message: updatedView.message)
                    if let responseData = try? response.encode(encoder) {
                        bkservice.write(responseData)
                    }
                    progressView = updatedView
                }
            }
        }
        info.bepStream = stream
    }

  // This loop looks for JSON files with a known suffix `BUILD_SERVICE_SOURE_OUTPUT_FILE_MAP_SUFFIX` and loads the mapping
  // information from it decoding the JSON and storing in-memory.
  //
  // Read about the 'namedSetOfFiles' key here: https://bazel.build/remote/bep-examples#consuming-namedsetoffiles
  func parseSourceOutputFileMappingsFromBEP(msg: WorkspaceInfoKeyable, event: BuildEventStream_BuildEvent, ctx: BasicMessageContext) {
      guard let info = ctx.indexingService.infos[msg.workspaceKey] else { return }
      // Do work only if `namedSetOfFiles` is present and contain `files`
      guard let json = try? JSONSerialization.jsonObject(with: event.jsonUTF8Data(), options: []) as? [String: Any] else { return }
      guard let namedSetOfFiles = json["namedSetOfFiles"] as? [String: Any] else { return }
      guard namedSetOfFiles.count > 0 else { return }
      guard let allPairs = namedSetOfFiles["files"] as? [[String: Any]] else { return }

      for pair in allPairs {
          // Only proceed if top level keys exist and a .json to be decoded is found
          guard let jsonFilename = pair["name"] as? String else { continue }
          guard var jsonURI = pair["uri"] as? String else { continue }
          guard jsonURI.hasSuffix(".json") else { continue }

          jsonURI = jsonURI.replacingOccurrences(of: "file://", with: "")

          // Only proceed for keys holding .json files with known pattern (i.e. `BUILD_SERVICE_SOURE_OUTPUT_FILE_MAP_SUFFIX`) in the name
          guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath:jsonURI)) else { continue }
          guard jsonData.count > 0 else { continue }
          guard let sourceOutputFileMapSuffix = info.config.sourceOutputFileMapSuffix else { continue }
          guard jsonFilename.hasSuffix(sourceOutputFileMapSuffix) else { continue }

          // Load .json contents into memory
          log("[INFO] Parsed \(jsonFilename) from BEP.")
          ctx.indexingService.loadSourceOutputFileMappingInfo(msg: msg, jsonFilename: jsonFilename, jsonData: jsonData, updateCache: true)
      }
  }
}