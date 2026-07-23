# verify_remote.sh — L1: Verify the git remote URL is the expected upstream.

verify_remote() {
  local repo="$1"
  local expected_pattern="$2"

  local origin_url
  origin_url=$(git -C "$repo" remote get-url origin 2>/dev/null) || {
    fail "No 'origin' remote configured."
    exit 1
  }

  if echo "$origin_url" | grep -qE "$expected_pattern"; then
    ok "Remote URL verified: $origin_url"
  else
    fail "BLOCKED: origin remote does not match expected pattern."
    echo "  Expected pattern: $expected_pattern"
    echo "  Actual URL:       $origin_url"
    echo ""
    echo "  This could indicate a tampered remote. Fix with:"
    echo "    git -C $repo remote set-url origin git@github.com:NousResearch/hermes-agent.git"
    exit 1
  fi
}
