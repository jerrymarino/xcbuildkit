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
import XCBProtocol

// Consider:
// decompose the "Bazel" example to work end to end with Xcode
// hardcode DeriveData /private/var/tmp/xcbuildkit/example-dd or read
// read workspace from xcbuild / remove jmarino

// This one is rigged for /tmp/xtest
// TODO: Populate this with an empty index
let clangXMLT: String = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
        <dict>
                <key>LanguageDialect</key>
                <string>objective-c</string>
                <key>clangASTBuiltProductsDir</key>
                <string>/tmp/xtest</string>
                <key>clangASTCommandArguments</key>
                <array>
                        <string>-x</string>
                        <string>objective-c</string>
                        <string>-target</string>
                        <string>x86_64-apple-macos10.14</string>
                        <string>-fmessage-length=0</string>
                        <string>-fdiagnostics-show-note-include-stack</string>
                        <string>-fmacro-backtrace-limit=0</string>
                        <string>-std=gnu11</string>
                        <string>-fobjc-arc</string>
                        <string>-fobjc-weak</string>
                        <string>-fmodules</string>
                        <string>-fmodules-cache-path=/tmp/ModuleCache.noindex</string>
                        <string>-fmodules-prune-interval=86400</string>
                        <string>-fmodules-prune-after=345600</string>
                        <string>-Wnon-modular-include-in-framework-module</string>
                        <string>-Werror=non-modular-include-in-framework-module</string>
                        <string>-Wno-trigraphs</string>
                        <string>-fpascal-strings</string>
                        <string>-O0</string>
                        <string>-fno-common</string>
                        <string>-Wno-missing-field-initializers</string>
                        <string>-Wno-missing-prototypes</string>
                        <string>-Werror=return-type</string>
                        <string>-Wdocumentation</string>
                        <string>-Wunreachable-code</string>
                        <string>-Wno-implicit-atomic-properties</string>
                        <string>-Werror=deprecated-objc-isa-usage</string>
                        <string>-Wno-objc-interface-ivars</string>
                        <string>-Werror=objc-root-class</string>
                        <string>-Wno-arc-repeated-use-of-weak</string>
                        <string>-Wimplicit-retain-self</string>
                        <string>-Wduplicate-method-match</string>
                        <string>-Wno-missing-braces</string>
                        <string>-Wparentheses</string>
                        <string>-Wswitch</string>
                        <string>-Wunused-function</string>
                        <string>-Wno-unused-label</string>
                        <string>-Wno-unused-parameter</string>
                        <string>-Wunused-variable</string>
                        <string>-Wunused-value</string>
                        <string>-Wempty-body</string>
                        <string>-Wuninitialized</string>
                        <string>-Wconditional-uninitialized</string>
                        <string>-Wno-unknown-pragmas</string>
                        <string>-Wno-shadow</string>
                        <string>-Wno-four-char-constants</string>
                        <string>-Wno-conversion</string>
                        <string>-Wconstant-conversion</string>
                        <string>-Wint-conversion</string>
                        <string>-Wbool-conversion</string>
                        <string>-Wenum-conversion</string>
                        <string>-Wno-float-conversion</string>
                        <string>-Wnon-literal-null-conversion</string>
                        <string>-Wobjc-literal-conversion</string>
                        <string>-Wshorten-64-to-32</string>
                        <string>-Wpointer-sign</string>
                        <string>-Wno-newline-eof</string>
                        <string>-Wno-selector</string>
                        <string>-Wno-strict-selector-match</string>
                        <string>-Wundeclared-selector</string>
                        <string>-Wdeprecated-implementations</string>
                        <string>-DDEBUG=1</string>
                        <string>-DDEMOSQUARE=1</string>
                        <string>-DOBJC_OLD_DISPATCH_PROTOTYPES=0</string>
                        <string>-isysroot</string>
                        <string>/Applications/Xcode-13.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.3.sdk</string>
                        <string>-fasm-blocks</string>
                        <string>-fstrict-aliasing</string>
                        <string>-Wprotocol</string>
                        <string>-Wdeprecated-declarations</string>
                        <string>-g</string>
                        <string>-Wno-sign-conversion</string>
                        <string>-Winfinite-recursion</string>
                        <string>-Wcomma</string>
                        <string>-Wblock-capture-autoreleasing</string>
                        <string>-Wstrict-prototypes</string>
                        <string>-Wno-semicolon-before-method-body</string>
                        <string>-Wunguarded-availability</string>
                        <string>-index-store-path</string>
                        <string>/tmp/xtest/XDataStore</string>
                        <string>-fsyntax-only</string>
                        <string>__SOURCE_FILE__</string>
                        <string>-o</string>
                        <string>/tmp/xtest/main.o</string>
                        <string>-Xclang</string>
                        <string>-fallow-pcm-with-compiler-errors</string>
                        <string>-fretain-comments-from-system-headers</string>
                        <string>-ferror-limit=10</string>
                        <string>-working-directory=__TODO_SRCROOT__</string>
                        <string>-Xclang</string>
                        <string>-detailed-preprocessing-record</string>
                        <string>-DXXXXXXXXX=1</string>
                </array>
                <key>outputFilePath</key>
                <string>/tmp/main.o</string>
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

public enum XCBBuildServiceProxyStub {
   public static func getASTArgs(targetID: String, outputFilePath: String) -> Data {
       //return (try? Data(contentsOf: URL(fileURLWithPath: "/Users/jmarino/Development/XCBuildResponses/indexinginfo_requested.payload"))) ?? Data()

       let clangXML = clangXMLT.replacingOccurrences(of:"__SOURCE_FILE__", with: outputFilePath)
       log("CLANG XML \(clangXML)")
       return BPlistConverter(xml: clangXML)?.convertToBinary() ?? Data()
   }
}

