# =========================================================
#  LOGIN & COMMAND HUB
# =========================================================

scanner_login() {
    clear
    echo "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}              💙 REBELS LOGIN PG🩵${NC}"
    echo "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [ -f "$RAT_KEY_FILE" ] && [ -f "$RAT_USER_FILE" ]; then
        local SAVED_KEY=$(cat "$RAT_KEY_FILE")
        local RESULT=$(verify_vkey "$SAVED_KEY")
        if [ "$RESULT" != "INVALID" ] && [ "$RESULT" != "WRONG_DEVICE" ] && [ "$RESULT" != "EXPIRED" ]; then
            local USERNAME=$(cat "$RAT_USER_FILE")
            echo "${GREEN}[!] ACCESS GRANTED AUTOMATICALLY LOGGING IN!!${NC}"
            sleep 1
            command_hub "$USERNAME"
            return
        else
            rm -f "$RAT_KEY_FILE" "$RAT_USER_FILE"
        fi
    fi

    local DEVICE_ID=$(get_device_id)
    echo "${WHITE}YOU TERMUX DEVICE ID: ${GREEN}$DEVICE_ID${NC}"
    echo ""
    echo "${AQUA}SEND THE TERMUX DEVICE ID TO THE R•S•T ADMINS or SIMPLY GO TO OUR WEBSITE https://rst-freenet-hub.base44.app"
    echo "ON THE WEB CLICK MENU ICON(☰) AND GO TO HUNTING-HUB PAGE AND LOOK FOR"
    echo "V-KEY(VERIFICATION-KEY) THEN YOU PUT YOUR USERNAME AND YOUR TERMUX DEVICE ID"
    echo "THEN CLICK GENERATE WAIT FEW SECONDS WHILE IT IS GENERATING THEREAFTER"
    echo "YOU'LL BE GIVEN YOUR PM-KEY/V-KEY AND COMEBACK AND PASTE IT HERE${NC}"
    echo ""

    # Username max 10 chars
    local USERNAME=""
    while true; do
        printf "${YELLOW}ENTER USERNAME: ${NC}"
        read USERNAME
        if [ -z "$USERNAME" ]; then
            echo "${RED}[!] Username required${NC}"
            continue
        fi
        if [ ${#USERNAME} -gt 10 ]; then
            echo "${RED}[!] Username must not exceed 10 characters (incl. spaces). You entered ${#USERNAME}.${NC}"
            continue
        fi
        break
    done

    # V-KEY with retry loop
    while true; do
        printf "${YELLOW}ENTER PM/V-KEY: ${NC}"
        read vkey
        local RESULT=$(verify_vkey "$vkey")
        case "$RESULT" in
            "INVALID")
                echo "${RED}[!] INCORRECT V-KEY! Please try again.${NC}"
                continue
                ;;
            "WRONG_DEVICE")
                echo "${RED}[!] INVALID: This key was generated for a different device! Please try again.${NC}"
                continue
                ;;
            "EXPIRED")
                echo "${RED}[!] INVALID: Your V-Key has expired! Generate a new one.${NC}"
                continue
                ;;
            *)
                echo "$vkey" > "$RAT_KEY_FILE"
                echo "$USERNAME" > "$RAT_USER_FILE"
                chmod 600 "$RAT_KEY_FILE" "$RAT_USER_FILE"
                echo ""
                echo "${GREEN}[+] [+]ACCESS GRANTED. KEY SAVED FOR AUTO-LOGIN! WELCOME TO PM USER${NC}"
                sleep 2
                command_hub "$USERNAME"
                return
                ;;
        esac
    done
}

command_hub() {
    local USERNAME="$1"
    local DEVICE_ID=$(get_device_id)
    local VKEY=$(cat "$RAT_KEY_FILE")
    local EXPIRY=$(echo "$VKEY" | cut -d'-' -f3)
    local EXPIRY_FMT="$(echo "$EXPIRY" | cut -c1-4)-$(echo "$EXPIRY" | cut -c5-6)-$(echo "$EXPIRY" | cut -c7-8)"

    while true; do
        show_header_with_user "$USERNAME" "$DEVICE_ID" "$EXPIRY_FMT"
        echo "${MAGENTA}╔═•COMMAND HUB•══════════════════════════════════════════════════${NC}"
        echo "${AQUA}║ [S]TART EXECUTION${NC}"
        echo "${AQUA}║ [L]ICENCE RENEWAL${NC}"
        echo "${AQUA}║ [G]UIDANCE${NC}"
        echo "${AQUA}║ [U]PDATE TO NEWEST VERSION${NC}"
        echo "${AQUA}║ [X]UNINSTALL TOOL${NC}"
        echo "${AQUA}║ [E]XIT${NC}"
        echo "${MAGENTA}╚═══════════════════════════════════════════════════════════════${NC}"
        prompt_rat
        read hub_choice
        case "$hub_choice" in
            s|S) start_execution "$USERNAME" "$DEVICE_ID" "$EXPIRY_FMT" ;;
            l|L) echo "${YELLOW}Go to $RAT_WEB to renew${NC}"; sleep 3 ;;
            g|G) show_guidance ;;
            u|U) update_tool ;;
            x|X) echo "${RED}[!] Uninstalling...${NC}"; rm -rf "$RAT_DIR"; rm -f "$PREFIX/bin/R@t" "$PREFIX/bin/R@tscan" "$PREFIX/bin/RSTzscan"; echo "${GREEN}[+] Uninstalled.${NC}"; exit 0 ;;
            e|E) echo "${CYAN}Goodbye!${NC}"; exit 0 ;;
            *) echo "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

main_menu() {
    [ ! -f "$RAT_DIR/rat.sh" ] && { echo "${RED}[!] Tool not installed.${NC}"; exit 1; }
    scanner_login
}

# ─── Execution flow (replaces whole screen) ──────────────
start_execution() {
    local USERNAME="$1" DEVICE_ID="$2" EXPIRY_FMT="$3"
    show_header_with_user "$USERNAME" "$DEVICE_ID" "$EXPIRY_FMT"
    echo "${MAGENTA}╔═•Target directory where to look for & save files•═════════════${NC}"
    echo "${AQUA}║ [1]R@t folder (Default)${NC}"
    echo "${AQUA}║ [2]Download folder${NC}"
    echo "${AQUA}║ [3]Current tool folder${NC}"
    echo "${AQUA}║ [4]Custom path(inside current folder)${NC}"
    echo "${AQUA}║ [5]Custom path(inside phone storage)${NC}"
    echo "${MAGENTA}╚═══════════════════════════════════════════════════════════════${NC}"
    prompt_rat
    read dir_choice

    local WORK_DIR="$RAT_SAVED"
    case "$dir_choice" in
        1) WORK_DIR="$RAT_SAVED" ;;
        2) WORK_DIR="/storage/emulated/0/Download" ;;
        3) WORK_DIR="$PWD" ;;
        4) printf "Enter folder name: "; read cd; WORK_DIR="$PWD/$cd"; mkdir -p "$WORK_DIR" ;;
        5) printf "Enter full path: "; read cp; WORK_DIR="$cp" ;;
    esac
    mkdir -p "$WORK_DIR"
    echo "${GREEN}[+] Working directory set to:$WORK_DIR${NC}"

    # Paused scans
    local RESUME_FILE=""
    local resume_out=$(list_paused_scans "$WORK_DIR")
    if [ -n "$resume_out" ]; then
        local resume_choice=$(echo "$resume_out" | tail -1)
        if [[ "$resume_choice" =~ ^[1-4]$ ]]; then
            local idx=1
            for f in "$WORK_DIR"/PAUSED_*.txt; do
                [[ "$f" == *_hosts.txt ]] && continue
                [ -f "$f" ] && [ $idx -eq "$resume_choice" ] && { RESUME_FILE="$f"; break; }
                idx=$((idx+1))
            done
        elif [ "$resume_choice" = "m" ] || [ "$resume_choice" = "M" ]; then
            printf "Enter paused file name: "; read pfile
            [ -f "$WORK_DIR/$pfile" ] && RESUME_FILE="$WORK_DIR/$pfile"
        fi
    fi

    if [ -n "$RESUME_FILE" ]; then
        R_TARGET=$(jq -r '.target_file' "$RESUME_FILE" 2>/dev/null)
        local R_HOSTS="${RESUME_FILE%.txt}_hosts.txt"
        [ -f "$R_HOSTS" ] && R_TARGET="$R_HOSTS"
        R_POS=$(jq -r '.total_scanned' "$RESUME_FILE")
        R_TOTAL=$(jq -r '.total' "$RESUME_FILE")
        R_TIMEOUT=$(jq -r '.timeout' "$RESUME_FILE")
        R_BATCH=$(jq -r '.batch' "$RESUME_FILE")
        R_THREADS=$(jq -r '.threads' "$RESUME_FILE")
        R_CARRIER=$(jq -r '.carrier' "$RESUME_FILE")
        R_WORKDIR=$(jq -r '.work_dir' "$RESUME_FILE")
        R_TAG=$(jq -r '.tag' "$RESUME_FILE")
        R_ZR=$(jq -r '.zero_rated' "$RESUME_FILE")
        R_BLK=$(jq -r '.blocked' "$RESUME_FILE")
        R_BIL=$(jq -r '.billed' "$RESUME_FILE")
        R_BUGS=$(jq -r '.bugs' "$RESUME_FILE" 2>/dev/null || echo 0)
        R_ELAPSED=$(jq -r '.elapsed_sec' "$RESUME_FILE")
        R_DEADLOCK=$(jq -r '.deadlock_mode' "$RESUME_FILE")
        R_SCANMODE=$(jq -r '.scan_mode' "$RESUME_FILE")
        R_DNS=$(jq -r '.dns_mode' "$RESUME_FILE")
        R_BATCH_EN=$(jq -r '.batch_enabled' "$RESUME_FILE")
        rm -f "$RESUME_FILE"
        export RESUME_ELAPSED="$R_ELAPSED"
        echo "${GREEN}[+] Resuming from $R_POS / $R_TOTAL${NC}"
        sleep 1
        if [ "$R_SCANMODE" = "1" ] || [ "$R_SCANMODE" = "2" ]; then
            run_scan_zero "$R_TARGET" "$R_TOTAL" "$R_TIMEOUT" "$R_BATCH" "$R_CARRIER" "$R_WORKDIR" "$R_TAG" "$R_THREADS" "$R_DEADLOCK" "$R_POS" "$R_ZR" "$R_BLK" "$R_BIL" "$R_DNS" "$R_BATCH_EN" "$R_SCANMODE"
        else
            run_scan_active "$R_TARGET" "$R_TOTAL" "$R_TIMEOUT" "$R_BATCH" "$R_CARRIER" "$R_WORKDIR" "$R_TAG" "$R_THREADS" "$R_DEADLOCK" "$R_DNS" "$R_BATCH_EN" "$R_SCANMODE"
        fi
        return
    fi

    echo ""
    echo "${YELLOW}• TARGET INPUT MODE•${NC}"
    echo "${AQUA}- Type a single host (e.g host.com)${NC}"
    echo "${AQUA}- Type multiple hosts seperated by space${NC}"
    echo "${AQUA}- Type a filename(e.g 0host.txt)${NC}"
    echo "${AQUA}- Type 'nano' to open in-line edit${NC}"
    echo "${AQUA}- Or Auto detect files in current folder to choose(default)${NC}"
    echo ""
    printf "${GREEN}SNI HOST(S) OR HOSTS FILE: ${NC}"
    read target_input

    local TARGET_FILE=""
    if [ "$target_input" = "nano" ]; then
        TARGET_FILE="$WORK_DIR/scan_targets.txt"; nano "$TARGET_FILE"
    elif [[ "$target_input" == *.txt ]]; then
        if [ -f "$WORK_DIR/$target_input" ]; then TARGET_FILE="$WORK_DIR/$target_input"
        elif [ -f "$target_input" ]; then TARGET_FILE="$target_input"
        else echo "${RED}[!] File '$target_input' not found.${NC}"; sleep 2; return; fi
    elif [ -f "$WORK_DIR/$target_input" ]; then TARGET_FILE="$WORK_DIR/$target_input"
    elif echo "$target_input" | grep -q ' '; then
        TARGET_FILE="$WORK_DIR/temp_targets.txt"; > "$TARGET_FILE"
        for host in $target_input; do echo "$host" >> "$TARGET_FILE"; done
    elif echo "$target_input" | grep -q '\.'; then
        TARGET_FILE="$WORK_DIR/temp_targets.txt"; > "$TARGET_FILE"; echo "$target_input" > "$TARGET_FILE"
    else
        echo "${YELLOW}Auto-detecting files in $WORK_DIR...${NC}"
        local files=(); for f in "$WORK_DIR"/*.txt; do [ -f "$f" ] && files+=("$f"); done
        [ ${#files[@]} -eq 0 ] && { echo "${RED}[!] No files.${NC}"; return; }
        local i=1
        for f in "${files[@]}"; do
            [ $i -gt 4 ] && break
            echo "  [${AQUA}$i${NC}] $(basename "$f")"; i=$((i+1))
        done
        prompt_rat; read fc
        if [[ "$fc" =~ ^[0-9]+$ ]] && [ "$fc" -ge 1 ] && [ "$fc" -le ${#files[@]} ]; then
            TARGET_FILE="${files[$((fc-1))]}"
        else
            [ -f "$WORK_DIR/$fc" ] && TARGET_FILE="$WORK_DIR/$fc" || TARGET_FILE="${files[0]}"
        fi
    fi
    [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ] && { echo "${RED}[!] No valid target.${NC}"; sleep 2; return; }

    echo "${AQUA}[*] Loading host file...${NC}"
    local TOTAL_HOSTS=$(sort -u "$TARGET_FILE" | grep -c .)
    echo "${GREEN}[+] File loaded - $TOTAL_HOSTS lines | $TOTAL_HOSTS unique hosts ready.${NC}"
    sleep 0.5

    # SCAN MODE
    echo ""
    echo "${MAGENTA}╔═•SCAN MODE•════════════════════════════════════════════════════${NC}"
    echo "${AQUA}║ [1]Strict 0-balance(full scan-highly Accurate)${NC}"
    echo "${AQUA}║ [2]Strict 0-balance Anti-FUP Mode(fast scan-saves data highly accurate)[default]${NC}"
    echo "${AQUA}║ [3]Bypass & scan with active data(full scan-standard pro)${NC}"
    echo "${AQUA}║ [4]Bypass & scan with active data Anti-FUP mode(fast scan-low bandwidth)${NC}"
    echo "${MAGENTA}╚═══════════════════════════════════════════════════════════════${NC}"
    prompt_rat; read scan_mode
    [ -z "$scan_mode" ] && scan_mode="2"

    # DNS
    echo ""
    echo "${MAGENTA}╔═•DNS RESOLVER CASCADE•═════════════════════════════════════════${NC}"
    echo "${AQUA}║ [1]No DNS(default OS Resolver-skip custom)${NC}"
    echo "${AQUA}║ [2]Network DNS(Extract from the carrier/router)${NC}"
    echo "${AQUA}║ [3]Cloud (1.1.1.1)${NC}"
    echo "${AQUA}║ [4]Google (8.8.8.8)${NC}"
    echo "${YELLOW}║ [!]You can combine them! e.g type 134 or 34 or 1${NC}"
    echo "${MAGENTA}╚════════════════════════════════════════════════════════════════${NC}"
    prompt_rat; read dns_choice
    [ -z "$dns_choice" ] && dns_choice="1"

    printf "${AQUA}Enter timeout in seconds(default 10): ${NC}\n"; prompt_rat; read timeout; [ -z "$timeout" ] && timeout=10
    printf "${AQUA}Enter max Retries(default 0): ${NC}\n"; prompt_rat; read retries; [ -z "$retries" ] && retries=0
    printf "${AQUA}Enter concurrency/Threads(default 100): ${NC}\n"; prompt_rat; read threads; [ -z "$threads" ] && threads=100
    printf "${AQUA}Enter batch size(default 100): ${NC}\n"; prompt_rat; read batch_size; [ -z "$batch_size" ] && batch_size=100
    printf "${AQUA}Mark your saved files as? or press enter to skip: ${NC}\n"; prompt_rat; read file_tag

    # DEADLOCK
    echo ""
    echo "${MAGENTA}╔═•DEADLOCK RECOVERY MODE•═══════════════════════════════════════${NC}"
    echo "${AQUA}║ [1] Manual Pause (wait for user) [default]${NC}"
    echo "${AQUA}║ [2]Auto-standby(wait for WiFi/Data to auto heal${NC}"
    echo "${AQUA}║ [3]Shizuku Auto-Airplane Mode (Requires Shizuku)${NC}"
    echo "${MAGENTA}╚════════════════════════════════════════════════════════════════${NC}"
    prompt_rat; read deadlock_choice
    [ -z "$deadlock_choice" ] && deadlock_choice="1"

    echo ""
    echo "${MAGENTA}╔═•LOGGING CONFIGURATION•════════════════════════════════════════${NC}"
    printf "${AQUA}║ Enter full log mode (press enter to skip)${NC}\n"
    echo "${MAGENTA}╚════════════════════════════════════════════════════════════════${NC}"
    prompt_rat; read log_mode
    echo "${AQUA}[+]Standard logging enabled.${NC}"

    # ENGINE CONFIG
    echo ""
    local dns_display="$dns_choice"; [ "$dns_choice" = "1" ] && dns_display="Default"
    echo "${MAGENTA}╔═•ENGINE CONFIGURATION•═════════════════════════════════════════${NC}"
    echo "${AQUA}║ 🎯 TARGET        : $WORK_DIR/$(basename "$TARGET_FILE")${NC}"
    echo "${AQUA}║ 📊 TOTAL HOSTS   : $TOTAL_HOSTS${NC}"
    echo "${YELLOW}║ 🚀 THREADS.      : $threads${NC}"
    echo "${YELLOW}║ 📦 BATCH SIZE    : $batch_size${NC}"
    echo "${AQUA}║ ⏳ TIMEOUT       : ${timeout}s${NC}"
    echo "${YELLOW}║ 🦯 DNS CHAIN     : $dns_display${NC}"
    echo "${MAGENTA}╚════════════════════════════════════════════════════════════════${NC}"

    # CUSTOM NETWORK SETUP
    echo ""
    echo "${MAGENTA}╔═•CUSTOM NETWORK SETUP•════════════════════════════════════════${NC}"
    echo "${AQUA}║ [1] Skip (Auto-Detect Network / Default Wi-Fi) [Default]${NC}"
    echo "${AQUA}║ [2] Proceed Custom Setup Network${NC}"
    echo "${MAGENTA}╚════════════════════════════════════════════════════════════════${NC}"
    prompt_rat; read net_choice
    [ -z "$net_choice" ] && net_choice="1"

    local CARRIER=""
    if [ "$net_choice" = "2" ]; then
        CARRIER=$(custom_network_setup "$scan_mode")
    else
        CARRIER=$(detect_carrier)
        echo "${AQUA}[:°] ANALYZING NETWORK...${NC} [ - R@ - - ]"
        sleep 1
        echo "${GREEN}[+] Network Carrier: $CARRIER${NC}"
    fi
    sleep 1

    local final_batch=$batch_size

    if [ "$scan_mode" = "1" ] || [ "$scan_mode" = "2" ]; then
        run_scan_zero "$TARGET_FILE" "$TOTAL_HOSTS" "$timeout" "$final_batch" "$CARRIER" "$WORK_DIR" "$file_tag" "$threads" "$deadlock_choice" "0" "0" "0" "0" "$dns_choice" "y" "$scan_mode"
    else
        run_scan_active "$TARGET_FILE" "$TOTAL_HOSTS" "$timeout" "$final_batch" "$CARRIER" "$WORK_DIR" "$file_tag" "$threads" "$deadlock_choice" "$dns_choice" "y" "$scan_mode"
    fi
}
