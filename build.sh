#!/bin/bash
# Builds build/NightOwl.app. Pass "install" to also copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/NightOwl.app
SWIFT_FLAGS=(-O -swift-version 5 -target "$(uname -m)-apple-macos13.0")

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc "${SWIFT_FLAGS[@]}" Sources/OwlArt.swift Tools/IconRenderer/main.swift -o build/icon-renderer
build/icon-renderer appicon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

swiftc "${SWIFT_FLAGS[@]}" Sources/*.swift -o "$APP/Contents/MacOS/NightOwl"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x NightOwl || true
    rm -rf /Applications/NightOwl.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/NightOwl.app"
fi
