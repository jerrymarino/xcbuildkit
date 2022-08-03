# This shim makes it easy to debug standard input and output
# It's not useful for production
cc_binary(
    name = "main",
    srcs = ["main.c"],
)

sh_library(
    name = "BuildServiceShim_deps",
    data = ["stub.sh"],
)

sh_binary(
    name = "BuildServiceShim",
    srcs = [":main"],
    deps = [":BuildServiceShim_deps"]
)
