# =========================================================
#  UTILITIES – Device ID, V‑KEY, Install, Update, State
# =========================================================

# ─── Device ID (persistent) ──────────────────────────────
get_device_id() {
    # If file exists, just read it
    if [ -f "$RAT_DEV_FILE" ]; then
        cat "$RAT_DEV_FILE"
        return
    fi

    # Otherwise, generate a new one
    local DEV_ID=""

    # 1. Try Android serial
    DEV_ID=$(getprop ro.serialno 2>/dev/null | head -c 16)
    if [ -z "$DEV_ID" ] || [ "$DEV_ID" = "unknown" ]; then
        # 2. Try boot ID
        DEV_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '-' | head -c 16)
    fi
    if [ -z "$DEV_ID" ]; then
        # 3. Fallback: hash of directory + time
        DEV_ID=$(echo "$RAT_DIR$(date +%s)" | sha256sum | cut -c1-16)
    fi

    # Save it
    mkdir -p "$(dirname "$RAT_DEV_FILE")"
    echo "$DEV_ID" > "$RAT_DEV_FILE"
    chmod 600 "$RAT_DEV_FILE"

    echo "$DEV_ID"
}

# ─── V‑KEY Verification ──────────────────────────────────
verify_vkey() {
    local VKEY="$1"
    local DEVICE_ID
    DEVICE_ID=$(get_device_id)   # Now it will create if missing
    local PREFIX KEY_DEV_HASH KEY_EXPIRY KEY_CK
    PREFIX=$(echo "$VKEY" | cut -d'-' -f1)
    KEY_DEV_HASH=$(echo "$VKEY" | cut -d'-' -f2)
    KEY_EXPIRY=$(echo "$VKEY" | cut -d'-' -f3)
    KEY_CK=$(echo "$VKEY" | cut -d'-' -f4)

    [ "$PREFIX" != "RST" ] && { echo "INVALID"; return 1; }

    local CALC_DEV_HASH
    CALC_DEV_HASH=$(echo -n "$DEVICE_ID$SALT1" | sha256sum | cut -c1-8)
    [ "$CALC_DEV_HASH" != "$KEY_DEV_HASH" ] && { echo "WRONG_DEVICE"; return 1; }

    local CALC_CK
    CALC_CK=$(echo -n "$KEY_DEV_HASH$KEY_EXPIRY$SALT2" | sha256sum | cut -c1-4)
    [ "$CALC_CK" != "$KEY_CK" ] && { echo "INVALID"; return 1; }

    local TODAY
    TODAY=$(date +%Y%m%d)
    [ "$TODAY" -gt "$KEY_EXPIRY" ] && { echo "EXPIRED"; return 1; }

    echo "$KEY_EXPIRY"
    return 0
}

# ... the rest of your utils.sh (install_rat, update_tool, detect_carrier, etc.) remains the same ...

# ─── Installation ─────────────────────────────────────────
install_rat() {
    clear
    echo "$CYAN[+] Installing R@t Scanner Tool v$RAT_VERSION...$NC"
    echo "$YELLOW[+] Installing dependencies...$NC"
    pkg update -y 2>/dev/null
    pkg install -y curl jq coreutils dig 2>/dev/null
    mkdir -p "$RAT_DIR" "$RAT_CONFIG" "$RAT_RESULTS" "$RAT_LOGS" "$RAT_SAVED"

    echo "$YELLOW[+] This may take some few minutes (1-5)...$NC"
    sleep 1

    echo "$GREEN[+] curl installed ✓$NC"
    echo "$GREEN[+] jq installed ✓$NC"
    echo "$GREEN[+] coreutils installed ✓$NC"
    echo "$GREEN[+] dig installed ✓$NC"

    if [ ! -f "$RAT_DEV_FILE" ]; then
        echo "$YELLOW[+] Generating device ID...$NC"
        DEV_ID=$(getprop ro.serialno 2>/dev/null | head -c 16)
        if [ -z "$DEV_ID" ]; then
            DEV_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '-' | head -c 16)
        fi
        if [ -z "$DEV_ID" ]; then
            DEV_ID=$(date +%s%N | sha256sum | cut -c1-16)
        fi
        echo "$DEV_ID" > "$RAT_DEV_FILE"
        chmod 600 "$RAT_DEV_FILE"
    fi

    # Copy the main script (this will be done by install.sh)
    # But if run directly, we source from current dir
    # We'll handle this in install.sh separately.
    echo ""
    echo "$GREEN[+] Installation successful!$NC"
    echo "$GREEN[+] YOU CAN NOW LAUNCH THE SCANNER FROM ANYWHERE BY TYPING ANY OF THESE:$NC"
    echo "  $AQUA R@t$NC"
    echo "  $AQUA R@tscan$NC"
    echo "  $AQUA RSTzscan$NC"
    echo ""
    read -p "$YELLOW[!!] Press ENTER to continue...$NC"
}

# ─── Update Tool ──────────────────────────────────────────
update_tool() {
    echo "$CYAN[+] Checking for updates...$NC"
    local REMOTE_VERSION
    REMOTE_VERSION=$(curl -s "$GITHUB_RAW/core/config.sh" | grep -m1 'RAT_VERSION="' | cut -d'"' -f2)
    if [ -z "$REMOTE_VERSION" ]; then
        echo "$RED[!] Could not fetch remote version. Check your internet.$NC"
        sleep 2
        return
    fi
    if [ "$REMOTE_VERSION" = "$RAT_VERSION" ]; then
        echo "$GREEN[+] You have the latest version ($RAT_VERSION).$NC"
        sleep 2
        return
    fi
    echo "$YELLOW[!] New version available: $REMOTE_VERSION (yours: $RAT_VERSION)$NC"
    echo "$YELLOW[!] Downloading update...$NC"
    for file in rat.sh core/config.sh core/utils.sh core/ui.sh core/login.sh core/scanner.sh; do
        curl -s -o "$RAT_DIR/$file" "$GITHUB_RAW/$file"
    done
    chmod +x "$RAT_DIR/rat.sh"
    chmod +x "$RAT_DIR/core"/*.sh
    echo "$GREEN[+] Update applied successfully. Please restart the tool.$NC"
    sleep 2
    exit 0
}

# ─── Carrier Detection ────────────────────────────────────
detect_carrier() {
    local active_sim=$(getprop persist.radio.data_sim 2>/dev/null)
    local carrier="Unknown"
    if [ "$active_sim" = "0" ] || [ -z "$active_sim" ]; then
        local val=$(getprop gsm.sim.operator.alpha 2>/dev/null | head -c 30)
        case $(echo "$val" | tr '[:upper:]' '[:lower:]') in
            *vodacom*|*voda*) carrier="Vodacom" ;;
            *mtn*) carrier="MTN" ;;
            *cell*) carrier="CellC" ;;
            *telkom*|*8ta*) carrier="Telkom" ;;
            *rain*) carrier="Rain" ;;
        esac
    else
        local val=$(getprop gsm.sim.operator.alpha 2>/dev/null | head -c 30)
        case $(echo "$val" | tr '[:upper:]' '[:lower:]') in
            *vodacom*|*voda*) carrier="Vodacom" ;;
            *mtn*) carrier="MTN" ;;
            *cell*) carrier="CellC" ;;
            *telkom*|*8ta*) carrier="Telkom" ;;
            *rain*) carrier="Rain" ;;
        esac
    fi
    if [ "$carrier" = "Unknown" ]; then
        local num=$(getprop gsm.sim.operator.numeric 2>/dev/null)
        case "$num" in
            65501) carrier="Vodacom" ;;
            65510) carrier="MTN" ;;
            65507) carrier="CellC" ;;
            65502|65506) carrier="Telkom" ;;
            65536) carrier="Rain" ;;
        esac
    fi
    echo "$carrier"
}

# ─── DNS Resolver ─────────────────────────────────────────
resolve_host() {
    local domain="$1"
    local dns_mode="$2"
    local ip=""
    local resolvers=()
    local modes=$(echo "$dns_mode" | grep -o . | sort -u)
    for m in $modes; do
        case $m in
            3) resolvers+=("1.1.1.1" "1.0.0.1") ;;
            4) resolvers+=("8.8.8.8" "8.8.4.4") ;;
            *) ;;
        esac
    done
    for ns in "${resolvers[@]}"; do
        ip=$(dig +short +timeout=2 +tries=1 @"$ns" "$domain" A 2>/dev/null | head -1)
        [ -n "$ip" ] && { echo "$ip"; return 0; }
    done
    ip=$(dig +short +timeout=2 "$domain" A 2>/dev/null | head -1)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    echo ""
    return 1
}

# ─── State Save / Resume ──────────────────────────────────
save_scan_state() {
    local state_file="$RAT_CONFIG/scan_state_$(date +%Y%m%d_%H%M%S)_$RANDOM.json"
    cat > "$state_file" << EOF
{
    "target_file": "$TARGET_FILE",
    "total_scanned": $total_scanned,
    "total": $TOTAL,
    "timeout": $TIMEOUT,
    "batch": $BATCH,
    "threads": $THREADS,
    "carrier": "$CARRIER",
    "work_dir": "$WORK_DIR",
    "tag": "$TAG",
    "zero_rated": $zero_rated,
    "blocked": $blocked,
    "billed": $billed,
    "bugs": $bugs,
    "deadlock_mode": "$DEADLOCK_MODE",
    "scan_mode": "$SCAN_MODE",
    "dns_mode": "$DNS_MODE",
    "batch_enabled": "$BATCH_ENABLED"
}
EOF
    echo "$state_file"
}

list_paused_scans() {
    local count=0
    local files=()
    for f in "$RAT_CONFIG"/scan_state_*.json; do
        [ -f "$f" ] && { count=$((count+1)); files+=("$f"); }
    done
    [ $count -eq 0 ] && return 1
    echo "$GREEN [+] Found $count paused scan(s):$NC"
    local idx=1
    for f in "${files[@]}"; do
        local target=$(jq -r '.target_file' "$f" 2>/dev/null)
        local scanned=$(jq -r '.total_scanned' "$f" 2>/dev/null)
        local total=$(jq -r '.total' "$f" 2>/dev/null)
        local timestamp=$(basename "$f" | sed 's/scan_state_//' | sed 's/\.json//')
        local carrier=$(jq -r '.carrier' "$f" 2>/dev/null)
        echo "  ${MAGENTA}[$idx]${NC} $(basename "$target") - $scanned / $total hosts ($carrier) saved at $timestamp"
        idx=$((idx+1))
    done
    return 0
}

# ─── Next Prompt ──────────────────────────────────────────
show_next_prompt() {
    echo ""
    echo "$CYAN ╔═•WHAT'S NEXT?•════════════════════════════$NC"
    echo "${MAGENTA} [R]eturn to hub  [E]xit R0scan${NC}"
    echo "$CYAN ╚═══════════════════════════════════════════$NC"
    printf "~OPTION: "
    read next_choice
    case "$next_choice" in
        [rR]*) return 0 ;;
        *) exit 0 ;;
    esac
}
