#!/usr/bin/env bash
# test_verify_remote.sh — unit tests for L1 remote URL verification.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/verify_remote.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert_pass() {
  local desc="$1" url="$2" pattern="$3"
  git -C "$TMPDIR" init -q test_repo 2>/dev/null || true
  git -C "$TMPDIR/test_repo" remote add origin "$url" 2>/dev/null || \
    git -C "$TMPDIR/test_repo" remote set-url origin "$url"

  if ( verify_remote "$TMPDIR/test_repo" "$pattern" ) &>/dev/null; then
    echo "  ✓ PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: $desc (expected pass, got block)"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$TMPDIR/test_repo"
}

assert_block() {
  local desc="$1" url="$2" pattern="$3"
  git -C "$TMPDIR" init -q test_repo 2>/dev/null || true
  git -C "$TMPDIR/test_repo" remote add origin "$url" 2>/dev/null || \
    git -C "$TMPDIR/test_repo" remote set-url origin "$url"

  if ( verify_remote "$TMPDIR/test_repo" "$pattern" ) &>/dev/null; then
    echo "  ✗ FAIL: $desc (expected block, got pass)"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ PASS: $desc"
    PASS=$((PASS + 1))
  fi
  rm -rf "$TMPDIR/test_repo"
}

echo "── verify_remote tests ──"

PATTERN="github\.com[:/]NousResearch/hermes-agent(\.git)?$"

assert_pass "SSH URL matches" \
  "git@github.com:NousResearch/hermes-agent.git" "$PATTERN"

assert_pass "HTTPS URL matches" \
  "https://github.com/NousResearch/hermes-agent.git" "$PATTERN"

assert_block "Wrong org blocked" \
  "git@github.com:evil-org/hermes-agent.git" "$PATTERN"

assert_block "Wrong repo blocked" \
  "https://github.com/NousResearch/hermes-agent-fork.git" "$PATTERN"

assert_block "Completely different URL blocked" \
  "https://gitlab.com/someone/hermes-agent.git" "$PATTERN"

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
