import BKBuildService
import Foundation
import XCBProtocol

struct BasicMessageContext {
    let xcbbuildService: XCBBuildServiceProcess
    let bkservice: BKBuildService
}

/// FIXME: support multiple workspaces
var gStream: BEPStream?

/// This example listens to a BEP stream to display some output.
///
/// All operations are delegated to XCBBuildService and we inject
/// progress from BEP.
enum BasicMessageHandler {
    static func startStream(bepPath: String, startBuildInput: XCBInputStream, bkservice: BKBuildService) throws {
        log("startStream " + String(describing: startBuildInput))
        let stream = try BEPStream(path: bepPath)
        var progressView: ProgressView?
        try stream.read {
            event in
            if let updatedView = ProgressView(event: event, last: progressView) {
                let encoder = XCBEncoder(input: startBuildInput)
                let response = BuildProgressUpdatedResponse(progress:
                    updatedView.progressPercent, message: updatedView.message)
                if let responseData = try? response.encode(encoder) {
                     bkservice.write(responseData)
                }
                progressView = updatedView
            }
        }
        gStream = stream
    }

    public static let clangXML: String = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <array>
        <dict>
        <key>LanguageDialect</key>
        <string>objective-c</string>
        <key>clangASTBuiltProductsDir</key>
        <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Products/Debug</string>
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
            <string>-fmodules-cache-path=/Users/thiago/Library/Developer/Xcode/DerivedData/ModuleCache.noindex</string>
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
            <string>-DOBJC_OLD_DISPATCH_PROTOTYPES=0</string>
            <string>-isysroot</string>
            <string>/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk</string>
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
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/DataStore</string>
            <string>-iquote</string>
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/CLI-generated-files.hmap</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/CLI-own-target-headers.hmap</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/CLI-all-target-headers.hmap</string>
            <string>-iquote</string>
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/CLI-project-headers.hmap</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Products/Debug/include</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/DerivedSources-normal/x86_64</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/DerivedSources/x86_64</string>
            <string>-I/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/DerivedSources</string>
            <string>-F/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Products/Debug</string>
            <string>-fsyntax-only</string>
            <string>/Users/thiago/Development/xcbuildkit/iOSApp/CLI/main.m</string>
            <string>-o</string>
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
            <string>-Xclang</string>
            <string>-fallow-pcm-with-compiler-errors</string>
            <string>-ivfsoverlay</string>
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/regular-to-index-overlay.yaml</string>
            <string>-ivfsoverlay</string>
            <string>/Users/thiago/Library/Developer/Xcode/DerivedData/iOSApp-frrxxdgefswljmaayjgcihttruuq/Index/Build/Intermediates.noindex/index-to-regular-overlay.yaml</string>
            <string>-index-unit-output-path</string>
            <string>/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
            <string>-fretain-comments-from-system-headers</string>
            <string>-ferror-limit=10</string>
            <string>-working-directory=/Users/thiago/Development/xcbuildkit/iOSApp</string>
            <string>-Xclang</string>
            <string>-detailed-preprocessing-record</string>
        </array>
        <key>outputFilePath</key>
        <string>/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
        <key>sourceFilePath</key>
        <string>/Users/thiago/Development/xcbuildkit/iOSApp/CLI/main.m</string>
        <key>toolchains</key>
        <array>
            <string>com.apple.dt.toolchain.XcodeDefault</string>
        </array>
        </dict>
    </array>
    </plist>
    """

    static func fakeIndexingInfoResCLI() -> Data {
        // <string>/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
        // <string>/iOSApp/main.o</string>
        let xml = """
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"> 
        <plist version="1.0">
            <array>
                <dict>
                    <key>outputFilePath</key>
                    <string>/iOSApp.build/Debug/CLI.build/Objects-normal/x86_64/main.o</string>
                    <key>sourceFilePath</key>
                    <string>/Users/thiago/Development/xcbuildkit/iOSApp/CLI/main.m</string>
                </dict>
            </array>
        </plist>
        """
        guard let converter = BPlistConverter(xml: xml) else {
            fatalError("Failed to allocate converter")
        }
        guard let fakeData = converter.convertToBinary() else {
            fatalError("Failed to convert XML to binary plist data")
        }

        return fakeData
    }

    static func fakeIndexingInfoResiOSApp() -> Data {
        // <string>/iOSApp.build/Debug-iphonesimulator/iOSApp.build/Objects-normal/x86_64/main.o</string>
        // <string>/CLI/main.o</string>
        let xml = """
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <array>
                <dict>
                    <key>outputFilePath</key>
                    <string>/iOSApp.build/Debug-iphonesimulator/iOSApp.build/Objects-normal/x86_64/main.o</string>
                    <key>sourceFilePath</key>
                    <string>/Users/thiago/Development/xcbuildkit/iOSApp/iOSApp/main.m</string>
                </dict>
            </array>
        </plist>
        """
        guard let converter = BPlistConverter(xml: xml) else {
            fatalError("Failed to allocate converter")
        }
        guard let fakeData = converter.convertToBinary() else {
            fatalError("Failed to convert XML to binary plist data")
        }

        return fakeData
    }

    // CLI target
    static let fakeCLITargetID = "a218dfee841498f4d1c86fb12905507da6b8608e8d79fa8addd22be62fee6ac8"

    // iOSApp target
    static let fakeiOSAppTargetID = "a218dfee841498f4d1c86fb12905507d07cc8d7a3ea25dc2e041fef4554fafd5"

    /// Proxying response handler
    /// Every message is written to the XCBBuildService
    /// This simply injects Progress messages from the BEP
    static func respond(input: XCBInputStream, data: Data, context: Any?) {
        let basicCtx = context as! BasicMessageContext
        let xcbbuildService = basicCtx.xcbbuildService
        let bkservice = basicCtx.bkservice
        let decoder = XCBDecoder(input: input)
        let encoder = XCBEncoder(input: input)

        if let msg = decoder.decodeMessage() {
            if let createSessionRequest = msg as? CreateSessionRequest {
                xcbbuildService.startIfNecessary(xcode: createSessionRequest.xcode)
            }
            else if msg is BuildStartRequest {
                do {
                    let bepPath = "/tmp/bep.bep"
                    try startStream(bepPath: bepPath, startBuildInput: input, bkservice: bkservice)
                } catch {
                    fatalError("Failed to init stream" + error.localizedDescription)
                }
            }
            else if msg is IndexingInfoRequested {
                // PrettyPrinter.fooWrite(text: "\(data.readableString)", append: true, filename: "foo.txt")

                guard let filePath = PrettyPrinter.matchExactly(key: "filePath", data: data) as? String else {
                    return
                }

                // If `false` clause here is enabled to skip indexing is supposed to work as usual
                // goal is to conditionally send the indexing message below without Xcode becoming unresponsive
                if false {
                // if filePath.contains("CLI/main.m") {
                    let message = IndexingInfoReceivedResponse(
                        targetID: fakeCLITargetID,
                        data: fakeIndexingInfoResCLI(),
                        responseChannel: UInt64(34),
                        length: UInt64(17),
                        clangXMLData: BPlistConverter(xml: clangXML)?.convertToBinary() ?? Data())

                    if let responseData = try? message.encode(encoder) {
                        bkservice.write(responseData)
                    }
                }           
            }
        }
        // writes input data to original service
        xcbbuildService.write(data)
    }
}

let xcbbuildService = XCBBuildServiceProcess()
let bkservice = BKBuildService()

let context = BasicMessageContext(
    xcbbuildService: xcbbuildService,
    bkservice: bkservice
)

bkservice.start(messageHandler: BasicMessageHandler.respond, context: context)
