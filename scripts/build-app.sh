#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
(cd "$ROOT" && swift build -c release --product TodoBar)
BIN_DIR=$(cd "$ROOT" && swift build -c release --show-bin-path)
APP="$ROOT/.build/Todo Bar.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
cp "$BIN_DIR/TodoBar" "$CONTENTS/MacOS/TodoBar"

cat >"$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>TodoBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.dudong2.TodoBar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Todo Bar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
