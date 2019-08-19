int main(int ac, char** av) {
    // Run a bash script "stub" adjacent to the binary
    system("/bin/bash -c \"$(dirname $XCBBUILDSERVICE_PATH)/stub\"");
    return 0;
}
