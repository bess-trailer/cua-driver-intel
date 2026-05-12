# cua-driver-intel

**cua-driver for Intel (x86_64) Macs — the workaround that works.**

This repo provides everything needed to run [`cua-driver`](https://github.com/trycua/cua) (macOS desktop automation, used by OpenAI Codex and Hermes Agent) on Intel-based Macs where the upstream stdio MCP server deadlocks.

## Do you need this?

```
Your Mac:
├── Apple Silicon (M1/M2/M3/M4) → No. Upstream cua-driver works directly.
│   MCP stdio works, no bundle needed.
│   → https://github.com/trycua/cua
│
└── Intel (x86_64) → You're in the right place.
    ├── Do you have a cua-driver binary?
    │   No → Request a custom x86_64 build from the cua team
    │         (https://github.com/trycua/cua/issues or PR #1469).
    │         This repo documents the process but does not redistribute
    │         binaries from the upstream repo.
    │   Yes → Continue.
    │
    └── Does `cua-driver mcp < /dev/null` hang?
        Yes → Expected on Intel. This repo fixes it.
        No → Upstream may have fixed the deadlock. Use stdio MCP.
```

## Status

| Component | Status |
|-----------|--------|
| `cua-driver mcp` (stdio MCP server) | ❌ Deadlocks on 4-core Intel (AppKitBootstrap + Swift concurrency) |
| `cua-driver serve` (daemon) | ✅ Works |
| `cua-driver call <tool> '<json-args>'` (CLI wrapper) | ✅ Works — **this is the recommended path** |
| App bundle (CuaDriver.app for TCC) | ✅ Solves screen-capture permission, **not needed for CLI subprocess path** |
| Hermes Agent `computer_use` toolset | ✅ Works via CLI subprocess backend (`_CliCallSession`) |
| Screenshots (vision mode) | ✅ Work via bundle daemon (TCC satisfied by code-signing) |
| Raw socket protocol | 🟡 Works for zero-arg tools; pid serialization bug for argument tools |

## ⚠️ Environment Caveats — Read This First

**This workaround was built and tested on one specific machine:**

| Property | Value |
|----------|-------|
| Model | iMac14,3 (late 2013) |
| CPU | Intel Core i5 (4-core, 4-thread) |
| RAM | 16 GB DDR3 |
| macOS | 15.7.5 (Sequoia) |
| cua-driver | v0.1.5 custom x86_64 build (PR #1469) |
| Hermes Agent | Upstream main (May 2026) |

Your mileage will vary depending on:

- **macOS version** — TCC behavior, SkyLight SPI availability, and code signing requirements change between versions. macOS 14 (Sonoma) and 15 (Sequoia) are most likely to work the same. Older versions (macOS 13 Ventura, 12 Monterey) may have different SkyLight symbol names or missing permissions APIs.
- **CPU generation** — The Swift concurrency cooperative thread pool deadlock is most likely on **4-core/4-thread** CPUs (Haswell and earlier). Newer Intel CPUs with Hyper-Threading (6+ threads) or efficiency cores *may* avoid the starvation condition. The exact threshold is unknown — we tested on exactly one machine.
- **Swift runtime version** — The Swift 6 runtime changed the cooperative thread pool behavior. If cua-driver is recompiled with a different Swift version, the deadlock may manifest differently or not at all.
- **Code signing requirements** — macOS 15.2+ requires hardened runtime for some entitlements. Ad-hoc signing (which `create-bundle.sh` uses) may not satisfy all TCC gates on newer macOS builds.

**If the workaround doesn't work on your machine:** run `bash scripts/diagnose.sh` and open an issue with the output. The more data points we have, the better the coverage.

## Quickstart (4 commands)

```bash
# 1. Place the x86_64 binary
cp ~/Downloads/cua-driver /usr/local/bin/cua-driver

# 2. Verify the binary
cua-driver --version    # should show v0.1.5+
cua-driver list-tools   # should show 29 tools

# 3. Create the app bundle (enables screenshots via daemon)
git clone https://github.com/bess-trailer/cua-driver-intel.git
cd cua-driver-intel
bash bundle/create-bundle.sh /usr/local/bin/cua-driver

# 4. Test it
cua-driver call list_apps
cua-driver call get_screen_size
cua-driver call get_window_state '{"pid":'"$(pgrep -x Terminal)"',"window_id":0}'
```

## The Problem (Front-Loaded)

> The `cua-driver mcp` stdio MCP server — the normal, supported, documented path — **deadlocks on Intel Macs**. The root cause is a Swift concurrency cooperative thread pool starvation on 4-core systems: `AppKitBootstrap.shared.ensureGranted()` spawns a detached Task that tries to cross `@MainActor` boundaries, but the main thread is blocked in `NSApplication.shared.run()`, and there aren't enough cooperative threads on Intel to service the hop.

**The result:** The MCP process starts, produces zero output, never responds to stdin, and must be killed with `kill -9`. The Hermes Agent gateway sees a 15-second timeout and surfaces `"computer_use backend unavailable: "` with no explanation.

Everything in this repo documents the workaround **and** the architecture so you understand why.

## Architecture

```
Your Agent (Hermes / Codex / etc.)
  │
  ├─ MCP stdio (cua-driver mcp)        ❌ Deadlocks on Intel
  │   └─ AppKitBootstrap + StdioTransport
  │
  ├─ Daemon socket (JSON-RPC)          🟡 Protocol has bugs with pid args
  │   └─ cua-driver serve → raw socket
  │
  └─ CLI subprocess                     ✅ Works everywhere
      └─ subprocess: cua-driver call <tool> '<json-args>'
            └─ daemon socket ←→ cua-driver serve
                  └─ SkyLight SPIs + AX APIs
```

The **CLI subprocess path** is the recommended approach. Each tool call runs `cua-driver call <tool> '<json-args>'`, which auto-starts the daemon if needed, sends the request, and returns the result. The ~200ms per-call latency is negligible for human-scale desktop automation.

## Documentation

| Doc | What it covers |
|-----|----------------|
| [Architecture](docs/01-ARCHITECTURE.md) | The three transport layers, why MCP fails, how the daemon works, TCC implications |
| [Setup](docs/02-SETUP.md) | Step-by-step: binary → bundle → Hermes backend → verification |
| [Capabilities](docs/03-CAPABILITIES.md) | Tool matrix — what works per transport mode |
| [Troubleshooting](docs/04-TROUBLESHOOTING.md) | Symptom → cause → fix table |
| [Upgrading](docs/05-UPGRADING.md) | Replacing the binary, testing a new build |
| [Contributing](docs/06-CONTRIBUTING.md) | Reproducing the deadlock, testing a potential fix |

## Scripts

| Script | Purpose |
|--------|---------|
| [`scripts/diagnose.sh`](scripts/diagnose.sh) | Full health check — arch, binary, bundle, daemon, socket, tools |
| [`scripts/clean.sh`](scripts/clean.sh) | Kill daemons, remove stale sockets, reset state |
| [`bundle/create-bundle.sh`](bundle/create-bundle.sh) | Wrap a binary in CuaDriver.app |
| [`bundle/verify-bundle.sh`](bundle/verify-bundle.sh) | Verify bundle integrity, code signing, symlink |
| [`patches/hermes-cua-backend.patch`](patches/hermes-cua-backend.patch) | Hermes Agent `cua_backend.py` — replace daemon socket with CLI subprocess |

## Hermes Agent Integration

If you use [Hermes Agent](https://github.com/NousResearch/hermes-agent), apply the patch:

```bash
cd ~/.hermes/hermes-agent
patch -p1 < ~/Desktop/cua-driver-intel/patches/hermes-cua-backend.patch
```

This replaces the broken daemon socket session with the CLI subprocess backend. See [Setup → Phase 3](docs/02-SETUP.md#phase-3-install-the-hermes-backend) for details.

## License

MIT — see [LICENSE](LICENSE)
