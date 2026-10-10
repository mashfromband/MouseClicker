#!/bin/bash
# Builds MouseClicker.app (release) in ./build. Requires macOS + Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/MouseClicker.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MouseClicker "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MouseClicker</string>
<key>CFBundleIdentifier</key><string>local.mouseclicker</string>
<key>CFBundleExecutable</key><string>MouseClicker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Ad-hoc sign so macOS keeps the Accessibility grant stable between launches.
codesign --force --deep --sign - "$APP"
echo "Built $APP"
