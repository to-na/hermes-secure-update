# diff_summary.sh — Review: human-readable diff summary.

show_diff_summary() {
  local repo="$1"
  local target_ref="$2"
  local verbose="$3"

  echo "── Commit log ──"
  git -C "$repo" log -n 30 --format="  %h %G? %an: %s" HEAD.."$target_ref"

  local total_commits
  total_commits=$(git -C "$repo" rev-list HEAD.."$target_ref" --count)
  if [[ $total_commits -gt 30 ]]; then
    echo "  ... and $((total_commits - 30)) more commits"
  fi

  echo ""
  echo "── Changed files ──"

  # Group by directory for readability
  git -C "$repo" diff --stat HEAD.."$target_ref" | tail -5

  if [[ "$verbose" == "true" ]]; then
    echo ""
    echo "── Full file list ──"
    git -C "$repo" diff --name-status HEAD.."$target_ref" | sed 's/^/  /'
  fi

  # Highlight notable changes
  echo ""
  echo "── Notable changes ──"

  local pyproject_diff
  pyproject_diff=$(git -C "$repo" diff HEAD.."$target_ref" -- pyproject.toml 2>/dev/null || true)
  if [[ -n "$pyproject_diff" ]]; then
    echo "  pyproject.toml modified:"
    echo "$pyproject_diff" | grep '^[+-]' | grep -v '^[+-][+-][+-]' | sed -n '1,10p' | sed 's/^/    /'
  fi

  local install_diff
  install_diff=$(git -C "$repo" diff HEAD.."$target_ref" -- scripts/install.sh 2>/dev/null || true)
  if [[ -n "$install_diff" ]]; then
    warn "  install.sh modified — review carefully"
  fi

  # New files in security-sensitive paths
  local new_security_files
  new_security_files=$(git -C "$repo" diff --diff-filter=A --name-only HEAD.."$target_ref" \
    | grep -iE 'security|auth|credential|token|secret' || true)
  if [[ -n "$new_security_files" ]]; then
    warn "  New security-sensitive files:"
    echo "$new_security_files" | sed 's/^/    /'
  fi
}
