#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash source/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'Qwen Local.app/Contents/Info.plist')
ARCHIVE="QwenLocal-${VERSION}-macOS-arm64.zip"
mkdir -p dist
codesign --verify --deep --strict 'Qwen Local.app'
/usr/bin/ditto -c -k --sequesterRsrc --keepParent 'Qwen Local.app' "dist/$ARCHIVE"
/usr/bin/unzip -tq "dist/$ARCHIVE"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
/usr/bin/ditto -x -k "dist/$ARCHIVE" "$CHECK_DIR"
test -x "$CHECK_DIR/Qwen Local.app/Contents/MacOS/QwenLocal"
codesign --verify --deep --strict "$CHECK_DIR/Qwen Local.app"
cd dist
/usr/bin/shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Pronto: dist/$ARCHIVE"
