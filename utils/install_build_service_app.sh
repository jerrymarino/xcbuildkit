#!/bin/bash
set -o pipefail

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
pushd "$SCRIPTPATH/.." > /dev/null

# Normalize all XCBuildKit services to this directory. This makes it easier to
# manage multiple checkouts / builds and ensure there's only 1 installed
INSTALL_DIR="$HOME/Library/Application Support/XCBuildKit"

APP="$1"

if [[ ! -n "$APP" ]]; then
    echo "usage: /path/to/BuildService.app"
    exit 1
fi

if [[ ! -d "$APP" ]]; then
    echo "Can't find .app at $1"
    exit 1
fi

mkdir -p "$INSTALL_DIR"
EXISTING_BUILD_SERVICE="$(find "$INSTALL_DIR" -name *.app | head)"

function get_version() {
    /usr/libexec/PlistBuddy "$1/Contents/Info.plist" -c "Print :CFBundleVersion"
}

# Print a message when replacing
if [[ -d "$EXISTING_BUILD_SERVICE" ]]; then
    if [[ "$(get_version "$EXISTING_BUILD_SERVICE")" == "$(get_version $APP)" ]]; then
        echo "Skipping install"
        exit 0
    fi

    echo "Replacing build service $EXISTING_BUILD_SERVICE"
fi

INSTALLED_APP="$INSTALL_DIR/$(basename $APP)"
ditto "$APP" "$INSTALLED_APP"

BINARY="$(find "$INSTALLED_APP/Contents/MacOS" -type f | head)"

if [[ "${LAUNCH_DAEMON:-false}" == "true" ]]; then
    PLIST="/Library/LaunchDaemons/com.xcbuildkit.envvar.plist"
else
    PLIST="$HOME/Library/LaunchAgents/com.xcbuildkit.envvar.plist"
fi

echo "binary $BINARY"
# Generate and load the plist
"$SCRIPTPATH/plist_generator.sh" "$BINARY" > "$PLIST"
launchctl load -w "$PLIST"

echo "Installer needs to re-launch Xcode"
# Attempt to gracefully quit Xcode. If the user doesn't close it then this wont
# work until the next launch
osascript -e 'quit app "Xcode"'
open "$(dirname $(dirname $(xcode-select -p)))"

