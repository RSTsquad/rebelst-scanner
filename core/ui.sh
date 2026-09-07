# =========================================================
#  UI – Banners, Guidance, Display Helpers
# =========================================================

# ─── Helpers ──────────────────────────────────────────────
clear_line() { printf "\r\033[K"; }
save_cursor() { printf "\033[s"; }
restore_cursor() { printf "\033[u"; }
move_up() { printf "\033[%dA" "$1"; }

# ─── Banner ──────────────────────────────────────────────
show_banner() {
    clear
    echo ""
    echo "  $AQUA ╔══════════════════════════════════════════════════════════════════╗$NC"
    echo "  $AQUA       ██████╗ ███████╗██████╗ ███████╗██╗     ███████╗████████╗$NC"
    echo "  $AQUA       ██╔══██╗██╔════╝██╔══██╗██╔════╝██║     ██╔════╝╚══██╔══╝$NC"
    echo "  $AQUA       ██████╔╝█████╗  ██████╔╝█████╗  ██║     ███████╗   ██║$NC"
    echo "  $AQUA       ██╔══██╗██╔══╝  ██╔══██╗██╔══╝  ██║     ╚════██║   ██║$NC"
    echo "  $AQUA       ██║  ██║███████╗██████╔╝███████╗███████╗███████║   ██║$NC"
    echo "  $AQUA       ╚══╝  ╚══╝╚══════╝╚═════╝ ╚══════╝╚══════╝╚══════╝   ╚═╝$NC"
    echo "  $AQUA                                 Techsystem: R@t$NC"
    echo "  $AQUA  REBEL SQUAD TERRORIST ZERO-RATED SCANNER TOOL | V$RAT_VERSION  ©$NC"
    echo "  $AQUA  RST:REBELSQUADTERRORISTtechsystem  ROLEMODEL:TK.M@☆$NC"
    echo "  $AQUA ╔═════════════════════════════════════════════════════════════════╗$NC"
}

show_guidance() {
    clear
    echo "$CYAN ╔════════════════════════════════════════╗$NC"
    echo "$CYAN ║          GUIDANCE                      ║$NC"
    echo "$CYAN ╚════════════════════════════════════════╝$NC"
    echo ""
    echo "${MAGENTA}1 Prepare a host list file (.txt) with one host per line${NC}"
    echo "${MAGENTA}2 Choose Strict 0-balance mode for zero-rated scanning${NC}"
    echo "${MAGENTA}3 Use DNS Cascade (combine Cloud + Google for best results)${NC}"
    echo "${MAGENTA}4 Set timeout to 20s, threads to 100, batch size to 400${NC}"
    echo "${MAGENTA}5 Results saved to the folder you chose${NC}"
    echo ""
    echo "$YELLOW Tip: Use Anti-FUP mode to save data on mobile networks$NC"
    echo ""
    read -p "Press Enter to continue..."
}

# ─── Verify Scan Mode ─────────────────────────────────────
verify_scan_mode() {
    local mode="$1"
    echo ""
    echo "$YELLOW [+] Verifying scan mode - running real network test...$NC"
    sleep 1
    local test_code
    test_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "https://google.com" 2>/dev/null)
    if [ "$mode" = "1" ] || [ "$mode" = "2" ]; then
        if [ "$test_code" = "200" ] || [ "$test_code" = "301" ] || [ "$test_code" = "302" ]; then
            echo "$RED [!] WARNING: Active data detected! You are NOT on zero balance.$NC"
            echo "$YELLOW [!] Strict 0-balance mode requires NO active data connection.$NC"
            echo "$YELLOW [!] Scan results will NOT be accurate in this mode.$NC"
            echo ""
            echo "${MAGENTA}[1] Choose another scan mode${NC}"
            echo "${MAGENTA}[2] Continue anyway (not recommended)${NC}"
            printf "~OPTION: "
            read verify_choice
            [ "$verify_choice" != "2" ] && return 1
        else
            echo "$GREEN [+] Zero-balance mode verified - no active data detected.$NC"
            echo "$GREEN [+] Safe to proceed with strict 0-balance scanning.$NC"
        fi
    elif [ "$mode" = "3" ] || [ "$mode" = "4" ]; then
        if [ "$test_code" != "200" ] && [ "$test_code" != "301" ] && [ "$test_code" != "302" ]; then
            echo "$RED [!] WARNING: No active data detected!$NC"
            echo "$YELLOW [!] Bypass & scan mode requires active data connection.$NC"
            echo "$YELLOW [!] Scan results will NOT be accurate without data.$NC"
            echo ""
            echo "${MAGENTA}[1] Choose another scan mode${NC}"
            echo "${MAGENTA}[2] Continue anyway (not recommended)${NC}"
            printf "~OPTION: "
            read verify_choice
            [ "$verify_choice" != "2" ] && return 1
        else
            echo "$GREEN [+] Active data verified - safe to proceed with bypass mode.$NC"
        fi
    fi
    sleep 1
    return 0
}