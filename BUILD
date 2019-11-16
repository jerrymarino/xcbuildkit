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
    name = "BSBuildServiceLib",
    srcs = glob(["Sources/BSBuildService/*.swift"]),
    deps = ["//third_party/xcbuildkit-MessagePack:MessagePack"],
)

apple_bundle_version(
    name = "XCBuildKitVersion",
    build_version = "1.0",
)

# This is an end to end integration test utility
macos_application(
    name = "BSBuildService",
    bundle_id = "com.xcbuildkit.bsbuildservice",
    infoplists = ["Sources/BSBuildService/Info.plist"],
    minimum_os_version = "10.14",
    version = ":XCBuildKitVersion",
    deps = [":BSBuildServiceLib"],
)

