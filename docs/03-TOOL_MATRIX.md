# Tool Matrix

Tool availability by transport mode. CLI subprocess is the recommended path — it's the only mode where all tools work.

## Legend

✅ = works, 🟡 = partial/conditional, ❌ = broken or absent

## Matrix

| Tool | CLI subproc | MCP stdio | Daemon socket | TCC | Notes |
|------|-------------|-----------|---------------|-----|-------|
| `list_apps` | ✅ | ❌ | ✅ | None | |
| `list_windows` | ✅ | ❌ | ✅ | None | |
| `get_screen_size` | ✅ | ❌ | ✅ | None | |
| `list_tools` | ✅ | ❌ | ✅ | None | |
| `get_cursor_position` | ✅ | ❌ | ✅ | None | |
| `get_window_state` (text) | ✅ | ❌ | 🟡 | AX | Socket pid bug |
| `get_window_state` (image) | ✅ | ❌ | 🟡 | AX+SR | Embedded JPEG |
| `click(element)` | ✅ | ❌ | 🟡 | AX | |
| `click(coordinate)` | ✅ | ❌ | 🟡 | AX+SR | |
| `double_click` | ✅ | ❌ | 🟡 | AX | |
| `right_click` | ✅ | ❌ | 🟡 | AX | May fail on non-AX elements |
| `type_text` | ✅ | ❌ | 🟡 | AX | Char-by-char ~30ms/char |
| `hotkey` | ✅ | ❌ | 🟡 | AX | `cmd+s`, `return`, `escape`, etc. |
| `scroll` | ✅ | ❌ | 🟡 | AX | Tick-based, default 3 ticks |
| `drag(element→element)` | ✅ | ❌ | 🟡 | AX | |
| `drag(coord→coord)` | ✅ | ❌ | 🟡 | AX+SR | Window-local pixel space |
| `focus_app` | ✅ | ❌ | 🟡 | AX | Default no-raise |
| `launch_app` | ✅ | ❌ | 🟡 | None | Not tested |
| `screenshot` | 🟡 | ❌ | 🟡 | SR | Works from bundle daemon only |
| `set_value` | 🟡 | ❌ | 🟡 | AX | Not tested |
| `middle_click` | ❌ | ❌ | ❌ | — | Not exposed by cua-driver |
| `diagnose` | ✅ | ❌ | ✅ | None | |

## Per-tool arguments

| Tool | Required | Optional |
|------|----------|----------|
| `click` | `pid`, `x`, `y` | `element_index`, `window_id`, `mouse_button`, `click_count` |
| `type_text` | `pid`, `text` | `window_id` |
| `hotkey` | `pid`, `keys` | `window_id` |
| `scroll` | `pid`, `direction` (up/down) | `amount` (default 3) |
| `drag` | `pid`, `from_x`, `from_y`, `to_x`, `to_y` | `from_element_index`, `to_element_index` |
| `get_window_state` | `pid` | `window_id` |
| `focus_app` | `pid` | — |
| `launch_app` | `bundle_id` | — |
| `set_value` | `pid`, `element_index`, `value` | `window_id` |

## MCP `--raw` output format

```json
{
  "content": [
    {"type": "text", "text": "..."},
    {"type": "image", "data": "<base64>", "mimeType": "image/jpeg"}
  ],
  "structuredContent": {...},
  "isError": false
}
```

`structuredContent` is the parsed data (apps array, element tree, etc.). `content` has text rendering + optional base64 image.

## Unsupported

- `middle_click` — not in cua-driver's tool list at any version
- `set_agent_cursor_*` — would need AppKitBootstrap path, which is deadlocked
