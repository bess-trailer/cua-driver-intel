# Install

Steps to get from a binary to a working computer_use toolset on an Intel Mac.

## 1. Get the binary

Upstream ships arm64 only. The x86_64 build is a custom build from cua team (PR #1469). This repo doesn't redistribute binaries — ask via the cua-driver repo or PR.

```bash
cp ~/Downloads/cua-driver /usr/local/bin/cua-driver
chmod +x /usr/local/bin/cua-driver
```

## 2. Verify

```bash
cua-driver --version       # → 0.1.5+
cua-driver list-tools      # → 29 tools
cua-driver call get_screen_size  # → "Main display: 1920x1080"
```

## 3. Create the bundle (optional, enables screen capture)

```bash
bash bundle/create-bundle.sh /usr/local/bin/cua-driver --install
```

Verify: `bash bundle/verify-bundle.sh` — 8 checks, all pass.

Without the bundle: AX-mode tools still work. SOM/vision mode won't get screenshots (TCC).

## 4. Grant permissions

System Settings → Privacy & Security:
- **Accessibility** → add Terminal.app (required for all interaction tools)
- **Screen Recording** → add Terminal.app (required for screenshots; only if using bundle daemon)

## 5. Apply Hermes Agent patch

```bash
cp /path/to/hermes-agent/tools/computer_use/cua_backend.py{,.bak}
cd /path/to/hermes-agent
patch -p1 < /path/to/cua-driver-intel/patches/hermes-cua-backend.patch
```

Verify: `grep -c "_CliCallSession" tools/computer_use/cua_backend.py` — should return >0.

## 6. Test

```bash
# From Python
cd /path/to/hermes-agent && venv/bin/python3 -c "
from tools.computer_use.cua_backend import CuaDriverBackend
b = CuaDriverBackend(); b.start()
print('apps:', len(b.list_apps()))
cap = b.capture(mode='ax')
print(f'capture: {len(cap.elements)} elements in {cap.app}')
b.stop()
"

# From Hermes
hermes -t computer_use chat -q "List my apps"
```

## Cleanup

`bash scripts/clean.sh` — kills daemons, removes stale sockets, resets state.
