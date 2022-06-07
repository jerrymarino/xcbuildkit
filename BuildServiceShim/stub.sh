#!/bin/bash

# The service is adjacent to this program
# The layer of indirection is useful for debugging and not
# a production component
SERVICE="$(dirname $(dirname $XCBBUILDSERVICE_PATH))/BazelBuildService_app_dir/BazelBuildService.app/Contents/MacOS/BazelBuildService"

function redirect() {
    #tee  >($SERVICE) /tmp/xcbuild.out
    /usr/bin/env - XCBUILD_TRACING_URL=/tmp/xcbuild.trace TERM="${TERM}" SHELL="${SHELL}" PATH="${PATH}" HOME="${HOME}" \
    tee  /tmp/xcbuild.in | \
    $XCODE/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService | \
    tee  /tmp/xcbuild.out
}

function replace() {
    /usr/bin/env - TERM="${TERM}" SHELL="${SHELL}" PATH="${PATH}" HOME="${HOME}" \
    tee  /tmp/xcbuild.in | $SERVICE | tee /tmp/xcbuild.out
}

# This simply redirects stdin and stdout of Xcode's build service
if [[ "${BUILD_SERVICE_REDIRECT:-false}" == "true" ]]; then
    redirect
else
    replace
fi
