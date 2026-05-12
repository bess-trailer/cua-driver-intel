# cua-driver-intel

cua-driver for Intel (x86_64) Macs. Upstream MCP stdio (`cua-driver mcp`) deadlocks on 4-core systems due to AppKitBootstrap + Swift concurrency cooperative pool starvation. This repo documents the workaround and provides the infrastructure for it.

**Audience:** cua-driver contributors and Hermes Agent developers running on Intel Macs. If you're on Apple Silicon, nothing here applies — use upstream.

## Status

| Layer | Status |
|-------|--------|
| `cua-driver mcp` (stdio) | ❌ Deadlocks on 4-core Intel |
| `cua-driver serve` (daemon) | ✅ Works |
| `cua-driver call` (CLI wrapper) | ✅ Works — **recommended path** |
| App bundle (CuaDriver.app) | ✅ Fixes TCC for MCP (not needed for CLI path) |
| Raw daemon socket (JSON-RPC) | 🟡 Zero-arg tools work; pid serialization bug breaks arg tools |
| Hermes `_CliCallSession` | ✅ All computer_use tools work |
| Screenshots from daemon | ✅ Work via bundle symlink (TCC satisfied) |

## Quickstart

```bash
# 1. Place x86_64 binary (must obtain from cua team — upstream only ships arm64)
cp ~/Downloads/cua-driver /usr/local/bin/cua-driver

# 2. Verify
cua-driver list-tools           # → 29 tools
cua-driver call get_screen_size # → 1920x1080

# 3. Create bundle (enables screen capture from daemon)
bash bundle/create-bundle.sh /usr/local/bin/cua-driver --install

# 4. Smoke test
cua-driver call list_apps
cuda-driver call get_window_state '{"pid":'"$(pgrep -x Finder)"',"window_id":0}'
```

## Environment

Tested on **one machine:** iMac14,3 (2013), 4-core Core i5, 16 GB, macOS 15.7.5, cua-driver v0.1.5 custom x86_64. YMMV by:
- **macOS version** — TCC, SkyLight, and code signing behavior changes across releases
- **CPU generation** — deadlock reproduces on 4-core/4-thread. 6+ threads *may* avoid the starvation. Unknown threshold
- **Swift runtime** — Swift 6 changed cooperative thread pool behavior. Recompiled binaries may behave differently
- **Code signing** — macOS 15.2+ hardened runtime requirements. Ad-hoc signing may not satisfy all TCC gates on newer builds

Run `bash scripts/diagnose.sh` and open an issue with the output if something doesn't work.

## The Problem (Context for Upstream)

`cua-driver mcp` calls `AppKitBootstrap.shared.ensureGranted()`, which spawns a detached Swift concurrency Task. On 4-core Intel:

1. `NSApplication.shared.run()` blocks the main thread (the `@MainActor` executor)
2. The detached Task needs to cross `@MainActor` to probe TCC
3. The cooperative thread pool on 4-core Intel has no available thread to service the `@MainActor` hop
4. Result: **cooperative pool starvation** — MCP process starts, produces zero output, must be killed -9

The daemon path (`serve` + `call`) sidesteps this entirely — `ServeCommand` has its own `AppKitBootstrap` but doesn't call `ensureGranted()`, so it never triggers the deadlock path.

## Docs

| Document | What |
|----------|------|
| [ARCHITECTURE.md](docs/01-ARCHITECTURE.md) | Three transport layers, deadlock mechanism, TCC matrix |
| [INSTALL.md](docs/02-INSTALL.md) | Binary → bundle → Hermes patch → verify |
| [TOOL_MATRIX.md](docs/03-TOOL_MATRIX.md) | Tool availability per transport, args, TCC requirements |
| [TROUBLESHOOTING.md](docs/04-TROUBLESHOOTING.md) | Symptom → cause |
| [TESTED.md](docs/05-TESTED.md) | Empirical results: every tool and parameter combination we ran |
| [CONTRIBUTING.md](docs/06-CONTRIBUTING.md) | Reproducing the deadlock, testing a fix |

## Scripts

- `scripts/diagnose.sh` — arch, binary, bundle, daemon, socket, tools
- `scripts/clean.sh` — kill daemons, remove stale state
- `bundle/create-bundle.sh` — wrap binary in CuaDriver.app
- `bundle/verify-bundle.sh` — 8-point integrity check

## Patch

`patches/hermes-cua-backend.patch` replaces the Hermes `_DaemonSocketSession` with `_CliCallSession`. Apply:

```bash
cd ~/.hermes/hermes-agent
patch -p1 < /path/to/cua-driver-intel/patches/hermes-cua-backend.patch
```
