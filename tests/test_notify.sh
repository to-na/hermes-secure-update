#!/usr/bin/env bash
# test_notify.sh — unit tests for lib/notify.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (expected: '$expected', got: '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (expected to contain: '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

# ── Setup: temp log ──────────────────────────────────────────────────────────
TMPDIR_TEST=$(mktemp -d)
export NOTIFY_LOG="$TMPDIR_TEST/notify.log"
export _NOTIFY_ENABLED="false"   # suppress osascript during tests

source "$LIB_DIR/notify.sh"

echo "── notify.sh tests ──"

# Test 1: notify_log writes structured line
notify_log "INFO" "test message"
LINE=$(tail -1 "$NOTIFY_LOG")
assert_contains "log contains level" "INFO" "$LINE"
assert_contains "log contains message" "test message" "$LINE"
assert_contains "log has pipe separator" "|" "$LINE"

# Test 2: multiple levels
notify_log "OK" "success"
notify_log "WARN" "warning"
notify_log "FAIL" "failure"
LINES=$(wc -l < "$NOTIFY_LOG" | tr -d ' ')
assert_eq "4 log lines written" "4" "$LINES"

# Test 3: notify_log creates directory if missing
rm -rf "$TMPDIR_TEST/sub"
export NOTIFY_LOG="$TMPDIR_TEST/sub/deep/notify.log"
_NOTIFY_LOG="$NOTIFY_LOG"
notify_log "INFO" "nested dir"
assert_eq "nested log file exists" "true" "$([[ -f "$NOTIFY_LOG" ]] && echo true || echo false)"

# Test 4: notify() dispatches to log (osascript suppressed)
export NOTIFY_LOG="$TMPDIR_TEST/notify2.log"
_NOTIFY_LOG="$NOTIFY_LOG"
notify "WARN" "Test Title" "warn message"
LINE=$(tail -1 "$NOTIFY_LOG")
assert_contains "notify() logs message" "warn message" "$LINE"

# Test 5: convenience wrappers
notify_ok "ok msg"
notify_fail "fail msg"
LINES=$(wc -l < "$NOTIFY_LOG" | tr -d ' ')
assert_eq "convenience wrappers write 2 more lines" "3" "$LINES"

# ── Cleanup ──────────────────────────────────────────────────────────────────
rm -rf "$TMPDIR_TEST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
