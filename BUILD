load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_application",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)
load(
    "@build_bazel_rules_apple//apple:versioning.bzl",
    "apple_bundle_version",
)
load("//:utils/InstallerPkg/pkg.bzl", "macos_application_installer")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

swift_library(
    name = "XCBProtocol",
    srcs = glob(["Sources/XCBProtocol/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack"],
)

swift_library(
    name = "BKBuildService",
    srcs = glob(["Sources/BKBuildService/*.swift"]),
    deps = [
        ":XCBProtocol",
        "//third_party/xcbuildkit-MessagePack:MessagePack",
    ],
)

apple_bundle_version(
    name = "XCBuildKitVersion",
    build_version = "1.0",
)

swift_library(
    name = "BSBuildServiceLib",
    srcs = glob(["Examples/BSBuildService/*.swift"]),
    deps = [
        ":BKBuildService",
        "//third_party/xcbuildkit-MessagePack:MessagePack",
    ],
)

# This is an end to end integration test utility
macos_application(
    name = "BSBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = ["Examples/BSBuildService/Info.plist"],
    minimum_os_version = "10.15.4",
    version = ":XCBuildKitVersion",
    deps = [":BSBuildServiceLib"],
)

swift_library(
    name = "HybridBuildServiceLib",
    srcs = glob(["Examples/HybridBuildService/*.swift"]),
    deps = [
        ":BKBuildService",
        "//third_party/xcbuildkit-MessagePack:MessagePack",
    ],
)

# This is an end to end integration test utility
macos_application(
    name = "HybridBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = ["Examples/HybridBuildService/Info.plist"],
    minimum_os_version = "10.15.4",
    version = ":XCBuildKitVersion",
    deps = [":HybridBuildServiceLib"],
)

# Bazel BEP Protobuf libary
swift_library(
    name = "BEP",
    srcs = glob(["Examples/BEP/*.swift"]),
    deps = ["@xcbuildkit-SwiftProtobuf//:SwiftProtobuf"],
)

swift_library(
    name = "BazelBuildServiceLib",
    srcs = glob(["Examples/BazelBuildService/*.swift"]),
    deps = [
        ":BEP",
        ":BKBuildService",
        "//third_party/xcbuildkit-MessagePack:MessagePack",
    ],
)

# This is an end to end integration test utility

macos_application(
    name = "BazelBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = [
        "Examples/BazelBuildService/Info.plist",
        ":BuildInfo",
    ],
    minimum_os_version = "10.15.4",
    version = ":XCBuildKitVersion",
    deps = [":BazelBuildServiceLib"],
)

# Gen a BuildInfo.plist to be later consumed by apple bundling rules. In order
# for this work in the context of a dependency it needs to read the value of the
# git repo for _this_ repo.
# If the repo_info doesn't exist then read out commit from the repo
genrule(
    name = "BuildInfo",
    srcs = ["@xcbuildkit_repo_info//:ref"],
    outs = ["BuildInfo.plist"],
    cmd = """
        SRC=$(SRCS)
        COMMIT=$$(cat $$SRC)
        if [[ ! -n "$$COMMIT" ]]; then
            pushd "$$(cat ../../DO_NOT_BUILD_HERE)"
            COMMIT=$$(git rev-parse HEAD)
            popd
        fi
        echo \"<plist version=\"1.0\"><dict><key>BUILD_COMMIT</key><string>$$COMMIT</string></dict></plist>\" > $@
        """,
)

# We use the xcode-locator to determine what Xcode versions are on the system
filegroup(
    name = "BazelBuildServiceInstaller_scripts",
    srcs = glob(["utils/InstallerPkg/scripts/*"]) + [
        "@bazel_tools//tools/osx:xcode-locator-genrule",
    ],
)

filegroup(
    name = "BazelBuildServiceInstaller_resources",
    srcs = glob(["Examples/BazelBuildService/InstallerPkg/Resources/*"]),
)

macos_application_installer(
    name = "BazelBuildServiceInstaller",
    app = ":BazelBuildService",
    distribution = "Examples/BazelBuildService/InstallerPkg/distribution.xml",
    identifier = "com.xcbuildkit.installer",
    resources = ":BazelBuildServiceInstaller_resources",
    scripts = ":BazelBuildServiceInstaller_scripts",
)
