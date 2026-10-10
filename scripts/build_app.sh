#!/bin/bash
# Builds MouseClicker.app (release) in ./build. Requires macOS + Xcode command line tools.
# The app is signed with a stable local certificate so the Accessibility permission
# survives rebuilds (ad-hoc signatures change on every build and invalidate the grant).
set -euo pipefail
cd "$(dirname "$0")/.."
CERT="MouseClicker Local Signing"

ensure_cert() {
  if security find-certificate -c "$CERT" >/dev/null 2>&1; then return; fi
  echo "Creating local code-signing certificate '$CERT' (login password may be requested)..."
  local tmp; tmp=$(mktemp -d)
  cat > "$tmp/openssl.cnf" <<CNF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$CERT
[ext]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=critical,CA:false
CNF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "$tmp/k.pem" -out "$tmp/c.pem" -config "$tmp/openssl.cnf" 2>/dev/null
  openssl pkcs12 -export -inkey "$tmp/k.pem" -in "$tmp/c.pem" -out "$tmp/id.p12" -passout pass:mc -legacy 2>/dev/null \
    || openssl pkcs12 -export -inkey "$tmp/k.pem" -in "$tmp/c.pem" -out "$tmp/id.p12" -passout pass:mc
  security import "$tmp/id.p12" -k ~/Library/Keychains/login.keychain-db -P mc -T /usr/bin/codesign
  security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$tmp/c.pem" || true
  rm -rf "$tmp"
}

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

ensure_cert
if codesign --force --deep --sign "$CERT" "$APP" 2>/dev/null; then
  echo "Signed with '$CERT'"
else
  echo "Warning: falling back to ad-hoc signing; re-grant Accessibility after each rebuild."
  codesign --force --deep --sign - "$APP"
fi
echo "Built $APP"
