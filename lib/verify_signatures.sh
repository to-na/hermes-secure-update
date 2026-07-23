# verify_signatures.sh — L2/L3: Commit and tag signature verification.

verify_signatures() {
  local repo="$1"
  local target_ref="$2"
  local maintainers_file="$3"

  local total signed unsigned expired unknown_author
  total=$(git -C "$repo" rev-list HEAD.."$target_ref" --count)
  signed=0
  unsigned=0
  expired=0
  unknown_author=0

  # Load known maintainers
  local -a known_emails=()
  if [[ -f "$maintainers_file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      known_emails+=("$line")
    done < "$maintainers_file"
  fi

  while IFS= read -r sha; do
    # Check signature status
    local gpg_status
    gpg_status=$(git -C "$repo" log --format="%G?" -1 "$sha" 2>/dev/null)
    case "$gpg_status" in
      G|U) signed=$((signed + 1)) ;;
      E)   expired=$((expired + 1)) ;;
      *)   unsigned=$((unsigned + 1)) ;;
    esac

    # Check author against known maintainers
    if [[ ${#known_emails[@]} -gt 0 ]]; then
      local author_email
      author_email=$(git -C "$repo" log --format="%ae" -1 "$sha" 2>/dev/null)
      local found=false
      for email in "${known_emails[@]}"; do
        if [[ "$author_email" == "$email" ]]; then
          found=true
          break
        fi
      done
      if ! $found; then
        unknown_author=$((unknown_author + 1))
      fi
    fi
  done < <(git -C "$repo" rev-list HEAD.."$target_ref")

  # Report
  echo "  Commit signatures:"
  echo "    Signed (valid):   $signed/$total"
  [[ $expired -gt 0 ]]   && echo "    Signed (expired): $expired/$total"
  [[ $unsigned -gt 0 ]]  && warn "  Unsigned commits: $unsigned/$total"
  [[ $unknown_author -gt 0 ]] && warn "  Commits from unknown authors: $unknown_author/$total"

  # Store for risk scoring
  _SIG_UNSIGNED=$unsigned
  _SIG_UNKNOWN_AUTHOR=$unknown_author
  _SIG_TOTAL=$total
}

verify_tag_signature() {
  local repo="$1"
  local tag="$2"

  echo ""
  echo "  Tag signature ($tag):"

  if git -C "$repo" verify-tag "$tag" &>/dev/null; then
    ok "  Tag '$tag' has a valid signature."
  else
    # Check if it's an annotated tag at all
    local tag_type
    tag_type=$(git -C "$repo" cat-file -t "$tag" 2>/dev/null || echo "unknown")
    if [[ "$tag_type" == "tag" ]]; then
      warn "  Tag '$tag' is annotated but signature verification failed."
    else
      warn "  Tag '$tag' is a lightweight tag (no signature possible)."
    fi
    warn "  Proceeding without tag signature verification."
  fi
}
