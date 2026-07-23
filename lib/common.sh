# common.sh — shared helpers for hermes-secure-update
# Colors and output formatting.

_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[0;33m'
_BLUE='\033[0;34m'
_BOLD='\033[1m'
_NC='\033[0m'

info()  { echo -e "${_BLUE}→${_NC} $*"; }
ok()    { echo -e "${_GREEN}✓${_NC} $*"; }
warn()  { echo -e "${_YELLOW}⚠${_NC} $*"; }
fail()  { echo -e "${_RED}✗${_NC} $*" >&2; }
phase() { echo -e "${_BOLD}── $* ──${_NC}"; }

# Risk level state (set by compute_risk)
_RISK_LEVEL=0   # 0=low, 1=medium, 2=high
_RISK_LABEL="low"
_RISK_DETAILS=()

risk_label() { echo "$_RISK_LABEL"; }
risk_level_numeric() { echo "$_RISK_LEVEL"; }

risk_to_numeric() {
  case "$1" in
    low)    echo 0 ;;
    medium) echo 1 ;;
    high)   echo 2 ;;
    *)      echo 0 ;;
  esac
}
