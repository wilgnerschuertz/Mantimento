#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash source/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'Mantimento.app/Contents/Info.plist')
ARCHIVE="Mantimento-${VERSION}-macOS-arm64.zip"
mkdir -p dist
codesign --verify --deep --strict 'Mantimento.app'
/usr/bin/ditto -c -k --sequesterRsrc --keepParent 'Mantimento.app' "dist/$ARCHIVE"
/usr/bin/unzip -tq "dist/$ARCHIVE"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
/usr/bin/ditto -x -k "dist/$ARCHIVE" "$CHECK_DIR"
test -x "$CHECK_DIR/Mantimento.app/Contents/MacOS/Mantimento"
codesign --verify --deep --strict "$CHECK_DIR/Mantimento.app"
cd dist
/usr/bin/shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Pronto: dist/$ARCHIVE"
