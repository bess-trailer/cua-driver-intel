# Contributing

How to test, reproduce, and contribute to fixing cua-driver on Intel.

## Reproducing the MCP Deadlock

This is the core issue — `cua-driver mcp` hangs on 4-core Intel Macs:

```bash
# Reproduce
cua-driver mcp < /dev/null
# → Process starts but NEVER exits.
# → No output on stdout or stderr.
# → Must be killed with `kill -9`.

# Confirm architecture
uname -m
# → x86_64
```

The process is alive but blocked. Capture a stack trace:

```bash
# Get PID
pgrep -f "cua-driver mcp"

# Sample the process (non-destructive)
sample $PID 5 -file /tmp/cua-driver-mcp-sample.txt
cat /tmp/cua-driver-mcp-sample.txt | head -50
```

Expected patterns in the sample:
- Main thread blocked in `NSApplication.shared.run()`
- Cooperative thread(s) blocked in `await` on `@MainActor` hop
- No threads making progress through `StdioTransport`

## Testing a Potential Fix

If you have a modified binary (self-compiled or from cua team), test each transport:

```bash
# 1. MCP stdio
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | cua-driver mcp
# Expected: exits cleanly with an initialize result (not hangs)

# 2. Daemon
cua-driver serve &
sleep 2
cua-driver call list_apps
cua-driver call get_screen_size
cua-driver call get_window_state '{"pid":'"$(pgrep -x Finder)"',"window_id":0}'
# Expected: all return results

# 3. Screenshot (TCC test)
cua-driver call screenshot
# Expected: saves a PNG file
```

## Testing the Daemon Protocol

If you want to work on the raw daemon socket (`pid` serialization bug), the test flow is:

```bash
# Start daemon
cua-driver serve &
sleep 2

# Test zero-arg (should work)
echo '{"jsonrpc":"2.0","method":"call","name":"list_apps","arguments":{}}' | nc -U ~/Library/Caches/cua-driver/cua-driver.sock

# Test with args (currently fails)
echo '{"jsonrpc":"2.0","method":"call","name":"get_window_state","arguments":{"pid":'"$(pgrep -x Finder)"',"window_id":0}}' | nc -U ~/Library/Caches/cua-driver/cua-driver.sock
# Expected: returns element tree
# Actual: "Missing required integer field pid."
```

The fix would be in the daemon's JSON-RPC argument decoder. Compare with what the CLI wrapper actually sends by intercepting the socket traffic.

## Running the Diagnostics

Before reporting an issue:

```bash
bash scripts/diagnose.sh > /tmp/cua-diag.txt
cat /tmp/cua-diag.txt
```

Include the output in your issue report.

## Upstream Integration

The ultimate goal is to make this repo unnecessary. Paths:

1. **cua team fixes the MCP deadlock** → implement headless MCP mode (skip `AppKitBootstrap`, don't call `NSApplication.shared.run()` in MCP mode)
2. **cua team builds x86_64 binaries** → distribute alongside arm64 in releases
3. **Hermes Agent upstreams the CLI subprocess backend** → the `_CliCallSession` patch becomes the default on Intel, with a smooth fallback

If you're contributing to either upstream, the architecture doc and the Hermes backend patch are your starting points.
