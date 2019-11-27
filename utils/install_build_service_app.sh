#!/bin/bash
set -o pipefail

function get_version() {
    /usr/libexec/PlistBuddy "$1/Contents/Info.plist" -c "Print :CFBundleVersion"
}

function gen_plist() {
    # Generates a plist for a given build service
    # This can be kicked off by calling launchd or used as a LaunchDaemon
cat << EOF > "$2"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.xcbuildkit.envvar</string>
  <key>ProgramArguments</key>
  <array>
    <string>sh</string>
    <string>-c</string>
    <string>
        launchctl unsetenv XCBBUILDSERVICE_PATH "$1"
        launchctl setenv XCBBUILDSERVICE_PATH "$1"
    </string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF
}

function load_plist() {
    BINARY="$(find "$INSTALLED_APP/Contents/MacOS" -type f | head)"
    if [[ "${GLOBAL:-false}" == "true" ]]; then
	PLIST="/Library/LaunchDaemons/com.xcbuildkit.envvar.plist"
	if [[ -n "$(grep "$BINARY" "$PLIST")" ]]; then 
	    # Skip the update if the binary has the right plist
	    exit 0
	fi
	# Setup as a launchdaemon so it starts up on boot
	# Otherwise, the user might open Xcode without it set.
	TEMPPLIST="$(mktemp -t pl-XXXXXXXXXX)"
	gen_plist "$BINARY" "$TEMPPLIST"
	sudo mv "$TEMPPLIST" "$PLIST"
	sudo chmod 0644 "$PLIST"
	sudo chown root:wheel "$PLIST"
	sudo launchctl load -w "$PLIST"
    else
	PLIST="$HOME/Library/LaunchAgents/com.xcbuildkit.envvar.plist"
	if [[ -n "$(grep "$BINARY" "$PLIST")" ]]; then 
	    # Skip the update if the binary has the right plist
	    exit 0
	fi
	gen_plist "$BINARY" "$PLIST"
	launchctl load -w "$PLIST"
    fi
}

# Begin install
# Normalize all XCBuildKit services to this directory. This makes it easier to
# manage multiple checkouts / builds and ensure there's only 1 installed
INSTALL_DIR="$HOME/Library/Application Support/XCBuildKit"

APP="$1"
# idiomatic parameter and option handling in sh
GLOBAL=false
while test $# -gt 0
do
    case "$1" in
	--global) GLOBAL=true
	    ;;
	*) 
	    ;;
    esac
    shift
done

if [[ ! -n "$APP" ]]; then
    echo "usage: /path/to/BuildService.app"
    echo "to run on startup as a LaunchDaemon use --global"
    exit 1
fi

# If the user provides the app as a zip then automatically unzip that
if [[ "$APP" == *.zip ]]; then
    ZIPDIR="$(mktemp -d -t z-XXXXXXXXXX)"
    unzip -q "$APP" -d "$ZIPDIR"
    APP="$(find "$ZIPDIR" -d 1 | head)"
fi

if [[ ! -d "$APP" ]]; then
    echo "Can't find .app at $APP"
    exit 1
fi

mkdir -p "$INSTALL_DIR"
EXISTING_BUILD_SERVICE="$(find "$INSTALL_DIR" -name *.app | head)"

if [[ -d "$EXISTING_BUILD_SERVICE" ]]; then
    if [[ "$(get_version "$EXISTING_BUILD_SERVICE")" == "$(get_version $APP)" ]]; then
	exit 0
    fi
fi

# Load the plist
INSTALLED_APP="$INSTALL_DIR/$(basename $APP)"
ditto "$APP" "$INSTALLED_APP"
load_plist


echo "Installer needs to re-launch Xcode"
# Attempt to gracefully quit Xcode. If the user doesn't close it then this wont
# work until the next launch
osascript -e 'quit app "Xcode"'
open "$(dirname $(dirname $(xcode-select -p)))"

