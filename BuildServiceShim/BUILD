# This shim makes it easy to debug standard input and output
cc_binary(
    name = "main",
    srcs = ["main.c"]
)

sh_binary(
    name = "BuildServiceShim",
    srcs = [":main"],
    data = glob(["*.sh"]),
)


