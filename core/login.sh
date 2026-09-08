# =========================================================
#  LOGIN & COMMAND HUB – FINAL FIXED
# =========================================================

# ─── Error Handling ──────────────────────────────────────
set -E
trap 'echo -e "\n${RED}[!] Error on line $LINENO${NC}"; read -p "Press ENTER to continue..."' ERR

# ─── Scanner Login ────────────────────────────────────────
scanner_login() {
    clear
    echo "$CYAN ╔════════════════════════════════════════════════════╗$NC"
    echo "$CYAN ║            ZERO-RATED SCANNER LOGIN               ║$NC"
    echo "$CYAN ╚════════════════════════════════════════════════════╝$NC"
    echo ""

    if [ -f "$RAT_KEY_FILE" ] && [ -f "$RAT_USER_FILE" ]; then
        local SAVED_KEY
        SAVED_KEY=$(cat "$RAT_KEY_FILE")
        local RESULT
        RESULT=$(verify_vkey "$SAVED_KEY")
        if [ "$RESULT" != "INVALID" ] && [ "$RESULT" != "WRONG_DEVICE" ] && [ "$RESULT" != "EXPIRED" ]; then
            local USERNAME
            USERNAME=$(cat "$RAT_USER_FILE")
            echo "$GREEN[!] ACCESS GRANTED AUTOMATICALLY LOGGING IN!!$NC"
            sleep 1
            command_hub "$USERNAME"
            return
        else
            rm -f "$RAT_KEY_FILE" "$RAT_USER_FILE"
        fi
    fi

    printf "~ENTER USERNAME (e.g Sibusiso N): "
    read USERNAME
    [ -z "$USERNAME" ] && { echo "$RED[!] Username required$NC"; sleep 2; return; }

    printf "~ENTER PIN: "
    read pin
    [ "$pin" != "$SCANNER_PIN" ] && { echo "$RED[!] INCORRECT PIN$NC"; sleep 2; return; }

    local DEVICE_ID
    DEVICE_ID=$(get_device_id)
    echo ""
    echo "$GREEN[!] DEVICE ID: $DEVICE_ID$NC"
    echo "$GREEN[!] GET YOUR PM KEY HERE: $RAT_WEB$NC"
    echo ""

    printf "~ENTER PM-KEY: "
    read vkey
    local RESULT
    RESULT=$(verify_vkey "$vkey")
    case "$RESULT" in
        "INVALID")
            echo "$RED[!] INCORRECT V-KEY! Random keys are not accepted.$NC"
            sleep 3
            return
            ;;
        "WRONG_DEVICE")
            echo "$RED[!] INVALID: This key was generated for a different device!$NC"
            echo "$YELLOW Get your own V-Key from: $RAT_WEB$NC"
            sleep 3
            return
            ;;
        "EXPIRED")
            echo "$RED[!] INVALID: Your V-Key has expired!$NC"
            echo "$YELLOW Generate a new V-Key from: $RAT_WEB$NC"
            sleep 3
            return
            ;;
        *)
            echo "$vkey" > "$RAT_KEY_FILE"
            echo "$USERNAME" > "$RAT_USER_FILE"
            chmod 600 "$RAT_KEY_FILE" "$RAT_USER_FILE"
            echo ""
            echo "$GREEN[+] ACCESS GRANTED. KEY SAVED FOR AUTO-LOGIN! WELCOME TO PM USER.$NC"
            sleep 2
            command_hub "$USERNAME"
            ;;
    esac
}

# ─── Command Hub ───────────────────────────────────────────
command_hub() {
    local USERNAME="$1"
    local DEVICE_ID
    DEVICE_ID=$(get_device_id)
    local VKEY
    VKEY=$(cat "$RAT_KEY_FILE")
    local EXPIRY
    EXPIRY=$(echo "$VKEY" | cut -d'-' -f3)
    local YR MO DY
    YR=$(echo "$EXPIRY" | cut -c1-4)
    MO=$(echo "$EXPIRY" | cut -c5-6)
    DY=$(echo "$EXPIRY" | cut -c7-8)
    local EXPIRY_FMT="$YR-$MO-$DY"

    while true; do
        show_banner
        echo "  $WHITE  [USER]      : VERIFIED (WELCOME $USERNAME)$NC"
        echo "  $WHITE  [HW-ID]     : $DEVICE_ID$NC"
        echo "  $GREEN  [LICENCE]   : VERIFIED (VALID UNTIL: $EXPIRY_FMT)$NC"
        echo "  $WHITE  [W.CHNNL]   : https://acesse.one/w-channel-me$NC"
        echo "  $WHITE  [WEB]       : $RAT_WEB$NC"
        echo "  $AQUA ╚═════════════════════════════════════════════════════════════════╝$NC"
        echo ""
        echo "  $BOLD ╔═•COMMAND HUB•════════════════════════════$NC"
        echo "  ${MAGENTA}│1 START EXECUTION${NC}"
        echo "  ${MAGENTA}│2 LICENCE RENEWAL${NC}"
        echo "  ${MAGENTA}│3 GUIDANCE${NC}"
        echo "  ${MAGENTA}│4 UPDATE TO NEWEST VERSION${NC}"
        echo "  ${MAGENTA}│5 UNINSTALL TOOL${NC}"
        echo "  ${MAGENTA}│6 EXIT${NC}"
        echo "  $BOLD ╚════════════════════════════════════════$NC"
        echo ""
        printf "~OPTION: "
        read hub_choice
        case "$hub_choice" in
            1) start_execution ;;
            2) echo "$YELLOW Go to $RAT_WEB to renew your licence$NC"; sleep 3 ;;
            3) show_guidance ;;
            4) update_tool ;;
            5) echo "$RED[!] Uninstalling...$NC"; rm -rf "$RAT_DIR"; rm -f "$PREFIX/bin/R@t" "$PREFIX/bin/R@tscan" "$PREFIX/bin/RSTzscan"; echo "$GREEN[+] Uninstalled.$NC"; exit 0 ;;
            6) echo "$CYAN Goodbye!$NC"; exit 0 ;;
            *) echo "$RED Invalid option$NC"; sleep 1 ;;
        esac
    done
}

# ─── Main Menu ────────────────────────────────────────────
main_menu() {
    if [ ! -f "$RAT_DIR/rat.sh" ]; then
        echo "$RED[!] Tool not installed properly. Run install again.$NC"
        exit 1
    fi
    scanner_login
}

# ─── START EXECUTION – FIXED ─────────────────────────────
start_execution() {
    # Do NOT clear screen – stay under command hub
    echo ""
    echo "$CYAN ╔═•Target directory where to look & save files•═══════$NC"
    echo "${MAGENTA}│1 R@t folder (Default)${NC}"
    echo "${MAGENTA}│2 Download folder${NC}"
    echo "${MAGENTA}│3 Current tool folder${NC}"
    echo "${MAGENTA}│4 Custom path (inside current folder)${NC}"
    echo "${MAGENTA}│5 Custom path (inside phone storage)${NC}"
    echo "$CYAN ╚════════════════════════════════════════════════════$NC"
    printf "~OPTION: "
    read dir_choice

    local WORK_DIR="$RAT_SAVED"
    case "$dir_choice" in
        1) WORK_DIR="$RAT_SAVED" ;;
        2) WORK_DIR="/storage/emulated/0/Download" ;;
        3) WORK_DIR="$PWD" ;;
        4) printf "Enter folder name: "; read custom_dir; WORK_DIR="$PWD/$custom_dir"; mkdir -p "$WORK_DIR" ;;
        5) printf "Enter full path: "; read custom_path; WORK_DIR="$custom_path" ;;
    esac
    mkdir -p "$WORK_DIR"
    echo "$GREEN [+] Working directory set to: $WORK_DIR$NC"
    sleep 1
    echo ""

    # Check paused scans
    if list_paused_scans; then
        echo ""
        echo "${MAGENTA}[R] Resume a paused scan (enter number)${NC}"
        echo "${MAGENTA}[N] Start a brand new scan${NC}"
        echo ""
        printf "~OPTION: "
        read resume_choice
        if [[ "$resume_choice" =~ ^[0-9]+$ ]]; then
            local idx=1
            local selected_file=""
            for f in "$RAT_CONFIG"/scan_state_*.json; do
                if [ -f "$f" ]; then
                    if [ $idx -eq "$resume_choice" ]; then
                        selected_file="$f"
                        break
                    fi
                    idx=$((idx+1))
                fi
            done
            if [ -n "$selected_file" ]; then
                R_TARGET=$(jq -r '.target_file' "$selected_file")
                R_POS=$(jq -r '.total_scanned' "$selected_file")
                R_TOTAL=$(jq -r '.total' "$selected_file")
                R_TIMEOUT=$(jq -r '.timeout' "$selected_file")
                R_BATCH=$(jq -r '.batch' "$selected_file")
                R_THREADS=$(jq -r '.threads' "$selected_file")
                R_DISPLAY=$(jq -r '.display' "$selected_file")
                R_CARRIER=$(jq -r '.carrier' "$selected_file")
                R_WORKDIR=$(jq -r '.work_dir' "$selected_file")
                R_TAG=$(jq -r '.tag' "$selected_file")
                R_ZR=$(jq -r '.zero_rated' "$selected_file")
                R_BLK=$(jq -r '.blocked' "$selected_file")
                R_BIL=$(jq -r '.billed' "$selected_file")
                R_BUGS=$(jq -r '.bugs' "$selected_file" 2>/dev/null || echo 0)
                R_DEADLOCK=$(jq -r '.deadlock_mode' "$selected_file")
                R_SCANMODE=$(jq -r '.scan_mode' "$selected_file")
                R_DNS=$(jq -r '.dns_mode' "$selected_file")
                R_BATCH_EN=$(jq -r '.batch_enabled' "$selected_file")
                rm -f "$selected_file"
                echo "$GREEN [+] Resuming scan from position $R_POS / $R_TOTAL$NC"
                sleep 1
                if [ "$R_SCANMODE" = "1" ] || [ "$R_SCANMODE" = "2" ]; then
                    run_scan_zero "$R_TARGET" "$R_TOTAL" "$R_TIMEOUT" "$R_BATCH" "$R_CARRIER" "$R_WORKDIR" "$R_TAG" "$R_THREADS" "$R_DEADLOCK" "$R_POS" "$R_ZR" "$R_BLK" "$R_BIL" "$R_DNS" "$R_BATCH_EN" "$R_SCANMODE"
                else
                    run_scan_active "$R_TARGET" "$R_TOTAL" "$R_TIMEOUT" "$R_BATCH" "$R_CARRIER" "$R_WORKDIR" "$R_TAG" "$R_THREADS" "$R_DEADLOCK" "$R_DNS" "$R_BATCH_EN" "$R_SCANMODE"
                fi
                return
            else
                echo "$RED Invalid selection.$NC"
                sleep 1
                return
            fi
        else
            echo "$GREEN Starting new scan...$NC"
        fi
    fi

    echo "$CYAN •TARGET INPUT MODE•$NC"
    echo " - Type a single host (e.g host.com)"
    echo " - Type multiple hosts separated by space"
    echo " - Type a filename (e.g 0host.txt)"
    echo " - Type 'nano' to open in-line edit"
    echo " - Or Auto detect files in current folder to choose (default)"
    echo ""
    printf "~OPTION: "
    read target_input

    local TARGET_FILE=""
    if [ "$target_input" = "nano" ]; then
        TARGET_FILE="$WORK_DIR/scan_targets.txt"
        nano "$TARGET_FILE"
    elif [ -f "$WORK_DIR/$target_input" ]; then
        TARGET_FILE="$WORK_DIR/$target_input"
    elif [ -f "$target_input" ]; then
        TARGET_FILE="$target_input"
    elif echo "$target_input" | grep -q ' '; then
        # Multiple hosts separated by space
        TARGET_FILE="$WORK_DIR/temp_targets.txt"
        for host in $target_input; do
            echo "$host" >> "$TARGET_FILE"
        done
    elif echo "$target_input" | grep -q '\.'; then
        # Single host (contains a dot)
        TARGET_FILE="$WORK_DIR/temp_targets.txt"
        echo "$target_input" > "$TARGET_FILE"
    else
        # Auto-detect .txt files
        echo "$YELLOW Auto-detecting .txt files in $WORK_DIR...$NC"
        local files=()
        for f in "$WORK_DIR"/*.txt; do
            [ -f "$f" ] && files+=("$f")
        done
        if [ ${#files[@]} -eq 0 ]; then
            echo "$RED [!] No .txt files found. Enter hosts manually.$NC"
            TARGET_FILE="$WORK_DIR/scan_targets.txt"
            nano "$TARGET_FILE"
        else
            local i=1
            for f in "${files[@]}"; do
                echo "  [${MAGENTA}$i${NC}] $(basename "$f")"
                i=$((i+1))
            done
            printf "~OPTION: "
            read file_choice
            if [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -ge 1 ] && [ "$file_choice" -le ${#files[@]} ]; then
                TARGET_FILE="${files[$((file_choice-1))]}"
            else
                echo "$RED Invalid selection. Using first file.$NC"
                TARGET_FILE="${files[0]}"
            fi
        fi
    fi

    if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
        echo "$RED[!] No valid target file.$NC"
        sleep 2
        return
    fi

    local TOTAL_HOSTS
    TOTAL_HOSTS=$(sort -u "$TARGET_FILE" | grep -c .)
    echo "$GREEN [+] File loaded - $TOTAL_HOSTS lines | $TOTAL_HOSTS unique hosts ready$NC"
    sleep 1
    echo ""

    # SCAN MODE
    echo "$CYAN ╔═•SCAN MODE•═════════════════════════════════════════════════════════════════════$NC"
    echo "${MAGENTA}│1 Strict 0-balance (full scan - highly Accurate)${NC}"
    echo "${MAGENTA}│2 Strict 0-balance Anti-FUP Mode (fast scan - saves data) [default]${NC}"
    echo "${MAGENTA}│3 Bypass & scan with active data (full scan - standard pro)${NC}"
    echo "${MAGENTA}│4 Bypass & scan with active data Anti-FUP mode (fast scan - low bandwidth)${NC}"
    echo "$CYAN ╚═════════════════════════════════════════════════════════════════════════════════$NC"
    echo ""

    while true; do
        printf "~OPTION: "
        read scan_mode
        [ -z "$scan_mode" ] && scan_mode="2"
        local MODE_DESC=""
        case "$scan_mode" in
            1) MODE_DESC="Strict 0-balance (full scan - highly Accurate)" ;;
            2) MODE_DESC="Strict 0-balance Anti-FUP Mode (fast scan - saves data)" ;;
            3) MODE_DESC="Bypass & scan with active data (full scan - standard pro)" ;;
            4) MODE_DESC="Bypass & scan with active data Anti-FUP mode (fast scan - low bandwidth)" ;;
            *) echo "$RED Invalid option$NC"; continue ;;
        esac
        echo "$GREEN [+] Selected: $MODE_DESC$NC"
        if verify_scan_mode "$scan_mode"; then
            echo "$GREEN [+] SCAN MODE VERIFIED & CONFIRMED!!$NC"
            echo "$GREEN [+] $MODE_DESC confirmed safe to proceed!!$NC"
            break
        else
            echo "$YELLOW [!] Scan mode verification failed. Please choose another option.$NC"
            echo "$CYAN ╔═•SCAN MODE•══════════════════════════════════════════════════════════════════════$NC"
            echo "${MAGENTA}│1 Strict 0-balance (full scan - highly Accurate)${NC}"
            echo "${MAGENTA}│2 Strict 0-balance Anti-FUP Mode (fast scan - saves data) [default]${NC}"
            echo "${MAGENTA}│3 Bypass & scan with active data (full scan - standard pro)${NC}"
            echo "${MAGENTA}│4 Bypass & scan with active data Anti-FUP mode (fast scan - low bandwidth)${NC}"
            echo "$CYAN ╚════════════════════════════════════════════════════════════════════════════════════$NC"
            echo ""
        fi
    done

    echo ""
    echo "$CYAN ╔═•DNS RESOLVER CASCADE•═══════════════════════════════$NC"
    echo "${MAGENTA}│1 No DNS (default OS Resolver - skip custom)${NC}"
    echo "${MAGENTA}│2 Network DNS (Extract from the carrier/router)${NC}"
    echo "${MAGENTA}│3 Cloud (1.1.1.1)${NC}"
    echo "${MAGENTA}│4 Google (8.8.8.8)${NC}"
    echo "$YELLOW │!] You can combine them! e.g type 134 or 34 or 1$NC"
    echo "$CYAN ╚═════════════════════════════════════════════════════$NC"
    printf "~OPTION: "
    read dns_choice
    [ -z "$dns_choice" ] && dns_choice="1"

    echo ""
    printf "Enter timeout in seconds (default 10): "
    read timeout
    [ -z "$timeout" ] && timeout=10
    printf "Enter max Retries (default 0): "
    read retries
    [ -z "$retries" ] && retries=0
    printf "Enter concurrency/Threads (default 100, max 200): "
    read threads
    [ -z "$threads" ] && threads=100
    [ "$threads" -gt 200 ] && threads=200

    echo ""
    echo "$CYAN Enable batching? (y/n) – if no, all domains will be processed in one batch.$NC"
    printf "~OPTION: "
    read batch_enabled
    [ -z "$batch_enabled" ] && batch_enabled="y"

    local batch_size=100
    if [ "$batch_enabled" = "y" ] || [ "$batch_enabled" = "Y" ]; then
        printf "Enter batch size (default 100): "
        read batch_size
        [ -z "$batch_size" ] && batch_size=100
    else
        batch_size=0
    fi

    printf "Mark your saved files as? or press enter to skip: "
    read file_tag

    echo ""
    echo "$CYAN ╔═•DEADLOCK RECOVERY MODE•═══════════════════════════════$NC"
    echo "${MAGENTA}│1 Manual Pause (wait for user) [default]${NC}"
    echo "${MAGENTA}│2 Auto-standby (wait for WiFi/Data to auto heal)${NC}"
    echo "${MAGENTA}│3 Auto wait (10s)${NC}"
    echo "${MAGENTA}│4 Auto wait (4s)${NC}"
    echo "$CYAN ╚═══════════════════════════════════════════════════════$NC"
    printf "~OPTION: "
    read deadlock_choice
    [ -z "$deadlock_choice" ] && deadlock_choice="1"

    echo ""
    echo "$CYAN ╔═•LOGGING CONFIGURATION•═══════════════════════$NC"
    printf "Enter full log mode (press enter to skip)\n~OPTION: "
    read log_mode
    echo "$GREEN [+] Standard logging enabled.$NC"

    echo ""
    echo "$CYAN ╔═•ENGINE CONFIGURATION•═════════════════════════════════$NC"
    echo "  🎯 TARGET...      : $WORK_DIR/$(basename "$TARGET_FILE")"
    echo "  📊 TOTAL HOSTS.   : $TOTAL_HOSTS"
    echo "  🚀 THREADS.       : $threads"
    echo "  📦 BATCH SIZE.    : $([ "$batch_enabled" = "y" ] && echo "$batch_size" || echo "N/A (all in one batch)")"
    echo "  ⏳ TIMEOUT..      : $timeout""s"
    echo "  🦯 DNS CHAIN      : $dns_choice"
    echo "$CYAN ╚═════════════════════════════════════════════════════════$NC"
    echo ""
    printf "~OPTION: "
    read confirm

    echo ""
    echo -n "$CYAN[+] Analysing network...$NC"
    sleep 1
    echo ""
    local CARRIER
    CARRIER=$(detect_carrier)
    echo "$GREEN [+] Network Carrier: $CARRIER$NC"
    sleep 0.5

    local display_mode=1

    local final_batch_size=$batch_size
    [ "$batch_enabled" != "y" ] && [ "$batch_enabled" != "Y" ] && final_batch_size=$TOTAL_HOSTS

    if [ "$scan_mode" = "1" ] || [ "$scan_mode" = "2" ]; then
        run_scan_zero "$TARGET_FILE" "$TOTAL_HOSTS" "$timeout" "$final_batch_size" "$CARRIER" "$WORK_DIR" "$file_tag" "$threads" "$deadlock_choice" "0" "0" "0" "0" "$dns_choice" "$batch_enabled" "$scan_mode"
    else
        run_scan_active "$TARGET_FILE" "$TOTAL_HOSTS" "$timeout" "$final_batch_size" "$CARRIER" "$WORK_DIR" "$file_tag" "$threads" "$deadlock_choice" "$dns_choice" "$batch_enabled" "$scan_mode"
    fi

    # No extra prompt – show_next_prompt already handles return/exit
}
