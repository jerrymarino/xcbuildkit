#!/bin/bash

# Generates a plist for a given build service
# This can be kicked off by calling launchd or used as a LaunchDaemon
if [[ ! -n "$1" ]]; then
    echo "usage: /path/to/buildservice"
    exit 1
fi

cat << EOF
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

