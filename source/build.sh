#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='Mantimento.app/Contents'
mkdir -p "$APP/MacOS" "$APP/Resources"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 source/App.swift source/Agent.swift source/AgentViews.swift source/ChatViews.swift source/SettingsView.swift -o "$APP/MacOS/Mantimento"
cp source/requirements-macos-arm64.txt "$APP/Resources/requirements-macos-arm64.txt"
cp source/command_runner.py "$APP/Resources/command_runner.py"
cp source/runtime.sh "$APP/Resources/runtime.sh"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Mantimento</string>
<key>CFBundleIdentifier</key><string>local.mantimento.mac</string>
<key>CFBundleName</key><string>Mantimento</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
codesign --force --deep --sign - 'Mantimento.app'
