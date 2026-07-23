#!/usr/bin/env bash
# test_risk_score.sh — unit tests for L4 risk scoring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/risk_score.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR" 2>/dev/null || true' EXIT

PASS=0
FAIL=0

# Helper: create a repo with N dummy commits that change files
make_repo_with_changes() {
  local dir="$1"
  local num_files="$2"
  local touch_pyproject="${3:-false}"

  git -C "$TMPDIR" init -q "$dir"
  cd "$TMPDIR/$dir"
  git config user.email "test@test.com"
  git config user.name "Test"

  # Initial commit
  echo "init" > README.md
  git add -A && git commit -qm "init"

  # Create a branch with changes
  git checkout -qb feature
  for i in $(seq 1 "$num_files"); do
    echo "content $i" > "file_$i.py"
  done
  if [[ "$touch_pyproject" == "true" ]]; then
    echo '[project]' > pyproject.toml
    echo 'dependencies = ["newdep"]' >> pyproject.toml
  fi
  git add -A && git commit -qm "add files"
  git checkout -q main 2>/dev/null || git checkout -q master

  cd "$TMPDIR"
}

assert_risk() {
  local desc="$1" expected="$2" num_files="$3" touch_pyproject="${4:-false}"

  local repo_name="risk_test_$(echo "$desc" | tr -c 'a-zA-Z0-9_' '_')"
  make_repo_with_changes "$repo_name" "$num_files" "$touch_pyproject"

  # Reset risk state
  _RISK_LEVEL=0
  _RISK_LABEL="low"
  _SIG_UNSIGNED=0
  _SIG_UNKNOWN_AUTHOR=0
  _SIG_TOTAL=1

  compute_risk "$TMPDIR/$repo_name" "feature" &>/dev/null

  if [[ "$_RISK_LABEL" == "$expected" ]]; then
    echo "  ✓ PASS: $desc → $_RISK_LABEL"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: $desc → expected $expected, got $_RISK_LABEL"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$TMPDIR/$repo_name"
}

echo "── risk_score tests ──"

assert_risk "Small change = low" "low" 3
assert_risk "50+ files = medium" "medium" 55
assert_risk "pyproject change = medium" "medium" 3 true
assert_risk "200+ files = high" "high" 205

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
