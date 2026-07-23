#!/usr/bin/env bash
# cron-update.sh — unattended hermes-secure-update wrapper for cron/launchd.
#
# Features:
#   - Lock file prevents concurrent runs
#   - Runs hermes-secure-update --dry-run --notify (check only, never applies)
#   - Logs to ~/.hermes/secure-update/cron.log
#   - Exit codes: 0 = success/up-to-date, 1 = blocked/error, 2 = lock held
#
# Usage:
#   scripts/cron-update.sh [--no-ai-review]
#
# Install (launchd):
#   cp scripts/ai.hermes.secure-update.plist ~/Library/LaunchAgents/
#   launchctl load ~/Library/LaunchAgents/ai.hermes.secure-update.plist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../bin/hermes-secure-update"
LOCK_DIR="${HERMES_HOME:-$HOME/.hermes}/secure-update"
LOCK_FILE="$LOCK_DIR/cron.lock"
CRON_LOG="$LOCK_DIR/cron.log"

mkdir -p "$LOCK_DIR"

# ── Lock ──────────────────────────────────────────────────────────────────────
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | LOCKED  | Another run in progress (PID $LOCK_PID)" >> "$CRON_LOG"
    exit 2
  fi
  # Stale lock — remove and continue
  rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ── Run ───────────────────────────────────────────────────────────────────────
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | START   | hermes-secure-update --dry-run --notify $*" >> "$CRON_LOG"

if bash "$TOOL" --dry-run --notify "$@" >> "$CRON_LOG" 2>&1; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | DONE    | Update completed or already up to date" >> "$CRON_LOG"
  exit 0
else
  RC=$?
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | FAILED  | Exit code $RC — manual review needed" >> "$CRON_LOG"
  exit 1
fi
