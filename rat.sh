#!/data/data/com.termux/files/usr/bin/bash
# =========================================================
#  R@t Scanner – Main Launcher
#  REBELSQUAD TERRORIST TECH SYSTEMS
# =========================================================

RAT_DIR="$HOME/R@t"

# Source all modules
source "$RAT_DIR/core/config.sh"
source "$RAT_DIR/core/utils.sh"
source "$RAT_DIR/core/ui.sh"
source "$RAT_DIR/core/login.sh"
source "$RAT_DIR/core/scanner.sh"

case "$1" in
    --install) install_rat ;;
    --run) main_menu ;;
    *) main_menu ;;
esac