import BEP
import SwiftProtobuf
import XCBProtocol

struct ProgressView {
    let progress: Int32
    let totalActions: Int32
    let count: Int32
    let message: String
    let progressPercent: Double

    init(progress: Int32, totalActions: Int32, count: Int32, message: String, progressPercent: Double) {
        self.progress = progress
        self.totalActions = totalActions
        self.count = count
        self.message = message
        self.progressPercent = progressPercent
    }

    init?(event: BuildEventStream_BuildEvent, last: ProgressView?) {
        let count = event.id.progress.opaqueCount
        let lastProgress = last?.progress ?? 0
        let lastTotalActions = last?.totalActions ?? 0
        let lastCount = last?.count ?? 0
        guard count > 0 else {
            return nil
        }

        let progressStderr = event.progress.stderr
        let (ranActions, totalActions) = ProgressView.extractUIProgress(progressStderr: progressStderr)
        var baseProgress: Int32
        if ranActions == 0 {
            // Update the base progress with the last progress. This is
            // a synthetic number. Bazel will not update for all actions
            baseProgress = lastProgress + (count - lastCount)
        } else {
            baseProgress = ranActions
        }

        let progressTotalActions = max(lastTotalActions, totalActions)
        let progress = min(progressTotalActions, max(lastProgress, baseProgress))
        // Don't notify for the same progress more than once.
        if progress == lastProgress, progressTotalActions == lastTotalActions {
            return nil
        }

        var message: String
        var progressPercent: Double = -1.0
        if progressTotalActions > 0 {
            message = "\(progress) of \(progressTotalActions) tasks"
            // Very early on in a build, totalActions is not fully computed, and if we set it here
            // the progress bar will jump to 100. Leave it at -1.0 until we get further along.
            // Generally, for an Xcode target there will be a codesign, link, and compile action.
            // Consider using a timestamp as an alternative?
            if progressTotalActions > 5 {
                progressPercent = (Double(progress) / Double(progressTotalActions)) * 100.0
            }
        } else if progressStderr.count > 28 {
            // Any more than this and it crashes or looks bad.
            // If Bazel hasn't reported anything resonable yet, then it's likely
            // likely still analyzing. Render Bazels message
            message = String(progressStderr.prefix(28)) + ".."
        } else {
            // This is really undefined behavior but render the count.
            message = "Updating \(progress)"
        }

        // At the last message, update to 100%
        if event.lastMessage {
            progressPercent = 99.0
        }

        self.init(progress: progress, totalActions: progressTotalActions, count: count, message: message, progressPercent: progressPercent)
    }

    /// Look for progress like [22 / 228]
    /// reference src/main/java/com/google/devtools/build/lib/buildtool/ExecutionProgressReceiver.java
    public static func extractUIProgress(progressStderr: String) -> (Int32, Int32) {
        var ranActions: Int32 = 0
        var totalActions: Int32 = 0
        if progressStderr.first == "[" {
            var numberStrings: [String] = []
            var accum = ""
            for x in progressStderr {
                if x == "[" {
                    continue
                } else if x == "]" {
                    numberStrings.append(accum)
                    break
                } else if x == " " || x == "/" {
                    if accum.count > 0 {
                        numberStrings.append(accum)
                        accum = ""
                    }
                } else {
                    accum.append(x)
                }
            }
            if numberStrings.count == 2 {
                ranActions = Int32(numberStrings[0]) ?? 0
                totalActions = Int32(numberStrings[1]) ?? 0
            }
        }

        return (ranActions, totalActions)
    }
}
