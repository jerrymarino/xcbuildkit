#include <stdlib.h>

int main(int ac, char** av) {
    // FIXME: not good assumptions:
    // - the BUILDSERVICE_PATH ( self ) is deep in bazel-out
    // https://github.com/jerrymarino/xcbuildkit/issues/36
    int st = system("/bin/bash -c \"$(dirname $(dirname $(dirname $XCBBUILDSERVICE_PATH)))/BuildServiceShim/stub.sh\"");

    // This atleast crashes it if its wrong
    if (WEXITSTATUS(st) == 0x10) {
        return 0;
    } else {
        return 1;
    }
}
