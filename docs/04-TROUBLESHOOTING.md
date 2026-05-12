# Troubleshooting

Symptom → cause → fix reference for common cua-driver-on-Intel problems.

## "computer_use backend unavailable: " (empty error)

| | |
|---|---|
| **Symptom** | Hermes logs show 15s timeout, empty error message. `cua-driver mcp` process starts but produces no output. |
| **Cause** | MCP stdio deadlock on Intel — AppKitBootstrap + Swift concurrency cooperative pool starvation on 4 cores |
| **Fix** | Use the CLI subprocess backend. Apply the patch in `patches/hermes-cua-backend.patch` and restart Hermes |
| **Verify** | `cua-driver call list_apps` should return app list |

## "Missing required integer field pid"

| | |
|---|---|
| **Symptom** | Tools requiring `pid` (click, get_window_state, type_text, etc.) fail with this message even though `pid` is provided |
| **Cause** | Daemon socket JSON-RPC argument deserialization bug. The raw socket protocol doesn't parse `pid` correctly from the `arguments` dict |
| **Fix** | Use `cua-driver call` CLI wrapper instead of raw socket. The CLI handles serialization correctly |
| **Verify** | `cua-driver call get_window_state '{"pid":61600,"window_id":0}'` should return the AX tree |

## Daemon starts but socket doesn't appear

| | |
|---|---|
| **Symptom** | `cua-driver call` hangs. `ls -la ~/Library/Caches/cua-driver/` shows no socket file |
| **Cause** | Stale lock/pid file from a previous daemon crash. The daemon starts but exits immediately because the lock file exists |
| **Fix** | Run `bash scripts/clean.sh` to remove stale files, then start the daemon fresh |
| **Verify** | `cua-driver call list_apps` returns immediately |

## Screenshots not returning in capture

| | |
|---|---|
| **Symptom** | `capture(mode="som")` returns AX tree but no image. `capture(mode="vision")` returns empty |
| **Cause** | Screen Recording permission denied to the daemon process. Either the binary isn't in an app bundle, or the bundle doesn't have the entitlement |
| **Fix** | Create the app bundle with `bash bundle/create-bundle.sh`. Ensure Screen Recording is granted to Terminal.app or CuaDriver.app in System Settings |
| **Fallback** | Use `capture(mode="ax")` — works with Accessibility permission only |

## Two daemon instances running

| | |
|---|---|
| **Symptom** | `pgrep -f "cua-driver serve"` shows two PIDs. Socket file exists but `cua-driver call` returns inconsistent results |
| **Cause** | Multiple daemon processes started via different methods (bundle binary + standalone binary) |
| **Fix** | Kill all daemons: `bash scripts/clean.sh`. Restart fresh: `cua-driver serve &` |

## "No cached AX state for pid"

| | |
|---|---|
| **Symptom** | Element-indexed click returns: "No cached AX state for pid N" |
| **Cause** | You called `click(element=7)` without calling `get_window_state` first for that pid. The daemon caches AX state per pid — element indices require a prior capture |
| **Fix** | Call `cua-driver call get_window_state '{"pid":...}'` before indexed clicks. In Hermes, call `capture(app="...")` first |
| **Verify** | `cua-driver call get_window_state '{"pid":61600,"window_id":0}'` followed by `cua-driver call click '{"pid":61600,"element_index":7}'` |

## "Unknown option '--pid'" (or similar)

| | |
|---|---|
| **Symptom** | `cua-driver call click --pid 61600 --x 100 --y 100` fails |
| **Cause** | Incorrect syntax. `cua-driver call` takes arguments as a JSON string, not as CLI flags |
| **Fix** | Use JSON format: `cua-driver call click '{"pid":61600,"x":100,"y":100}'` |
| **Verify** | Check the help: `cua-driver call --help` |

## Binary not found after bundle install

| | |
|---|---|
| **Symptom** | `cua-driver --version` returns "command not found" after creating the bundle |
| **Cause** | The `--install` flag wasn't passed to `create-bundle.sh`, or the symlink was created but `/usr/local/bin` isn't in PATH |
| **Fix** | Run `bash bundle/create-bundle.sh /path/to/binary --install`, or manually symlink: `ln -s ~/Applications/CuaDriver.app/Contents/MacOS/cua-driver /usr/local/bin/cua-driver` |

## Diagnostics Quick Reference

For a full system check, run:

```bash
bash scripts/diagnose.sh
```

This checks:
- CPU architecture
- Binary presence and version
- Bundle existence and code signing
- Daemon running status
- Socket file presence
- Daemon health (via `list_tools`)
- Tool count

## Still stuck?

Open an issue at [github.com/bess-trailer/cua-driver-intel/issues](https://github.com/bess-trailer/cua-driver-intel/issues) with the output of `bash scripts/diagnose.sh`.
