# =========================================================
#  LOGIN & COMMAND HUB
# =========================================================

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