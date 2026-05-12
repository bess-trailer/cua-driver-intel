#!/usr/bin/env bash
set -euo pipefail

# create-bundle.sh — Wrap a cua-driver binary in CuaDriver.app
# Usage: bash create-bundle.sh /path/to/cua-driver [--install]

BINARY="${1:-}"
INSTALL="${2:-}"

if [ -z "$BINARY" ]; then
    echo "Usage: bash create-bundle.sh /path/to/cua-driver [--install]"
    echo ""
    echo "  --install    Also symlink /usr/local/bin/cua-driver to the bundle"
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

BUNDLE_DIR="$HOME/Applications/CuaDriver.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
PLIST="$CONTENTS_DIR/Info.plist"
BUNDLE_BINARY="$MACOS_DIR/cua-driver"

echo "Creating CuaDriver.app at $BUNDLE_DIR"
mkdir -p "$MACOS_DIR"

# Copy the binary
echo "Copying binary..."
cp "$BINARY" "$BUNDLE_BINARY"
chmod +x "$BUNDLE_BINARY"

# Write Info.plist
echo "Writing Info.plist..."
cat > "$PLIST" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Cua Driver</string>
    <key>CFBundleExecutable</key>
    <string>cua-driver</string>
    <key>CFBundleIdentifier</key>
    <string>com.trycua.driver</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Cua Driver</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.5</string>
    <key>CFBundleVersion</key>
    <string>0.1.5</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>cua-driver needs accessibility and screen recording permissions for desktop automation.</string>
</dict>
</plist>
PLISTEOF

# Ad-hoc sign
echo "Code-signing (ad-hoc)..."
codesign -f -s - --deep "$BUNDLE_DIR" 2>&1

echo ""
echo "Bundle created at: $BUNDLE_DIR"

# Verify
SIGNATURE=$(codesign -dvvv "$BUNDLE_DIR" 2>&1 | grep "Signature=" || echo "none")
echo "Signature: $SIGNATURE"

# Optionally install symlink
if [ "$INSTALL" = "--install" ]; then
    echo ""
    echo "Setting up /usr/local/bin/cua-driver symlink..."
    if [ -L /usr/local/bin/cua-driver ] || [ -f /usr/local/bin/cua-driver ]; then
        rm -f /usr/local/bin/cua-driver
    fi
    ln -s "$BUNDLE_BINARY" /usr/local/bin/cua-driver
    echo "Symlink created: /usr/local/bin/cua-driver -> $BUNDLE_BINARY"
    echo ""
    echo "Verifying..."
    /usr/local/bin/cua-driver --version
fi

echo ""
echo "Done."
echo ""
echo "Test with:"
echo "  /usr/local/bin/cua-driver call list_apps"
