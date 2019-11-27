package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_application",
)
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_bundle_import",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)
load(
    "@build_bazel_rules_apple//apple:versioning.bzl",
    "apple_bundle_version",
)
load(
    "//third_party:repositories.bzl",
    "namespaced_name",
)

swift_library(
    name = "XCBProtocol",
    srcs = glob(["Sources/XCBProtocol/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack"],
)


swift_library(
    name = "BKBuildService",
    srcs = glob(["Sources/BKBuildService/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack", ":XCBProtocol"],
)

apple_bundle_version(
    name = "XCBuildKitVersion",
    build_version = "1.0",
)


swift_library(
    name = "BSBuildServiceLib",
    srcs = glob(["Examples/BSBuildService/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack", ":BKBuildService"],
)

# This is an end to end integration test utility
macos_application(
    name = "BSBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = ["Examples/BSBuildService/Info.plist"],
    minimum_os_version = "10.14",
    version = ":XCBuildKitVersion",
    deps = [":BSBuildServiceLib"],
)

swift_library(
    name = "HybridBuildServiceLib",
    srcs = glob(["Examples/HybridBuildService/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack", ":BKBuildService"],
)

# This is an end to end integration test utility
macos_application(
    name = "HybridBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = ["Examples/HybridBuildService/Info.plist"],
    minimum_os_version = "10.14",
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
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack", ":BKBuildService", ":BEP"],
)

# This is an end to end integration test utility
macos_application(
    name = "BazelBuildService",
    bundle_id = "com.xcbuildkit.example",
    infoplists = ["Examples/BazelBuildService/Info.plist"],
    minimum_os_version = "10.14",
    version = ":XCBuildKitVersion",
    deps = [":BazelBuildServiceLib"],
)

load("//:utils/InstallerPkg/pkg.bzl", "macos_application_installer")

macos_application_installer(
    name="BazelBuildServiceInstaller",
    app=":BazelBuildService",
    identifier="com.xcbuildkit.installer",
    distribution="Examples/BazelBuildService/InstallerPkg/distribution.xml",
    resources="Examples/BazelBuildService/InstallerPkg/Resources/",
)

