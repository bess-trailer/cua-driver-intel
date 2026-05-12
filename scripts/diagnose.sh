#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== cua-driver Intel Diagnostics ==="
echo ""

# --- Architecture ---
ARCH=$(uname -m)
echo -n "[arch] CPU architecture: $ARCH ... "
if [ "$ARCH" = "x86_64" ]; then
    echo -e "${YELLOW}Intel${NC} — this repo is for you."
elif [[ "$ARCH" == arm* ]]; then
    echo -e "${GREEN}Apple Silicon${NC} — you probably don't need this repo."
else
    echo -e "${RED}unknown${NC} — unexpected architecture."
fi
echo ""

# --- Binary ---
echo "--- cua-driver binary ---"
if command -v cua-driver &>/dev/null; then
    BIN=$(command -v cua-driver)
    echo -e "[binary] Path: ${BIN}"
    VER=$(cua-driver --version 2>&1 || echo "unknown")
    echo -e "[binary] Version: ${VER}"
    # Check if running from bundle
    REALPATH=$(perl -e 'print readlink("'"$BIN"'")' 2>/dev/null || echo "$BIN")
    if echo "$REALPATH" | grep -q "CuaDriver.app"; then
        echo -e "[binary] ${GREEN}Running from app bundle${NC}: ${REALPATH}"
    else
        echo -e "[binary] ${YELLOW}Standalone binary${NC}: ${REALPATH}"
    fi
else
    echo -e "[binary] ${RED}Not found in PATH${NC}"
fi
echo ""

# --- Bundle ---
echo "--- App bundle ---"
if [ -d ~/Applications/CuaDriver.app ]; then
    echo -e "[bundle] ${GREEN}Exists${NC} at ~/Applications/CuaDriver.app"
    codesign -dvvv ~/Applications/CuaDriver.app 2>&1 | grep -E "Identifier|Signature|TeamIdentifier" | head -3 || echo "[bundle] (unsigned/ad-hoc)"
else
    echo -e "[bundle] ${YELLOW}Not found${NC} at ~/Applications/CuaDriver.app"
fi
echo ""

# --- Daemon ---
echo "--- Daemon ---"
DAEMON_PIDS=$(pgrep -f "cua-driver serve" 2>/dev/null || true)
if [ -n "$DAEMON_PIDS" ]; then
    echo -e "[daemon] ${GREEN}Running${NC} — PIDs: ${DAEMON_PIDS}"
else
    echo -e "[daemon] ${YELLOW}Not running${NC}"
fi
echo ""

# --- Socket ---
SOCKET=~/Library/Caches/cua-driver/cua-driver.sock
echo "--- Socket ---"
if [ -S "$SOCKET" ]; then
    echo -e "[socket] ${GREEN}Exists${NC}: ${SOCKET}"
else
    echo -e "[socket] ${YELLOW}Not found${NC} (normal if daemon not running)"
fi
echo ""

# --- Daemon health (if socket exists) ---
if [ -S "$SOCKET" ]; then
    echo "--- Daemon health check ---"
    # Quick test — list_tools via daemon
    RESULT=$(cua-driver call list_tools 2>&1 | head -1)
    if echo "$RESULT" | grep -qi "error\|timeout\|refused"; then
        echo -e "[health] ${RED}Socket unhealthy${NC}: ${RESULT}"
    else
        echo -e "[health] ${GREEN}Daemon responding${NC}"
    fi
    echo ""
fi

# --- Tool test ---
echo "--- Tool smoke test ---"
TOOLS=$(cua-driver list-tools 2>&1 | wc -l || echo "0")
echo -e "[tools] ${TOOLS} tools available"

echo ""
echo "=== Diagnostic complete ==="
echo ""
echo "Quick fixes:"
echo "  Kill stale daemon:  pkill -f \"cua-driver serve\"; rm -f ~/Library/Caches/cua-driver/cua-driver.sock"
echo "  Create bundle:      bash bundle/create-bundle.sh /usr/local/bin/cua-driver"
echo "  Start daemon:       cua-driver serve &"
