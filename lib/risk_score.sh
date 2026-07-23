# risk_score.sh — L4: Compute risk score from the diff.

compute_risk() {
  local repo="$1"
  local target_ref="$2"

  local changed_files setup_changes new_deps deleted_files
  changed_files=$(git -C "$repo" diff --name-only HEAD.."$target_ref" | wc -l | tr -d ' ')
  setup_changes=$(git -C "$repo" diff --name-only HEAD.."$target_ref" \
    | grep -cE 'pyproject\.toml|setup\.py|setup\.cfg|install\.sh|uv\.lock' || true)
  new_deps=$(git -C "$repo" diff HEAD.."$target_ref" -- pyproject.toml uv.lock \
    | grep -c '^\+' || true)
  deleted_files=$(git -C "$repo" diff --diff-filter=D --name-only HEAD.."$target_ref" | wc -l | tr -d ' ')

  # Security-sensitive file changes
  local security_changes
  security_changes=$(git -C "$repo" diff --name-only HEAD.."$target_ref" \
    | grep -cE 'security|auth|credential|token|secret|\.env' || true)

  # Compute risk level
  _RISK_LEVEL=0
  _RISK_DETAILS=()

  _RISK_DETAILS+=("Changed files: $changed_files")
  _RISK_DETAILS+=("Build/install changes: $setup_changes")
  _RISK_DETAILS+=("Dependency additions: ~$new_deps")
  _RISK_DETAILS+=("Deleted files: $deleted_files")
  _RISK_DETAILS+=("Security-sensitive changes: $security_changes")

  # Scoring
  [[ $changed_files -gt 50 ]] && _RISK_LEVEL=1
  [[ $changed_files -gt 200 ]] && _RISK_LEVEL=2
  [[ $setup_changes -gt 0 ]] && _RISK_LEVEL=$(( _RISK_LEVEL > 1 ? _RISK_LEVEL : 1 ))
  [[ $new_deps -gt 5 ]] && _RISK_LEVEL=2
  [[ $security_changes -gt 0 ]] && _RISK_LEVEL=$(( _RISK_LEVEL > 0 ? _RISK_LEVEL : 1 ))
  [[ $deleted_files -gt 10 ]] && _RISK_LEVEL=$(( _RISK_LEVEL > 0 ? _RISK_LEVEL : 1 ))

  # Unsigned commits bump risk
  if [[ ${_SIG_UNSIGNED:-0} -gt 0 ]]; then
    local unsigned_ratio=$(( _SIG_UNSIGNED * 100 / _SIG_TOTAL ))
    [[ $unsigned_ratio -gt 50 ]] && _RISK_LEVEL=$(( _RISK_LEVEL > 0 ? _RISK_LEVEL : 1 ))
  fi

  case $_RISK_LEVEL in
    0) _RISK_LABEL="low" ;;
    1) _RISK_LABEL="medium" ;;
    2) _RISK_LABEL="high" ;;
  esac

  # Report
  echo "  Risk assessment:"
  for detail in "${_RISK_DETAILS[@]}"; do
    echo "    $detail"
  done
  echo ""
  echo "  Risk level: $_RISK_LABEL"
}
