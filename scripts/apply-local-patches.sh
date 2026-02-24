#!/usr/bin/env bash
set -euo pipefail

# Apply local patch(es) from this repo into the globally-installed OpenClaw,
# then restart the gateway.
#
# Usage:
#   ./scripts/apply-local-patches.sh
#   ./scripts/apply-local-patches.sh --check
#   ./scripts/apply-local-patches.sh --patch patches/feishu-calendar.patch
#   ./scripts/apply-local-patches.sh --patch patches/a.patch --patch patches/b.patch
#
# Notes:
# - Requires sudo to write to global node_modules.
# - Keeps official `openclaw update` workflow; re-run this after updates.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_GLOBAL="$(npm root -g)/openclaw"

PATCHES=()
MODE="apply"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --patch)
      PATCHES+=("$2")
      shift 2
      ;;
    -h|--help)
      sed -n '1,40p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Default patches: all *.patch in patches/ (sorted)
if [[ ${#PATCHES[@]} -eq 0 ]]; then
  while IFS= read -r p; do
    PATCHES+=("${p#$ROOT_DIR/}")
  done < <(find "$ROOT_DIR/patches" -maxdepth 1 -type f -name '*.patch' | sort)
fi

if [[ ${#PATCHES[@]} -eq 0 ]]; then
  echo "[!] No patch files found under $ROOT_DIR/patches" >&2
  exit 1
fi

echo "[i] Repo: $ROOT_DIR"
echo "[i] Global OpenClaw: $OPENCLAW_GLOBAL"
echo "[i] Mode: $MODE"

cd "$OPENCLAW_GLOBAL"

apply_one() {
  local rel="$1"
  local abs="$ROOT_DIR/$rel"
  if [[ ! -f "$abs" ]]; then
    echo "[!] Patch not found: $abs" >&2
    exit 1
  fi

  echo "[i] Patch: $rel"
  if [[ "$MODE" == "check" ]]; then
    sudo git apply --check --unsafe-paths "$abs"
  else
    sudo git apply --unsafe-paths "$abs"
  fi
}

for p in "${PATCHES[@]}"; do
  apply_one "$p"
done

if [[ "$MODE" == "check" ]]; then
  echo "[✓] Patch check OK"
  exit 0
fi

echo "[i] Restarting gateway..."
openclaw gateway restart

echo "[i] Status (head):"
openclaw status | head -n 40
