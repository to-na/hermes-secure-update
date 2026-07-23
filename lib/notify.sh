# notify.sh — notification helpers for hermes-secure-update
# macOS osascript notifications + structured log file.

_NOTIFY_LOG="${NOTIFY_LOG:-${HERMES_HOME:-$HOME/.hermes}/secure-update/notify.log}"
_NOTIFY_ENABLED="true"

# Ensure log directory exists
_notify_init() {
  local dir
  dir="$(dirname "$_NOTIFY_LOG")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Send a macOS notification (best-effort; silently skips if unavailable)
notify_macos() {
  local title="$1"
  local message="$2"
  local sound="${3:-default}"

  [[ "$_NOTIFY_ENABLED" == "true" ]] || return 0

  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\"" 2>/dev/null || true
  fi
}

# Append a structured log line: ISO-8601 timestamp | level | message
notify_log() {
  local level="$1"
  local message="$2"
  _notify_init
  printf '%s | %-7s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$message" >> "$_NOTIFY_LOG"
}

# Combined: macOS notification + log entry
notify() {
  local level="$1"    # INFO, OK, WARN, FAIL
  local title="$2"
  local message="$3"
  local sound="${4:-default}"

  notify_log "$level" "$message"

  case "$level" in
    FAIL)  sound="Basso" ;;
    WARN)  sound="Tink" ;;
    OK)    sound="Glass" ;;
  esac

  notify_macos "$title" "$message" "$sound"
}

# Convenience wrappers
notify_info() { notify "INFO" "hermes-secure-update" "$1"; }
notify_ok()   { notify "OK"   "hermes-secure-update" "$1"; }
notify_warn() { notify "WARN" "hermes-secure-update" "$1"; }
notify_fail() { notify "FAIL" "hermes-secure-update" "$1"; }
