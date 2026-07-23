# ai_review.sh — AI-powered security review of the update diff.
# Uses hermes chat -q (one-shot) to analyze the diff for suspicious patterns.

ai_review() {
  local repo="$1"
  local target_ref="$2"
  local model="${3:-}"
  local max_diff_chars="${4:-12000}"

  # Generate the diff
  local diff_content
  diff_content=$(git -C "$repo" diff HEAD.."$target_ref" 2>/dev/null)

  if [[ -z "$diff_content" ]]; then
    info "No diff to review."
    return 0
  fi

  # Truncate if too large
  local diff_len=${#diff_content}
  local truncated=false
  if [[ $diff_len -gt $max_diff_chars ]]; then
    diff_content="${diff_content:0:$max_diff_chars}"
    truncated=true
  fi

  # Build the review prompt
  local prompt
  prompt=$(cat <<'PROMPT_EOF'
You are a security reviewer analyzing a git diff for the Hermes Agent project (an open-source AI agent framework). Review the following diff for security concerns.

Focus on:
1. **Malicious injection**: reverse shells, data exfiltration, backdoors
2. **Credential harvesting**: reading .env, auth.json, API keys, tokens
3. **Unexpected network calls**: new outbound HTTP/DNS/websocket connections
4. **Obfuscated code**: base64-encoded payloads, eval/exec of dynamic strings
5. **Permission escalation**: sudo, chmod, setuid, new system-level access
6. **Supply chain risks**: new dependencies from unusual sources, modified install scripts
7. **Silent behavior changes**: telemetry, tracking, hidden feature flags

For each finding, rate severity: CRITICAL / HIGH / MEDIUM / LOW / INFO.
If nothing suspicious, say "No security concerns found." and give a 1-line summary of what the diff does.

Format:
- Start with a verdict line: ✅ CLEAN / ⚠️ REVIEW NEEDED / 🚨 SUSPICIOUS
- Then list findings (if any)
- End with a 1-line summary of the change's purpose

Be concise. Do not explain what the code does unless it's suspicious.
PROMPT_EOF
)

  if $truncated; then
    prompt="$prompt

NOTE: The diff was truncated to ${max_diff_chars} chars (total: ${diff_len}). Some changes may not be visible in this review."
  fi

  prompt="$prompt

--- DIFF START ---
$diff_content
--- DIFF END ---"

  # Call hermes one-shot
  info "Running AI security review..."
  [[ -n "$model" ]] && info "  Model: $model"

  local review_output
  local hermes_args=(-q "$prompt" -Q)
  if [[ -n "$model" ]]; then
    hermes_args+=(-m "$model")
  fi

  review_output=$(hermes chat "${hermes_args[@]}" 2>/dev/null) || {
    warn "AI review failed (hermes chat returned non-zero). Skipping."
    _AI_REVIEW_RESULT="skipped"
    return 0
  }

  if [[ -z "$review_output" ]]; then
    warn "AI review returned empty output. Skipping."
    _AI_REVIEW_RESULT="skipped"
    return 0
  fi

  _AI_REVIEW_RESULT="$review_output"

  # Display
  echo ""
  echo "── AI Security Review ──"
  echo "$review_output"
  echo ""
}

# Extract verdict for risk integration
ai_review_verdict() {
  local result="${_AI_REVIEW_RESULT:-}"
  if [[ -z "$result" || "$result" == "skipped" ]]; then
    echo "unknown"
    return
  fi
  if echo "$result" | grep -q "🚨\|SUSPICIOUS\|CRITICAL"; then
    echo "suspicious"
  elif echo "$result" | grep -q "⚠️\|REVIEW NEEDED\|HIGH"; then
    echo "review_needed"
  else
    echo "clean"
  fi
}
