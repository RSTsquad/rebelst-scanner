# =========================================================
#  CONFIGURATION
# =========================================================

RAT_VERSION="3.1"
RAT_DIR="$HOME/R@t"
RAT_CONFIG="$RAT_DIR/.config"
RAT_KEY_FILE="$RAT_CONFIG/.vkey"
RAT_USER_FILE="$RAT_CONFIG/.username"
RAT_DEV_FILE="$RAT_CONFIG/.devid"
RAT_SAVED="$RAT_DIR/saved"
RAT_LOGS="$RAT_DIR/logs"
RAT_RESULTS="$RAT_DIR/results"
SALT1="RST_SALT_V1"
SALT2="RST_CK_V1"
SCANNER_PIN="083312"
RAT_WEB="https://rst-freenet-hub.base44.app"
GITHUB_RAW="https://raw.githubusercontent.com/RSTsquad/rebelst-scanner/main"

# ─── Colours ──────────────────────────────────────────────
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
AQUA=$(printf '\033[1;36m')
MAGENTA=$(printf '\033[1;35m')
PURPLE=$(printf '\033[0;35m')
BLUE=$(printf '\033[0;34m')
GOLD=$(printf '\033[0;33m')
BOLD=$(printf '\033[1m')
WHITE=$(printf '\033[1;37m')
NC=$(printf '\033[0m')

# ─── Custom prompt ────────────────────────────────────────
prompt_rat() { printf "${GREEN}~${BLUE}R@${CYAN}en${RED}ter${NC}: "; }
