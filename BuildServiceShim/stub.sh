#!/bin/bash

function redirect() {
    /usr/bin/env - XCBUILD_TRACING_URL=/tmp/xcbuild.trace TERM="${TERM}" SHELL="${SHELL}" PATH="${PATH}" HOME="${HOME}" \
    tee  /tmp/xcbuild.in | \
    $XCODE/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService | \
    tee  /tmp/xcbuild.out
}

function replace() {
    local SERVICE="$DEBUG_BUILDSERVICE_PATH"
    /usr/bin/env - TERM="${TERM}" SHELL="${SHELL}" PATH="${PATH}" HOME="${HOME}" \
    tee  /tmp/xcbuild.in | $SERVICE | tee /tmp/xcbuild.out
}

if [[ -n "$DEBUG_BUILDSERVICE_PATH" ]]; then
    echo "[stub.sh] Replacing ($DEBUG_BUILDSERVICE_PATH)" >> /tmp/xcbuild.log
    replace
else
    echo "[stub.sh] Shimming" >> /tmp/xcbuild.log
    redirect
fi
