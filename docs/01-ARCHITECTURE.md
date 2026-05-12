# Architecture

Three transport modes. One works on Intel. This is why.

## The Stack

```
Agent (Hermes / Codex / MCP client)
  │
  ├── MCP stdio (cua-driver mcp)           ❌ deadlock on 4-core Intel
  ├── Daemon socket (raw JSON-RPC)          🟡 pid serialization bug
  └── CLI subprocess (cua-driver call)      ✅ recommended
        └── daemon socket ←→ cua-driver serve
              └── SkyLight SPIs + Accessibility APIs
```

## 1. MCP stdio — Upstream path, deadlocked on Intel

`cua-driver mcp` starts `NSApplication.shared.run()` on the main thread via `AppKitBootstrap`, then spawns a detached Swift concurrency Task to call `PermissionsGate.shared.ensureGranted()`. On 4-core/4-thread Intel:

1. Main thread blocked in `NSApp.run()` — this IS the `@MainActor` executor
2. Detached Task calls `SCShareableContent.excludingDesktopWindows()` — needs `@MainActor` hop
3. No cooperative thread available to service the hop → ∞ await
4. `StdioTransport` never initializes → zero bytes on stdout → MCP client times out at 15s

**Upstream fix would require** either: (a) headless MCP mode that skips `AppKitBootstrap` when stdin is a pipe, or (b) moving TCC probe off the concurrency thread pool into a dedicated thread.

> ⚠️ Reproduced on iMac14,3 (4-core Core i5, macOS 15.7.5). May not apply to Intel Macs with >4 threads or different Swift runtime.

**Bundle effect on MCP:** Wrapping the binary in CuaDriver.app (with ad-hoc signing) lets `ensureGranted()` clear the TCC gate — the process exits cleanly on `/dev/null` stdin. The concurrency deadlock on real MCP handshake persists regardless.

## 2. Daemon socket — Low latency, broken arg serialization

`cua-driver serve` listens on `~/Library/Caches/cua-driver/cua-driver.sock`. Protocol:

```json
{"jsonrpc":"2.0","method":"call","name":"<tool>","arguments":{...}}
```

Zero-arg tools work (~2ms). Tools requiring `pid` in `arguments` return `"Missing required integer field pid."` — the daemon's argument deserializer fails to parse `pid` from the JSON object, but `cua-driver call` (which uses the same socket internally) handles it correctly. Likely a difference in how the CLI's `DaemonClient` serializes args vs raw JSON-RPC framing — we didn't fully trace it because the CLI wrapper works.

## 3. CLI subprocess — Works, ~200ms overhead

`cua-driver call <tool> '<json-args>' --raw --compact` is a thin CLI wrapper that:
- Starts the daemon if not running
- Serializes args correctly (the daemon parses them from this wrapper)
- Returns MCP `CallToolResult` JSON (same format MCP stdio would use)
- `--raw`: full MCP response with `content[]`, `structuredContent`, `isError`
- `--compact`: minified JSON

The `--raw` flag is critical for programmatic use — without it the CLI unwraps `structuredContent` and prettifies, which is human-readable but harder to parse programmatically.

## Bundle

```
~/Applications/CuaDriver.app/Contents/
├── Info.plist    # com.trycua.driver, 14 keys
└── MacOS/
    └── cua-driver # x86_64 binary (copy), ad-hoc signed
```

`/usr/local/bin/cua-driver` symlinks into this bundle. The daemon spawned by `cua-driver call` inherits the bundle identity, which satisfies Screen Recording TCC. This is why SOM captures return screenshots.

Bundling does NOT fix the MCP deadlock — that's in AppKitBootstrap, not in TCC.

## TCC

| Permission | Standalone binary | From bundle |
|------------|-------------------|-------------|
| Accessibility | ✅ (inherits from Terminal) | ✅ |
| Screen Recording | ❌ (no bundle identity) | ✅ (bundle + ad-hoc sign) |

AX-mode tools (click, type, scroll, drag, hotkey, focus_app, get_window_state text) need only Accessibility. SOM/vision mode needs both.
