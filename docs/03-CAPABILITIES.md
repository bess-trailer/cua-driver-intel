# Capabilities — Tool Matrix

What works with cua-driver on Intel x86_64, per transport mode.

## Legend

| Icon | Meaning |
|------|---------|
| ✅ | Works |
| 🟡 | Partial / Conditional |
| ❌ | Broken / Not available |

## Tool Matrix

| Tool | CLI subprocess (recommended) | MCP stdio (deadlocked) | Daemon socket (buggy) | TCC requirement | Notes |
|------|------|------|------|------|-------|
| `list_apps` | ✅ | ❌ | ✅ | None | No args needed |
| `list_windows` | ✅ | ❌ | ✅ | None | No args needed |
| `get_screen_size` | ✅ | ❌ | ✅ | None | No args needed |
| `get_window_state` (text) | ✅ | ❌ | 🟡 | Accessibility | Daemon socket fails on pid arg |
| `get_window_state` (image) | ✅ | ❌ | 🟡 | Access. + Screen Rec. | Screenshot embedded in result |
| `click` (element) | ✅ | ❌ | 🟡 | Accessibility | Daemon socket fails on pid arg |
| `click` (coordinate) | ✅ | ❌ | 🟡 | Access. + Screen Rec. | Coordinate needs screen capture |
| `double_click` | ✅ | ❌ | 🟡 | Accessibility | |
| `right_click` | ✅ | ❌ | 🟡 | Accessibility | May fail on non-AX elements |
| `type_text` | ✅ | ❌ | 🟡 | Accessibility | Char-by-char, 20-50ms/char |
| `hotkey` | ✅ | ❌ | 🟡 | Accessibility | Combo keys like `cmd+s` |
| `scroll` | ✅ | ❌ | 🟡 | Accessibility | Tick-based |
| `drag` (element→element) | ✅ | ❌ | 🟡 | Accessibility | Stale index risk |
| `drag` (coord→coord) | ✅ | ❌ | 🟡 | Access. + Screen Rec. | Window-local pixel space |
| `focus_app` | ✅ | ❌ | 🟡 | Accessibility | Default no-raise |
| `launch_app` | ✅ | ❌ | 🟡 | None | Launch by bundle ID |
| `screenshot` | 🟡 | ❌ | 🟡 | Screen Recording | Works from bundle daemon |
| `set_value` (dropdown) | 🟡 | ❌ | 🟡 | Accessibility | Needs arg mapping test |
| `set_value` (slider) | 🟡 | ❌ | 🟡 | Accessibility | Needs arg mapping test |
| `middle_click` | ❌ | ❌ | ❌ | — | Not exposed by cua-driver at all |
| `get_cursor_position` | ✅ | ❌ | ✅ | None | No args needed |
| `list_tools` | ✅ | ❌ | ✅ | None | |

## CLI subprocess detail

Each tool call runs:

```bash
cua-driver call <tool-name> '<json-args>' --raw --compact
```

The `--raw` flag returns the full MCP `CallToolResult` JSON with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `content` | array | `[{type: "text", text: "..."}, {type: "image", data: "b64..."}]` |
| `structuredContent` | dict or null | Structured data (apps array, element tree, etc.) |
| `isError` | bool | Whether the tool returned an error |

The `--compact` flag minifies the JSON for smaller output.

## Arguments Reference

| Tool | Required args | Optional args |
|------|---------------|---------------|
| `click` | `pid`, `x`, `y` | `element_index`, `window_id`, `mouse_button`, `click_count` |
| `type_text` | `pid`, `text` | `window_id` |
| `hotkey` | `pid`, `keys` | `window_id` |
| `scroll` | `pid`, `direction` (up/down) | `amount` (default 3) |
| `drag` | `pid`, `from_x`, `from_y`, `to_x`, `to_y` | `from_element_index`, `to_element_index` |
| `get_window_state` | `pid` | `window_id` |
| `focus_app` | `pid` | — |
| `launch_app` | `bundle_id` | — |
| `set_value` | `pid`, `element_index`, `value` | `window_id` |

## Permissions Impact by Tool

| Permission needed | Tools affected | Required for CLI subprocess? |
|-------------------|----------------|------------------------------|
| **Accessibility** | click, type, scroll, drag, get_window_state, hotkey, focus_app, set_value | ✅ Yes — required for all interaction tools |
| **Screen Recording** | screenshot, get_window_state (image), click (coordinate), drag (coordinate) | ✅ Yes when working from bundle daemon. Otherwise text-only AX mode still works. |

## Unsupported

- **`middle_click`** — not in cua-driver's tool list at all (missing from upsteam, not just Intel)
- **`set_agent_cursor_*`** — would work in AppKitBootstrap path but that's deadlocked on Intel
