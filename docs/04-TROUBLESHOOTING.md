# Troubleshooting

Symptom → cause.

| Symptom | Cause | Fix |
|---------|-------|-----|
| `"computer_use backend unavailable: "` (15s timeout) | MCP stdio deadlock on Intel | Use CLI subprocess backend. Apply `patches/hermes-cua-backend.patch` |
| `"Missing required integer field pid."` | Daemon socket pid deserialization bug | Use `cua-driver call` CLI wrapper instead of raw socket |
| `cua-driver call` hangs | Stale socket file from crashed daemon | `bash scripts/clean.sh` |
| `capture(mode="som")` returns no image | Screen Recording TCC denied | Bundle binary + grant SR to Terminal.app. Fallback: use `mode="ax"` |
| Two daemon PIDs | Multiple daemons from bundle + standalone | `bash scripts/clean.sh`, restart fresh |
| `"No cached AX state for pid N"` | Click before capture | Call `get_window_state` first. In Hermes: `capture()` before `click()` |
| `"Unknown option '--pid'"` | CLI flags instead of JSON args | `cua-driver call click '{"pid":…}'` not `--pid …` |
| `cua-driver: command not found` after bundle install | Symlink not created | Re-run with `--install` or `ln -s ~/Applications/CuaDriver.app/Contents/MacOS/cua-driver /usr/local/bin/cua-driver` |
| Element index clicks wrong target | Stale AX tree (state changed since capture) | Re-capture before acting. See `cua-stale-element-recovery` skill |

## Diagnostics

```bash
bash scripts/diagnose.sh
# Checks: arch, binary, bundle, daemon, socket, daemon health, tool count
```

Include this output when opening an issue.
