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
import BKBuildService

// TODO:
// - decompose the "Bazel" example to work end to end with Xcode
// - hardcode DeriveData /private/var/tmp/xcbuildkit/example-dd or read
// - read workspace from xcbuild / remove jmarino
// - for this example - have another program generate the index and verify it
//   works
let clangXMLT: String = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
        <dict>
                <key>LanguageDialect</key>
                <string>objective-c</string>
                <key>clangASTBuiltProductsDir</key>
                <string>__DERIVED_DATA_PATH__/__WORKSPACE_NAME__-__WORKSPACE_HASH__/Index/Build/Products/__CONFIGURATION__-__PLATFORM__</string>
                <key>clangASTCommandArguments</key>
                <array>
                        __CMD_LINE_ARGS__
                        <string>-working-directory</string>
                        <string>__WORKING_DIR__</string>
                        <string>-fsyntax-only</string>
                        <string>__SOURCE_FILE__</string>
                </array>
                <key>outputFilePath</key>
                <string>__OUTPUT_FILE_PATH__</string>
                <key>sourceFilePath</key>
                <string>__SOURCE_FILE__</string>
                <key>toolchains</key>
                <array>
                        <string>com.apple.dt.toolchain.XcodeDefault</string>
                </array>
        </dict>
</array>
</plist>
"""

let swiftXMLT: String = """
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<array>
		<dict>
                        <key>LanguageDialect</key>
                        <string>swift</string>
                        <key>outputFilePath</key>
                        <string>__OUTPUT_FILE_PATH__</string>
                        <key>sourceFilePath</key>
                        <string>__SOURCE_FILE__</string>
                        <key>swiftASTBuiltProductsDir</key>
                        <string>__DERIVED_DATA_PATH__/__WORKSPACE_NAME__-__WORKSPACE_HASH__/Index/Build/Products/__CONFIGURATION__-__PLATFORM__</string>
                        <key>swiftASTCommandArguments</key>
                        <array>
                                __CMD_LINE_ARGS__
                                <string>-working-directory</string>
                                <string>__WORKING_DIR__</string>
                        </array>
                        <key>swiftASTModuleName</key>
                        <string>__MODULE_NAME__</string>
                        <key>toolchains</key>
                        <array>
                                <string>com.apple.dt.toolchain.XcodeDefault</string>
                        </array>
		</dict>
	</array>
</plist>
"""

public enum BazelBuildServiceStub {
        static private func xmlFromCmdLineArgs(args: [String], defaultWorkingDir: String) -> String {
                return args
                .map {
                        if $0.hasSuffix(".swift") {
                                return String("<string>\(defaultWorkingDir)/\($0)</string>")
                        }

                        return String("<string>\($0)</string>")
                }
                .joined(separator: "\n")
        }

        static private func collectValueForCompilerFlag(name: String, cmdLineArgs: [String]) -> String? {
                guard cmdLineArgs.count > 0 else { return nil }

                var collectNext: Bool = false
                for arg in cmdLineArgs {
                        if arg == name {
                                collectNext = true
                                continue
                        } else if collectNext {
                                return arg
                        }
                }
                return nil
        }

        public static func getASTArgs(isSwift: Bool,
                                      targetID: String,
                                      xcode: String,
                                      sourceFilePath: String,
                                      outputFilePath: String,
                                      derivedDataPath: String,
                                      workspaceHash: String,
                                      workspaceName: String,
                                      sdkPath: String,
                                      sdkName: String,
                                      defaultWorkingDir: String,
                                      bazelWorkingDir: String?,
                                      configuration: String,
                                      platform: String,
                                      cmdLineArgs: [String]) -> Data {
                var stub = isSwift ? swiftXMLT : clangXMLT
                let workingDir = bazelWorkingDir ?? defaultWorkingDir
                let cmdLineArgsXML = BazelBuildServiceStub.xmlFromCmdLineArgs(args: cmdLineArgs, defaultWorkingDir: defaultWorkingDir)

                stub = stub.replacingOccurrences(of:"__CMD_LINE_ARGS__", with: cmdLineArgsXML)
                .replacingOccurrences(of:"__SOURCE_FILE__", with: sourceFilePath)
                .replacingOccurrences(of:"__OUTPUT_FILE_PATH__", with: outputFilePath)
                .replacingOccurrences(of:"__WORKSPACE_NAME__", with: workspaceName)
                .replacingOccurrences(of:"__DERIVED_DATA_PATH__", with: derivedDataPath)
                .replacingOccurrences(of:"__WORKSPACE_HASH__", with: workspaceHash)
                .replacingOccurrences(of:"__BAZEL_XCODE_SDKROOT__", with: sdkPath)
                .replacingOccurrences(of:"__WORKING_DIR__", with: workingDir)
                .replacingOccurrences(of:"__CONFIGURATION__", with: configuration)
                .replacingOccurrences(of:"__PLATFORM__", with: platform)
                .replacingOccurrences(of:"__BAZEL_XCODE_DEVELOPER_DIR__", with: "\(xcode)/Contents/Developer")

                // Extracts value of `-module-name` from `swiftc` flags to set in the plist
                if let moduleName = BazelBuildServiceStub.collectValueForCompilerFlag(name: "-module-name", cmdLineArgs: cmdLineArgs), isSwift {
                        stub = stub.replacingOccurrences(of:"__MODULE_NAME__", with: moduleName)
                }

                // When indexing is setting up the data store it fails if compiler flags contain relative paths
                // Fixes that by pre-pending the working directory, we might want to revisit this and fix it
                // earlier in the build (i.e. when generating the compiler flags via an aspect)
                //
                // Example of what this does:
                //
                // -ivfsoverlaybazel-out/path/to/foo.yaml => -ivfsoverlay/private/var/path/to/execution_root/<workspace>/bazel-out/path/to/foo.yaml
                stub = stub.replacingOccurrences(of:"bazel-out/", with: "\(workingDir)/bazel-out/")
                // For indexing to work the path to the output file has to be relative to the `-working-directory` flag
                // so undo what the line above did only for this artifact
                stub = stub.replacingOccurrences(of: "\(workingDir)/\(outputFilePath)", with: outputFilePath)

                return BPlistConverter(xml: stub)?.convertToBinary() ?? Data()
        }

        // Required if `outputPathOnly` is `true` in the indexing request
        public static func outputPathOnlyData(outputFilePath: String,
                                              sourceFilePath: String,
                                              workingDir: String,
                                              bazelWorkingDir: String?) -> Data {
                let xml = """
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <array>
                        <dict>
                        <key>outputFilePath</key>
                        <string>\(outputFilePath)</string>
                        <key>sourceFilePath</key>
                        <string>\(sourceFilePath)</string>
                        </dict>
                </array>
                </plist>
                """
                guard let converter = BPlistConverter(xml: xml) else {
                        fatalError("Failed to allocate converter")
                }
                guard let bplistData = converter.convertToBinary() else {
                        fatalError("Failed to convert XML to binary plist data")
                }

                return bplistData
        }
}

