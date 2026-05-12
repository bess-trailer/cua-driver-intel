#!/usr/bin/env bash
set -euo pipefail

# verify-bundle.sh — Check that CuaDriver.app is properly set up

BUNDLE_DIR="${HOME}/Applications/CuaDriver.app"
BINARY="${BUNDLE_DIR}/Contents/MacOS/cua-driver"
PLIST="${BUNDLE_DIR}/Contents/Info.plist"
SYMLINK="/usr/local/bin/cua-driver"

echo "=== Bundle verification ==="
echo ""

errors=0

echo -n "[1] Bundle exists at ~/Applications/CuaDriver.app ... "
if [ -d "$BUNDLE_DIR" ]; then
    echo "✅"
else
    echo "❌"
    errors=$((errors + 1))
fi

echo -n "[2] Binary exists ... "
if [ -f "$BINARY" ]; then
    echo "✅"
    echo "    Size: $(stat -f '%z' "$BINARY") bytes"
else
    echo "❌"
    errors=$((errors + 1))
fi

echo -n "[3] Binary is executable ... "
if [ -x "$BINARY" ]; then
    echo "✅"
else
    echo "❌"
    errors=$((errors + 1))
fi

echo -n "[4] Info.plist exists ... "
if [ -f "$PLIST" ]; then
    PLIST_ID=$(plutil -p "$PLIST" 2>/dev/null | grep CFBundleIdentifier | head -1 || echo "missing")
    echo "✅ ($PLIST_ID)"
else
    echo "❌"
    errors=$((errors + 1))
fi

echo -n "[5] Binary version ... "
VER=$("$BINARY" --version 2>&1 || echo "")
if [ -n "$VER" ]; then
    echo "✅ v${VER}"
else
    echo "❌"
    errors=$((errors + 1))
fi

echo -n "[6] Code signature ... "
SIG=$(codesign -dvvv "$BUNDLE_DIR" 2>&1 | grep "Signature=" || echo "")
if echo "$SIG" | grep -q "adhoc"; then
    echo "✅ (ad-hoc)"
elif [ -z "$SIG" ]; then
    echo "❌ unsigned"
    errors=$((errors + 1))
else
    echo "✅ ($SIG)"
fi

echo -n "[7] Symlink at /usr/local/bin/cua-driver ... "
if [ -L "$SYMLINK" ]; then
    TARGET=$(readlink "$SYMLINK")
    echo "✅ → $TARGET"
elif [ -f "$SYMLINK" ]; then
    echo "⚠️  exists but is a regular file (not symlink)"
else
    echo "❌ not found"
    errors=$((errors + 1))
fi

echo -n "[8] Bundle binary responds via symlink ... "
RESULT=$("$SYMLINK" call get_screen_size 2>&1 | head -1)
if echo "$RESULT" | grep -qi "display"; then
    echo "✅"
else
    echo "⚠️  $RESULT"
fi

echo ""
if [ "$errors" -eq 0 ]; then
    echo "✅ All checks passed."
else
    echo "❌ ${errors} check(s) failed."
fi
