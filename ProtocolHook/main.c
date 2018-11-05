// tee messages to /tmp/x
int main(int ac, char** av) {
    system("/bin/bash -c \"/Applications/Xcode.app/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService | tee /tmp/x\"");
    return 0;
}
