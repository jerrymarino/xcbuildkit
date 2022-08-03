/*
Copyright (c) 2022, XCBuildKit contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of the IDEXCBProgress project.
*/

import Foundation
import XCBProtocol
import MessagePack

/// Interact with XCBBuildService
public class XCBBuildServiceProcess {
    private static let bsPath = "/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"
    private static let bsPathDefault = bsPath + ".default"

    // FIXME: We should add this as a formal feature and class
    // for now - maybe remove it
    public static func MessageDebuggingEnabled() -> Bool {
        return false
    }

    private var path: String?
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let process = Process()
    private var proxyIdx = 0

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
            // FIXME(https://github.com/jerrymarino/xcbuildkit/issues/36)
            //let defaultPath = CommandLine.arguments[0] + ".default"
            let defaultPath = "/Applications/Xcode-13.app//Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"
            guard FileManager.default.fileExists(atPath: defaultPath) else {
                fatalError("XCBBuildServiceProcess - unexpected installation.  \(defaultPath)")
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
            BKBuildService.writeQueue.sync {
                // For MessageDebuggingEnable - perhaps make a differnt log
                // level
                if XCBBuildServiceProcess.MessageDebuggingEnabled() {
                    try? data.write(to: URL(fileURLWithPath: "/tmp/stubs/xcbuild.og.stdout.\(self.proxyIdx).bin"))
                    let str = String(decoding: data, as: UTF8.self) ??  "<starting-issue>"
                    log("XCBBuildServiceProcess.Start: \(data.count) - \(str)")
                }
                FileHandle.standardOutput.write(data)
                self.proxyIdx += 1
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
