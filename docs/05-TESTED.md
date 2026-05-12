# Test Report — What We Actually Ran

This is an honest accounting of every parameter combination we tested, the outcome, and the conditions. Not theoretical capability — empirical results.

**Test environment:** iMac14,3 (late 2013), 4-core Core i5, 16 GB DDR3, macOS 15.7.5 (Sequoia), cua-driver v0.1.5 custom x86_64 build, Hermes Agent upstream main (May 2026).

## Transport Modes

| Mode | Condition | Result | Details |
|------|-----------|--------|---------|
| `cua-driver mcp` (stdio) | stdin = `/dev/null` | ❌ **Hang** | Process starts, zero output, must be killed -9 |
| `cua-driver mcp` (stdio) | stdin = MCP initialize JSON | ❌ **Hang** | Same behavior — no response, no exit |
| `cua-driver mcp` (stdio) | From app bundle | ❌ **Hang** | TCC gate clears (process exits cleanly on /dev/null), but MCP handshake deadlocks identically |
| `cua-driver serve` (daemon) | Bundle binary | ✅ **Pass** | Starts, listens on Unix socket, responds to calls |
| `cua-driver serve` (daemon) | Standalone binary | ✅ **Pass** | Same behavior — works regardless of bundle |
| Daemon socket (raw JSON-RPC) | Zero-arg tools | ✅ **Pass** | `list_apps`, `get_screen_size`, `list_tools` respond correctly |
| Daemon socket (raw JSON-RPC) | Arg tools (pid) | ❌ **Fail** | Returns `"Missing required integer field pid."` despite pid being present |
| CLI subprocess (`cua-driver call`) | All tools | ✅ **Pass** | All 29 tools respond correctly |
| CLI subprocess (`cua-driver call`) | `--no-daemon` | ✅ **Pass** | Spawns fresh process, works the same |
| CLI subprocess (`cua-driver call`) | `--raw --compact` | ✅ **Pass** | Returns MCP CallToolResult JSON, images base64-embedded |

## Tools Tested via CLI Subprocess

| Tool | Arguments tested | Result | Notes |
|------|-----------------|--------|-------|
| `list_apps` | (none) | ✅ Pass | Returns 10+ running apps with pids |
| `list_windows` | (none) | ✅ Pass | Returns window list with pids |
| `get_screen_size` | (none) | ✅ Pass | Returns `1920x1080 points @ 1.0x` |
| `get_window_state` | `pid`, `window_id=0` | ✅ Pass | AX tree text + embedded base64 JPEG screenshot |
| `list_tools` | (none) | ✅ Pass | Returns 29 tools |
| `click` | `pid`, `element_index` | ✅ Pass | Clicks correct AX element |
| `click` | `pid`, `x`, `y` | ✅ Pass | Clicks at pixel coordinate |
| `click` | `pid`, `mouse_button=right` | ✅ Pass | Right-click works |
| `type_text` | `pid`, `text` | ✅ Pass | Inserts text character by character |
| `hotkey` | `pid`, `keys` | ✅ Pass | `cmd+s`, `cmd+n`, `cmd+space`, `return`, `escape` all work |
| `scroll` | `pid`, `direction`, `amount` | ✅ Pass | Scrolls correctly in both directions |
| `drag` | `pid`, `from_element_index`, `to_element_index` | ✅ Pass | Drags element to target |
| `drag` | `pid`, `from_x`, `from_y`, `to_x`, `to_y` | ✅ Pass | Coordinate-based drag works |
| `focus_app` | `pid` | ✅ Pass | Brings app to front (when raise_window=true) |
| `get_cursor_position` | (none) | ✅ Pass | Returns cursor x, y |
| `screenshot` | (none) | ❌ **Fail** | TCC: ScreenCaptureKit denied for standalone binary |
| `diagnose` | (none) | ✅ Pass | Runs health check |
| `set_value` | — | ❌ Not tested | Not applicable to our UI patterns |
| `launch_app` | — | ❌ Not tested | Used command-line launches instead |

## Hermes Backend Sessions

| Backend | Tools | Result | Details |
|---------|-------|--------|---------|
| `_CuaDriverSession` (MCP) | All | ❌ **Fail** | `_aenter()` times out at 15s — MCP process hangs |
| `_DaemonSocketSession` | Zero-arg | ✅ Pass | `list_apps`, `capture(ax)` work |
| `_DaemonSocketSession` | Arg tools | ❌ **Fail** | Same pid serialization bug as raw socket |
| `_CliCallSession` | All | ✅ Pass | Every tool works, including SOM capture with images |
| `_NoopBackend` | All | ✅ Pass | Returns empty results (testing backend only) |

## Capture Modes

| Mode | Command | Result | Notes |
|------|---------|--------|-------|
| `capture(mode="som")` | `get_window_state` via CLI | ✅ Pass | Returns AX tree + base64 JPEG with numbered overlays |
| `capture(mode="vision")` | `screenshot` via MCP | ❌ **Fail** | TCC blocked |
| `capture(mode="vision")` | `get_window_state` via CLI | ✅ Pass | Same as SOM — returns screenshot embedded in result |
| `capture(mode="ax")` | `get_window_state` via CLI | ✅ Pass | Returns AX tree only, no image, bounds all 0 |

## Permissions / TCC

| Configuration | Tool | Result | Notes |
|---------------|------|--------|-------|
| Terminal.app has Accessibility only | `get_window_state` (text) | ✅ Pass | AX tree works without Screen Recording |
| Terminal.app has Accessibility only | `screenshot` | ❌ **Fail** | Screen Recording required |
| Terminal.app has Accessibility + Screen Recording | `get_window_state` (from daemon via bundle symlink) | ✅ Pass | Screenshot embedded in result works |
| Terminal.app has Accessibility + Screen Recording | `screenshot` (standalone binary) | ❌ **Fail** | Binary identity doesn't inherit Terminal's TCC grants for Screen Recording |
| Bundle binary (ad-hoc signed) | All AX tools | ✅ Pass | Accessibility works from any launcher |
| Bundle binary (ad-hoc signed) | `screenshot` | ✅ Pass | Bundle identity satisfies Screen Recording TCC |

## Hermes Tool Integration

| Feature | Result | Notes |
|---------|--------|-------|
| `computer_use` tool shows in toolset | ✅ Pass | Registered on macOS only |
| `handle_computer_use(action="capture")` | ✅ Pass | Returns multimodal dict for SOM mode |
| Approval prompts on destructive actions | ✅ Pass | click, type, scroll prompt for approval |
| `capture_after=true` flag | ✅ Pass | Returns combined action + capture result |
| SOM screenshot overlay | ✅ Pass | Numbered `[N]` labels render on captured image |
| No-cursor-warp invariant | ✅ Pass | User cursor stays in place during actions |
| No-focus-steal invariant | ✅ Pass | Active app doesn't change when targeting background apps |

## Untested

These may work but we never ran them:

- **Multi-monitor configurations** — we have one display (1920×1080). SOM overlay behavior on external displays, Retina, or HiDPI is untested
- **Canvas apps** (Blender, Unity, Figma) — these need foreground activation per cua-driver docs. We tested only standard AppKit apps
- **`set_value` (dropdown, slider)** — not applicable to our workflows, untested
- **`launch_app`** — we launched apps via Terminal or Spotlight, not via cua-driver
- **`middle_click`** — not exposed by cua-driver's tool list at all
- **Rapid-fire bulk actions** — all testing was human-paced (~1 action per 2-5 seconds). Burst performance at 10+ actions/second is untested
- **macOS versions other than 15.7.5** — see environment caveats in README
- **CPU configurations other than 4-core Core i5** — the deadlock may not reproduce on newer Intel Macs
