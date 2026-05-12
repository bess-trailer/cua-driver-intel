# Contributing

## Reproduce the MCP deadlock

```bash
cua-driver mcp < /dev/null
# → hangs. Must be killed -9. No output.

sample $(pgrep -f "cua-driver mcp") 5 -file /tmp/sample.txt
# Expected: main thread in NSApp.run(), co-op threads blocked on @MainActor hop
```

## Test a potential fix

```bash
# 1. MCP mode — should exit cleanly with initialize response
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | cua-driver mcp

# 2. Daemon — all tools should respond
cua-driver serve &
sleep 2
cua-driver call get_window_state '{"pid":'"$(pgrep -x Finder)"',"window_id":0}'

# 3. Screenshot (TCC test)
cua-driver call screenshot
```

## Investigate the daemon pid serialization bug

```bash
# Zero-arg works:
echo '{"jsonrpc":"2.0","method":"call","name":"list_apps","arguments":{}}' | nc -U ~/Library/Caches/cua-driver/cua-driver.sock

# Arg-based fails (returns "Missing required integer field pid."):
echo '{"jsonrpc":"2.0","method":"call","name":"get_window_state","arguments":{"pid":'"$(pgrep -x Finder)"',"window_id":0}}' | nc -U ~/Library/Caches/cua-driver/cua-driver.sock
```

Likely in the daemon's JSON-RPC argument decoder. Compare what `cua-driver call` actually sends vs raw socket by intercepting socket traffic.

## Upstream goals

Making this repo unnecessary:
- **cua team:** headless MCP mode (skip `AppKitBootstrap` in stdio mode) + x86_64 binary releases
- **Hermes:** upstream the `_CliCallSession` backend with arch-detect fallback

Before reporting an issue: `bash scripts/diagnose.sh` and include the output.
