# Local Patch Workflow (OpenClaw)

This repo (`~/magic/vibe-coding/openclaw`) is the **development source of truth**.

Your running OpenClaw is still the **global install** (Node global `node_modules/openclaw`).
So the deployment model is:

> **Develop here → generate a patch → apply patch to global install (sudo) → restart gateway → verify**

This avoids PRs and keeps official update flow intact.

---

## Paths

### Dev repo

- `~/magic/vibe-coding/openclaw`

### Patch file (committed or at least kept in this repo)

- `~/magic/vibe-coding/openclaw/patches/feishu-calendar.patch`

### Global OpenClaw install dir (runtime)

Usually:

```bash
OPENCLAW_GLOBAL="$(npm root -g)/openclaw"
echo "$OPENCLAW_GLOBAL"
```

Example:

- `/home/openclaw/.nvm/.../lib/node_modules/openclaw`

---

## Day-to-day workflow

### 1) Develop in the repo

```bash
cd ~/magic/vibe-coding/openclaw
# edit code under extensions/feishu/...
git status
```

Optional but recommended:

```bash
git commit -am "your change message"
```

### 2) Generate/update the patch

This exports the latest commit as a single patch file.

```bash
cd ~/magic/vibe-coding/openclaw
mkdir -p patches

git format-patch -1 HEAD --stdout > patches/feishu-calendar.patch
wc -l patches/feishu-calendar.patch
```

> Tip: keep your local modifications squashed into **one commit** so patch export/apply stays simple.

### 3) Apply patch to the global install (sudo)

```bash
OPENCLAW_GLOBAL="$(npm root -g)/openclaw"

cd "$OPENCLAW_GLOBAL"

# Apply (adds/updates files in place)
sudo git apply --unsafe-paths ~/magic/vibe-coding/openclaw/patches/feishu-calendar.patch

# Restart to load new code
openclaw gateway restart

# Quick health check
openclaw status | head -n 30
```

### 4) Verify runtime behavior

Use your normal chat/tool testing. For Feishu calendar:

- list calendars
- list events (this week)

If you want to verify the plugin registered, you should see log lines like:

- `feishu_calendar: Registered feishu_calendar tool`

---

## After official updates

Your global install will be overwritten by:

```bash
openclaw update
```

So after an update, just re-apply the patch:

```bash
OPENCLAW_GLOBAL="$(npm root -g)/openclaw"
cd "$OPENCLAW_GLOBAL"

sudo git apply --unsafe-paths ~/magic/vibe-coding/openclaw/patches/feishu-calendar.patch
openclaw gateway restart
```

If `git apply` fails, it usually means upstream changed the same files. Fix by:

1) update your dev repo to match upstream
2) rebase/resolve conflicts
3) regenerate the patch

---

## One-command helper script (recommended)

A script is included in this repo:

- `~/magic/vibe-coding/openclaw/scripts/apply-local-patches.sh`

Run it whenever you need to deploy.

```bash
#!/usr/bin/env bash
set -euo pipefail

PATCH="$HOME/magic/vibe-coding/openclaw/patches/feishu-calendar.patch"
OPENCLAW_GLOBAL="$(npm root -g)/openclaw"

echo "[i] Patch: $PATCH"
echo "[i] Global OpenClaw: $OPENCLAW_GLOBAL"

if [[ ! -f "$PATCH" ]]; then
  echo "[!] Patch not found: $PATCH" >&2
  exit 1
fi

cd "$OPENCLAW_GLOBAL"

echo "[i] Applying patch (sudo)..."
sudo git apply --unsafe-paths "$PATCH"

echo "[i] Restarting gateway..."
openclaw gateway restart

echo "[i] Status:"
openclaw status | head -n 40
```

Then:

```bash
cd ~/magic/vibe-coding/openclaw
chmod +x scripts/apply-local-patches.sh

# sanity-check patches apply cleanly
./scripts/apply-local-patches.sh --check

# apply patches + restart
./scripts/apply-local-patches.sh
```

---

## Notes / gotchas

- This model **patches node_modules in place**. It’s practical, but treat the patch file as your real source of truth.
- Keep secrets (Feishu app_secret, refresh_token) out of the repo. Store them under `~/.openclaw/secrets/` with `chmod 600`.
- If you modify more than one area, consider one patch per feature (multiple patch files) and apply them in order.
