#include <stdlib.h>

int main(int ac, char** av) {
    // Run a bash script "stub" adjacent to the binary
    system("/bin/bash -c \"$(dirname $XCBBUILDSERVICE_PATH)/BuildServiceShim.runfiles/__main__/BuildServiceShim/stub.sh\"");
    return 0;
}
