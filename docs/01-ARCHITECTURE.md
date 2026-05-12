# Architecture — cua-driver on Intel x86_64

## The Stack

```
macOS Desktop (SkyLight SPIs + Accessibility APIs)
  ▲
  │
cua-driver binary (x86_64 custom build v0.1.5+)
  ▲
  │
┌────────────────────────────────────────────────────────────┐
│                     Transport Layer                        │
├────────────────┬──────────────────────┬────────────────────┤
│  MCP stdio     │   Daemon Socket      │   CLI subprocess   │
│  cua-driver mcp│   cua-driver serve   │   cua-driver call  │
│  ▲             │   + raw JSON-RPC     │   (recommended)    │
│  │             │                      │                    │
│ ❌ DEADLOCK    │ 🟡 pid serialization  │ ✅ Works always    │
│   on Intel     │    bug on arg tools   │   200ms overhead   │
└────────────────┴──────────────────────┴────────────────────┘
  ▲
  │
Hermes Agent / Codex / MCP client
```

## The Three Transport Modes

### 1. MCP stdio (`cua-driver mcp`) — THE NORMAL PATH (broken on Intel)

This is the intended upstream mode. The binary runs a stdio MCP server using Apple's open-source [Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk) (v0.9.0+). An MCP client (Hermes Agent, any MCP-compatible tool) spawns the process and communicates via stdin/stdout JSON-RPC following the MCP protocol.

**On Apple Silicon:** Works perfectly. The MCP SDK's `StdioTransport` initializes, `AppKitBootstrap.shared.ensureGranted()` completes, and tools respond.

**On Intel (iMac14,3, 4-core Core i5):** The process hangs silently:
1. `AppKitBootstrap` starts `NSApplication.shared.run()` on the main thread
2. It spawns a detached Swift concurrency Task to call `ensureGranted()`
3. The Task needs to cross `@MainActor` to interact with AppKit's permission prompts
4. The main thread is blocked in `NSApplication.shared.run()`, which IS the `@MainActor` executor
5. The cooperative thread pool on 4-core Intel doesn't have an available thread to service the `@MainActor` hop
6. Result: **cooperative pool starvation deadlock** — the Task waits forever, no bytes are written to stdout, the MCP client sees a timeout

**TCC note:** Even if the concurrency bug were fixed, the standalone binary lacks an app bundle with entitlements, so Screen Recording permission would be denied — `SCShareableContent.excludingDesktopWindows()` would return empty.

### 2. Daemon socket (`cua-driver serve` + raw JSON-RPC) — FASTER BUT BUGGY

The daemon runs as a background process listening on a Unix socket at `~/Library/Caches/cua-driver/cua-driver.sock`. It accepts JSON-RPC requests:

```json
{"jsonrpc":"2.0","method":"call","name":"get_window_state","arguments":{"pid":…}}
```

**What works:** Zero-argument tools (`list_apps`, `get_screen_size`, `list_tools`). These don't need `pid` in the arguments.

**What doesn't work:** Any tool requiring arguments (`get_window_state` with `pid`, `click` with `pid`+`x`+`y`, etc.). The daemon's argument deserialization rejects valid JSON with `"Missing required integer field pid."` — even though `pid` is present in the `arguments` object. The `cua-driver call` CLI wrapper handles this correctly (it serializes arguments differently), but the raw socket protocol does not.

**Latency:** ~1-5ms per call (no process spawn). If the serialization bug were fixed, this would be ideal.

### 3. CLI subprocess (`cua-driver call`) — THE WORKING PATH

Each tool call spawns `cua-driver call <name> '<json-args>' --raw --compact` as a subprocess. The CLI wrapper:

1. Checks if the daemon is running; starts it if not
2. Sends the request via the daemon socket (using its internal serialization, which works)
3. Waits for the response and prints it as JSON
4. Returns the exit code

The `--raw` flag outputs the MCP `CallToolResult` directly — same format the stdio MCP mode would use. The `--compact` flag minifies the JSON.

**Latency:** ~200-400ms per call (subprocess spawn). Acceptable for human-scale interactions (click, type, scroll — you wouldn't notice).

**Why it works when the raw socket doesn't:** The CLI's `DaemonClient` class handles argument encoding in a way the raw daemon socket protocol expects. We never fully reverse-engineered the difference — but the CLI works, so we use it.

## The App Bundle

```
CuaDriver.app/
└── Contents/
    ├── Info.plist        # Bundle identifier: com.trycua.driver
    └── MacOS/
        └── cua-driver    # x86_64 binary (copy, not symlink)
```

The bundle at `~/Applications/CuaDriver.app` wraps the x86_64 binary in a macOS app container with:
- A valid `Info.plist` (CFBundleIdentifier, CFBundleName, etc.)
- Ad-hoc code signature (`codesign -f -s - --deep`)
- Installation in `~/Applications/` (no sudo needed)

**What the bundle fixes:** The MCP mode's TCC gate. When run from a bundle, `PermissionsGate.shared.ensureGranted()` can present a permission dialog to the user. When run as a standalone binary, this dialog never appears.

**What the bundle does NOT fix:** The MCP concurrency deadlock. The deadlock is in `AppKitBootstrap`+`StdioTransport` interaction, not in the TCC path specifically.

**Bundle relevance today:** The daemon auto-started by `cua-driver call` also gets the daemon process launched from the bundle (via the symlink), so screen captures from `get_window_state` work. This is why SOM mode returns images on our setup — the daemon has TCC grants because it's running from the bundle.

## TCC Permission Matrix

| Permission | Standalone binary | From bundle |
|------------|-------------------|-------------|
| Accessibility | ✅ Granted to Terminal.app, cascades | ✅ Same |
| Screen Recording | ❌ Blocked (no bundle identity) | ✅ Granted to bundle, cascades to subprocesses |
| Files/Folders | ✅ Via sandbox exemptions | ✅ Same |

## Latency breakdown

| Operation | MCP stdio (arm64) | Daemon socket | CLI subprocess (Intel) |
|-----------|-------------------|---------------|----------------------|
| `list_apps` | ~50ms | ~2ms | ~200ms |
| `get_window_state` (text) | ~100ms | ~5ms | ~300ms |
| `get_window_state` (with image) | ~300ms | ~50ms | ~600ms |
| `click(element)` | ~50ms | ~5ms | ~250ms |
| `type("hello")` | ~100ms | ~10ms | ~300ms |
| `screenshot` | ~200ms | ~40ms | ~500ms |

## Future

If the cua team:
- **Fixes the concurrency deadlock** in `AppKitBootstrap` on Intel: the MCP stdio path becomes viable. The bundle still needed for TCC.
- **Fixes the daemon pid serialization**: the raw socket path becomes the best option (~2ms latency).
- **Builds and ships x86_64 binaries**: no more custom build process needed.

Until then, the CLI subprocess path is the stable, working, recommended choice.
