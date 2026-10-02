# =========================================================
#  UTILITIES
# =========================================================

get_device_id() {
    if [ -f "$RAT_DEV_FILE" ]; then cat "$RAT_DEV_FILE"; return; fi
    local DEV_ID=""
    DEV_ID=$(getprop ro.serialno 2>/dev/null | head -c 16)
    if [ -z "$DEV_ID" ] || [ "$DEV_ID" = "unknown" ]; then
        DEV_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '-' | head -c 16)
    fi
    [ -z "$DEV_ID" ] && DEV_ID=$(echo "$RAT_DIR$(date +%s)" | sha256sum | cut -c1-16)
    mkdir -p "$(dirname "$RAT_DEV_FILE")"
    echo "$DEV_ID" > "$RAT_DEV_FILE"
    chmod 600 "$RAT_DEV_FILE"
    echo "$DEV_ID"
}

verify_vkey() {
    local VKEY="$1"
    local DEVICE_ID=$(get_device_id)
    local PREFIX KEY_DEV_HASH KEY_EXPIRY KEY_CK
    PREFIX=$(echo "$VKEY" | cut -d'-' -f1)
    KEY_DEV_HASH=$(echo "$VKEY" | cut -d'-' -f2)
    KEY_EXPIRY=$(echo "$VKEY" | cut -d'-' -f3)
    KEY_CK=$(echo "$VKEY" | cut -d'-' -f4)
    [ "$PREFIX" != "RST" ] && { echo "INVALID"; return 1; }
    local CALC_DEV_HASH=$(echo -n "$DEVICE_ID$SALT1" | sha256sum | cut -c1-8)
    [ "$CALC_DEV_HASH" != "$KEY_DEV_HASH" ] && { echo "WRONG_DEVICE"; return 1; }
    local CALC_CK=$(echo -n "$KEY_DEV_HASH$KEY_EXPIRY$SALT2" | sha256sum | cut -c1-4)
    [ "$CALC_CK" != "$KEY_CK" ] && { echo "INVALID"; return 1; }
    local TODAY=$(date +%Y%m%d)
    [ "$TODAY" -gt "$KEY_EXPIRY" ] && { echo "EXPIRED"; return 1; }
    echo "$KEY_EXPIRY"
    return 0
}

install_rat() {
    clear
    echo "${BLUE}══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}   [R•S•T]🇦🇶 🩵INSTALLATION HUB| THANKS😇 FOR INSTALLING ME R@t 0-SCANNER 💙${NC}"
    echo "${BLUE}══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "${YELLOW}[!] STORAGE PERMISION REQUIRED [!]${NC}"
    echo "${AQUA}   1. A settings screen will open in a moment.${NC}"
    echo "${AQUA}   2. Scroll down or use search bar/icon to find 'termux'.${NC}"
    echo "${AQUA}   3. Tap the switch to turn it 'on' (Allowing access to manage all files).${NC}"
    echo "${AQUA}   4. Then press your phone's back button to return here in termux app.${NC}"
    echo ""
    echo "${YELLOW}[*] Opening settings in 6 seconds... please carefully read the steps above!${NC}"
    sleep 6
    termux-setup-storage 2>/dev/null
    sleep 2
    echo "${GREEN}[+] It appears this action is already set now tool will proceed in 2s...${NC}"
    sleep 2
    echo ""
    while true; do
        echo -n "${YELLOW}[🔒] Enter The tool PIN to proceed: ${NC}"
        read pin
        [ "$pin" = "$SCANNER_PIN" ] && break
        echo "${RED}[!] INCORRECT PIN, CORRECT PIN IS REQUIRED RE ENTER THE CORRECT PIN NOW${NC}"
    done
    echo ""
    echo "${AQUA}[*] Setting up the tool (This may take 1 - 2 minutes)...${NC}"
    pkg update -y >/dev/null 2>&1
    pkg install -y curl jq coreutils dig termux-api >/dev/null 2>&1
    mkdir -p "$RAT_DIR" "$RAT_CONFIG" "$RAT_RESULTS" "$RAT_LOGS" "$RAT_SAVED"
    echo "${GREEN}[+] Tool framework set successfully✓${NC}"
    echo "${GREEN}[+] Member login sections for auto-login set✓${NC}"
    echo ""
    echo "${AQUA}[📥] Installing dependencies...${NC}"
    echo "${GREEN}[+] Tool folders set✓${NC}"
    echo "${GREEN}[+] curl installed✓${NC}"
    echo "${GREEN}[+] jq installed✓${NC}"
    echo "${GREEN}[+] coreutils installed✓${NC}"
    echo "${GREEN}[+] dig installed✓${NC}"
    echo "${GREEN}[+] termux-api installed✓${NC}"
    [ ! -f "$RAT_DEV_FILE" ] && get_device_id >/dev/null
    cp "$0" "$RAT_DIR/rat.sh" 2>/dev/null
    chmod +x "$RAT_DIR/rat.sh" 2>/dev/null
    ln -sf "$RAT_DIR/rat.sh" "$PREFIX/bin/R@t" 2>/dev/null
    ln -sf "$RAT_DIR/rat.sh" "$PREFIX/bin/R@tscan" 2>/dev/null
    ln -sf "$RAT_DIR/rat.sh" "$PREFIX/bin/RSTzscan" 2>/dev/null
    if ! grep -q "R@t=" ~/.bashrc 2>/dev/null; then
        echo 'alias R@t="bash ~/R@t/rat.sh --run"' >> ~/.bashrc
        echo 'alias R@tscan="bash ~/R@t/rat.sh --run"' >> ~/.bashrc
        echo 'alias RSTzscan="bash ~/R@t/rat.sh --run"' >> ~/.bashrc
    fi
    echo ""
    echo "${GREEN}[++] Tool is installed and set successfully✓${NC}"
    echo ""
    echo "${YELLOW}[*] You can now launch the scanner from anywhere by typing any of these:${NC}"
    echo ""
    echo "${YELLOW}     R@t${NC}"
    echo "${YELLOW}     R@tscan${NC}"
    echo "${YELLOW}     RSTzscan${NC}"
    echo ""
    echo -n "${YELLOW}~R@enter: ${NC}"
    read cmd
    case "$cmd" in
        R@t|R@tscan|RSTzscan|RSTscan|R@scan) exec bash "$RAT_DIR/rat.sh" --run ;;
        *) echo "${YELLOW}[*] Run any of the commands to start the tool.${NC}" ;;
    esac
}

update_tool() {
    echo "${AQUA}[+] Checking for updates...${NC}"
    local REMOTE_VERSION
    REMOTE_VERSION=$(curl -s --max-time 10 "$GITHUB_RAW/core/config.sh" | grep -m1 'RAT_VERSION="' | cut -d'"' -f2)
    if [ -z "$REMOTE_VERSION" ]; then echo "${RED}[!] Could not fetch remote version.${NC}"; sleep 2; return; fi
    if [ "$REMOTE_VERSION" = "$RAT_VERSION" ]; then
        echo "${GREEN}[+] You have the latest version ($RAT_VERSION).${NC}"; sleep 2; return
    fi
    echo "${YELLOW}[!] New version: $REMOTE_VERSION (yours: $RAT_VERSION)${NC}"
    echo "${YELLOW}[!] Downloading update...${NC}"
    for file in rat.sh install.sh core/config.sh core/utils.sh core/ui.sh core/login.sh core/scanner.sh; do
        curl -s -o "$RAT_DIR/$file" "$GITHUB_RAW/$file"
    done
    chmod +x "$RAT_DIR/rat.sh" 2>/dev/null
    chmod +x "$RAT_DIR/core"/*.sh 2>/dev/null
    echo "${GREEN}[+] Update applied. Please restart the tool.${NC}"
    sleep 3
    exit 0
}

detect_carrier() {
    local val=$(getprop gsm.sim.operator.alpha 2>/dev/null | head -c 30)
    local carrier="Unknown"
    case $(echo "$val" | tr '[:upper:]' '[:lower:]') in
        *vodacom*|*voda*) carrier="VODACOM" ;;
        *mtn*) carrier="MTN" ;;
        *cell*) carrier="CELLC" ;;
        *telkom*|*8ta*) carrier="TELKOM" ;;
        *rain*) carrier="RAIN" ;;
    esac
    if [ "$carrier" = "Unknown" ]; then
        local num=$(getprop gsm.sim.operator.numeric 2>/dev/null)
        case "$num" in
            65501) carrier="VODACOM" ;;
            65510) carrier="MTN" ;;
            65507) carrier="CELLC" ;;
            65502|65506) carrier="TELKOM" ;;
            65536) carrier="RAIN" ;;
        esac
    fi
    echo "$carrier"
}

normalize_carrier() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')" in
        *cell*) echo "CELLC" ;;
        *mtn*) echo "MTN" ;;
        *voda*) echo "VODACOM" ;;
        *telkom*|*8ta*) echo "TELKOM" ;;
        *rain*) echo "RAIN" ;;
    esac
}

animate_analyzing() {
    local total_secs="$1"
    local frames=("R@ - - - -" "- R@ - - -" "- - R@ - -" "- - - R@ -" "- - - - R@")
    local colours=("$YELLOW" "$CYAN" "$CYAN" "$CYAN" "$YELLOW")
    local flen=${#frames[@]}
    local i=0
    local elapsed=0
    local steps=$(( total_secs * 10 ))
    tput civis 2>/dev/null
    while [ $elapsed -lt $steps ]; do
        local idx=$(( i % flen ))
        printf "\r\033[K${AQUA}[:°] ANALYZING NETWORK...${NC} [ ${colours[$idx]}${frames[$idx]}${NC} ] "
        i=$((i+1))
        elapsed=$((elapsed+1))
        sleep 0.1
    done
    printf "\r\033[K${AQUA}[:°] ANALYZING NETWORK... [ DONE ]${NC}\n"
    tput cnorm 2>/dev/null
}

custom_network_setup() {
    local scan_mode="$1"
    local TMP=$(mktemp -d)
    local SITES=(
        "CELLC|nofunds.cellc.mobi"
        "MTN|nofunds.mtn.co.za"
        "VODACOM|connectu.vodacom.co.za"
        "RAIN|www.rain.co.za"
        "TELKOM|www.telkom.co.za"
    )
    local NEUTRAL=("www.google.com/generate_204" "www.cloudflare.com")

    _RST_CARRIER=""

    local frames=("R@ - - - -" "- R@ - - -" "- - R@ - -" "- - - R@ -" "- - - - R@")
    local colours=("$YELLOW" "$CYAN" "$CYAN" "$CYAN" "$YELLOW")
    local flen=${#frames[@]}
    local i=0

    tput civis 2>/dev/null

    local s
    for s in "${SITES[@]}"; do
        ( code=$(curl -s -o /dev/null -m 6 -w "%{http_code}" "https://${s#*|}" 2>/dev/null); echo "${code:-000}" > "$TMP/site_${s%%|*}.done" ) &
    done
    local n_idx=0
    for n in "${NEUTRAL[@]}"; do
        ( code=$(curl -s -o /dev/null -m 6 -w "%{http_code}" "https://$n" 2>/dev/null); echo "${code:-000}" > "$TMP/net_$n_idx.done" ) &
        n_idx=$((n_idx+1))
    done

    while [ "$(ls "$TMP"/*.done 2>/dev/null | wc -l)" -lt 7 ]; do
        local idx=$(( i % flen ))
        printf "\r\033[K${AQUA}[:°] ANALYZING NETWORK...${NC} [ ${colours[$idx]}${frames[$idx]}${NC} ] "
        i=$((i+1))
        sleep 0.15
    done
    printf "\r\033[K${AQUA}[:°] ANALYZING NETWORK... [ DONE ]${NC}\n"
    tput cnorm 2>/dev/null
    wait 2>/dev/null

    local net_works=0
    local f
    for f in "$TMP"/net_*.done; do
        [ -f "$f" ] && [ "$(cat "$f")" != "000" ] && net_works=1
    done

    if [ "$scan_mode" = "1" ] || [ "$scan_mode" = "2" ]; then
        if [ $net_works -eq 1 ]; then
            echo "${YELLOW}[!] WARNING INTERNET DETECTED MANUALLY ENTER CARRIER NETWORK${NC}"
            ask_manual_carrier
        else
            echo "${GREEN}[+] Zero balance confirmed. Safe to proceed.${NC}"
            local hits=()
            for s in "${SITES[@]}"; do
                [ -f "$TMP/site_${s%%|*}.done" ] && [ "$(cat "$TMP/site_${s%%|*}.done")" != "000" ] && hits+=("${s%%|*}")
            done
            case ${#hits[@]} in
                1) _RST_CARRIER="${hits[0]}" ;;
                0) echo "${YELLOW}[!] NO CARRIER SITE RESPONDED. MANUALLY ENTER CARRIER NETWORK${NC}"; ask_manual_carrier ;;
                *) echo "${YELLOW}[!] MULTIPLE RESPONDED (${hits[*]}). MANUALLY ENTER CARRIER NETWORK${NC}"; ask_manual_carrier ;;
            esac
        fi
    else
        if [ $net_works -eq 0 ]; then
            echo "${YELLOW}[!] WARNING NO ACTIVE DATA DETECTED. MANUALLY ENTER CARRIER NETWORK${NC}"
            ask_manual_carrier
        else
            echo "${GREEN}[+] Active data confirmed. Safe to proceed.${NC}"
            _RST_CARRIER=$(detect_carrier)
            [ "$_RST_CARRIER" = "Unknown" ] && ask_manual_carrier
        fi
    fi

    rm -rf "$TMP"
    echo "${GREEN}[+] Network Carrier: $_RST_CARRIER${NC}"
}

ask_manual_carrier() {
    local name="" input
    while [ -z "$name" ]; do
        prompt_rat
        read -r input
        name=$(normalize_carrier "$input")
        [ -z "$name" ] && echo "${RED}[!] Unknown network. Use: MTN, VODACOM, CELLC, TELKOM or RAIN${NC}"
    done
    _RST_CARRIER="$name"
}

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
        esac
    done
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "$domain"; return 0; fi
    for ns in "${resolvers[@]}"; do
        ip=$(dig +short +timeout=2 +tries=1 @"$ns" "$domain" A 2>/dev/null | head -1)
        [ -n "$ip" ] && { echo "$ip"; return 0; }
    done
    ip=$(dig +short +timeout=2 "$domain" A 2>/dev/null | head -1)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    echo ""
    return 1
}

# ─── Save paused state (sets global _SAVED_STATE_FILE) ────
save_scan_state() {
    local rnd=$(printf "%04d" $((RANDOM % 10000)))
    local sc=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    _SAVED_STATE_FILE="$WORK_DIR/PAUSED_${sc}_$(date +%d_%Y%m%d_%H%M)_${rnd}.txt"
    local elapsed_sec=0
    [ -n "$start_time" ] && [ "$start_time" -gt 0 ] 2>/dev/null && elapsed_sec=$(( $(date +%s) - start_time ))
    cat > "$_SAVED_STATE_FILE" << EOF
{
    "target_file": "$TARGET_FILE",
    "total_scanned": ${total_scanned:-0},
    "total": ${TOTAL:-0},
    "timeout": ${TIMEOUT:-10},
    "batch": ${BATCH:-100},
    "threads": ${THREADS:-100},
    "carrier": "$CARRIER",
    "work_dir": "$WORK_DIR",
    "tag": "$TAG",
    "zero_rated": ${zero_rated:-0},
    "blocked": ${blocked:-0},
    "billed": ${billed:-0},
    "bugs": ${bugs:-0},
    "pshd": ${pshd:-0},
    "elapsed_sec": $elapsed_sec,
    "deadlock_mode": "$DEADLOCK_MODE",
    "scan_mode": "$SCAN_MODE",
    "dns_mode": "$DNS_MODE",
    "batch_enabled": "$BATCH_ENABLED"
}
EOF
    local remaining_file="${_SAVED_STATE_FILE%.txt}_hosts.txt"
    tail -n +$(( ${total_scanned:-0} + 1 )) "$TARGET_FILE" > "$remaining_file" 2>/dev/null
}

list_paused_scans() {
    local dir="$1"
    local count=0
    local files=()
    for f in "$dir"/PAUSED_*.txt; do
        [[ "$f" == *_hosts.txt ]] && continue
        [ -f "$f" ] && { count=$((count+1)); files+=("$f"); }
    done
    [ $count -eq 0 ] && return 1
    echo "${YELLOW}[?] UNFINISHED 0-RATED SCANS DETECTED IN THIS FOLDER!${NC}"
    local shown=0
    for f in "${files[@]}"; do
        shown=$((shown+1))
        [ $shown -gt 4 ] && break
        echo "${AQUA} [$shown] Resume : $(basename "$f")${NC}"
    done
    echo "${AQUA} [M] Manual : Type the name of a different paused file${NC}"
    echo "${AQUA} [Enter]     : Start a brand new file${NC}"
    prompt_rat
    read resume_choice
    echo "$resume_choice"
    return 0
}
