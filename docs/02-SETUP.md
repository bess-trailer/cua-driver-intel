# Setup — cua-driver on Intel x86_64

A step-by-step guide from nothing to a working `computer_use` toolset on an Intel Mac.

## Prerequisites

- macOS 14 (Sonoma) or later (tested on 15.7.5 Sequoia)
- An x86_64 `cua-driver` binary (v0.1.5+)
- System permissions granted (see Phase 4)

## Phase 1: Obtain the Binary

Upstream cua-driver only ships arm64 binaries. For Intel, you need a custom x86_64 build.

**If you already have one** (from the cua team, PR #1469, or self-compiled):

```bash
cp ~/Downloads/cua-driver /usr/local/bin/cua-driver
chmod +x /usr/local/bin/cua-driver
```

**If you don't:** Reach out via the [cua-driver GitHub Issues](https://github.com/trycua/cua/issues) or PR [#1469](https://github.com/trycua/cua/pull/1469). The cua team has provided x86_64 builds in the past. This repo does not redistribute upstream binaries.

## Phase 2: Verify the Binary

```bash
# Version check
cua-driver --version
# Expected: 0.1.5

# Tool enumeration
cua-driver list-tools
# Expected: 29 tools listed (list_apps, click, type_text, scroll, ...)

# Test a no-arg tool
cua-driver call get_screen_size
# Expected: "Main display: 1920x1080 points @ 1.0x"

# Test an arg tool
cua-driver call list_apps --raw --compact
# Expected: JSON with apps[] array
```

If `cua-driver --version` fails, the binary isn't in PATH or isn't executable.

## Phase 3: Create the App Bundle (Recommended)

The bundle enables screen capture permission for the daemon (required for SOM/vision mode).

```bash
bash bundle/create-bundle.sh /usr/local/bin/cua-driver --install
```

This creates `~/Applications/CuaDriver.app` and symlinks `/usr/local/bin/cua-driver` into it.

**Verify:**

```bash
bash bundle/verify-bundle.sh
# Expected: All 8 checks pass
```

## Phase 4: Grant System Permissions

Open System Settings → Privacy & Security:

1. **Accessibility** → add Terminal.app (or your preferred terminal)
2. **Screen Recording** → add Terminal.app (or CuaDriver.app if visible)

> **Why Terminal.app?** The cua-driver process inherits permissions from the app that launches it. If you run from Terminal, Terminal needs both permissions. If you run from a launchd service or GUI wrapper, that app needs them instead.

## Phase 5: Apply the Hermes Backend Patch

If you use Hermes Agent, replace the daemon socket session with the CLI subprocess backend:

```bash
# Backup first
cp ~/.hermes/hermes-agent/tools/computer_use/cua_backend.py \
   ~/.hermes/hermes-agent/tools/computer_use/cua_backend.py.bak

# Apply the patch
cd ~/.hermes/hermes-agent
patch -p1 < ~/Desktop/cua-driver-intel/patches/hermes-cua-backend.patch
```

**Verify the patch applied:**

```bash
grep "_CliCallSession\|DaemonSocketSession" tools/computer_use/cua_backend.py
# Expected: _CliCallSession references only (no DaemonSocketSession)
```

**Restart Hermes:**
```bash
hermes gateway restart
```

## Phase 6: Test the Full Stack

```bash
# Start a test session with computer_use
hermes -t computer_use chat -q "List my running apps"
```

Or test via Python directly:

```bash
cd ~/.hermes/hermes-agent
source venv/bin/activate
python3 -c "
from tools.computer_use.cua_backend import CuaDriverBackend
b = CuaDriverBackend()
b.start()
apps = b.list_apps()
print(f'Found {len(apps)} running apps')
for a in apps:
    print(f'  {a}')
cap = b.capture(mode='ax')
print(f'Capture: {len(cap.elements)} elements in {cap.app}')
b.stop()
"
```

**Expected output:** Running apps listed, capture returns AX elements.

## Phase 7: Test with Vision

If you have a vision-capable model, test SOM mode:

```python
# This returns both text (AX tree) and base64 screenshot
cap = backend.capture(mode='som')
# → cap.png_b64 contains the screenshot
# → cap.elements contains the AX tree
```

The screenshot is embedded in the MCP response as a base64 JPEG. It should display in the model's context.

## Tidying Up

If something goes wrong:

```bash
# Clean up all daemon state
bash scripts/clean.sh

# Run diagnostics
bash scripts/diagnose.sh
```
