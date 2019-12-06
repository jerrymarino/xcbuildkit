#!/bin/bash
set -e
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
pushd "$SCRIPTPATH/.." > /dev/null

SUPPORTED_VERSION=11

function uninstall_for_xcode() {
    echo "Checking install for Xcode $1"
    BS_DEFAULT_LOCATION="${1}/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService"
    if [[ ! -n "$(readlink "$BS_DEFAULT_LOCATION")" ]]; then
        echo "Not installed for Xcode $1" && return
    fi

    BS_INSTALLED_LOCATION="${BS_DEFAULT_LOCATION}.default"
    # Move the original version to the installed location
    if [[ -f "$BS_INSTALLED_LOCATION" ]]; then
        echo "Uninstalling for Xcode $1"
        mv "$BS_INSTALLED_LOCATION" "$BS_DEFAULT_LOCATION" 
    fi
}

function main() {
    # See xcode-locator.m for more info
    "$SCRIPTPATH/../tools/bazelwrapper" build @bazel_tools//tools/osx:xcode-locator-genrule
    # Prints a list of [Xcode.app]
    ALL_XCODES=( $("$SCRIPTPATH/../bazel-bin/external/bazel_tools/tools/osx/xcode-locator" 2>&1 | \
         grep "expanded=$SUPPORTED_VERSION" | sed -e 's,.*file://,,g' -e 's,/:.*,,g') )
    for XCODE in "${ALL_XCODES[@]}"; do
        if [[ -n "$XCODE" ]]; then
            uninstall_for_xcode "$XCODE"
        fi
    done
}

main "$@"

