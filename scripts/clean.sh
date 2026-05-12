#!/usr/bin/env bash
set -euo pipefail

# clean.sh — Kill daemons, remove stale sockets, reset state

echo "=== Cleaning cua-driver state ==="

# Kill all cua-driver processes
echo "[1/3] Killing cua-driver processes..."
pkill -f "cua-driver serve" 2>/dev/null || true
pkill -f "cua-driver" 2>/dev/null || true
sleep 1

# Remove socket, pid, lock files
echo "[2/3] Removing stale files..."
rm -f ~/Library/Caches/cua-driver/cua-driver.sock
rm -f ~/Library/Caches/cua-driver/cua-driver.pid
rm -f ~/Library/Caches/cua-driver/cua-driver.lock

# Verify nothing is left
echo "[3/3] Verifying..."
sleep 1
REMAINING=$(pgrep -f "cua-driver" 2>/dev/null || true)
if [ -n "$REMAINING" ]; then
    echo "Warning: processes still running: $REMAINING"
    echo "  Try: kill -9 $REMAINING"
else
    echo "All clear — no cua-driver processes running."
fi

echo ""
echo "Done. Start fresh with:"
echo "  cua-driver serve &"
echo "  cua-driver call list_apps"
