# =========================================================
#  UI – Banner, Guidance, Display
# =========================================================

clear_line() { printf "\r\033[K"; }
save_cursor() { printf "\033[s"; }
restore_cursor() { printf "\033[u"; }
move_up() { printf "\033[%dA" "$1"; }

show_banner() {
    clear
    echo "${PURPLE}=====================================================================${NC}"
    echo "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${PURPLE}║${AQUA}        ██████╗ ███████╗██████╗ ███████╗██╗     ███████╗████████╗  ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}        ██╔══██╗██╔════╝██╔══██╗██╔════╝██║     ██╔════╝╚══██╔══╝  ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}        ██████╔╝█████╗  ██████╔╝█████╗  ██║     ███████╗   ██║     ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}        ██╔══██╗██╔══╝  ██╔══██╗██╔══╝  ██║     ╚════██║   ██║     ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}        ██║  ██║███████╗██████╔╝███████╗███████╗███████║   ██║     ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}        ╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝╚══════╝╚══════╝   ╚═╝     ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}                          Tech${BLUE}sys${AQUA}tem: ${BLUE}R@${AQUA}t${PURPLE}|${GOLD}V3.1${NC}                     ${PURPLE}║${NC}"
    echo "${PURPLE}║${AQUA}      ${YELLOW}•${AQUA}REBEL SQUAD TERRORIST ${YELLOW}R@${RED}- ZERO-RATED SCANNER TOOL${AQUA}${YELLOW}•${NC}         ${PURPLE}║${NC}"
    echo "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
}

show_header_with_user() {
    local USERNAME="$1" DEVICE_ID="$2" EXPIRY_FMT="$3"
    show_banner
    echo "${PURPLE}║${NC} ${WHITE}[USER]     :${NC} ${GREEN}VERIFIED (WELCOME, $USERNAME)${NC}"
    echo "${PURPLE}║${NC} ${WHITE}[HW-ID]    :${NC} ${GREEN}$DEVICE_ID${NC}"
    echo "${PURPLE}║${NC} ${WHITE}[LICENSE]  :${NC} ${GREEN}VERIFIED (VALID UNTIL: $EXPIRY_FMT)${NC}"
    echo "${PURPLE}║${NC} ${WHITE}[W-CHNNL]  :${NC} ${BLUE}https://acesse.one/w-channel1-me${NC}"
    echo "${PURPLE}║${NC}              ${BLUE}https://acesse.one/w-channel2-me${NC}"
    echo "${PURPLE}║${NC} ${WHITE}[WEB]      :${NC} ${BLUE}$RAT_WEB${NC}"
    echo "${PURPLE}║${NC}                                                                   ${NC}"
    echo "${PURPLE}║${NC}       ${YELLOW}•RST:REBELSQUADTERRORISTtechsystem•  •ROLEMODEL:TK.M@☆${NC}"
    echo "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_guidance() {
    clear
    echo "${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo "${MAGENTA}║          GUIDANCE                      ║${NC}"
    echo "${MAGENTA}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "${AQUA}1 Prepare a host list file (.txt) with one host per line${NC}"
    echo "${AQUA}2 Choose Strict 0-balance mode for zero-rated scanning${NC}"
    echo "${AQUA}3 Use DNS Cascade (combine Cloud + Google for best results)${NC}"
    echo "${AQUA}4 Set timeout to 20s, threads to 100, batch size to 400${NC}"
    echo "${AQUA}5 Results saved to the folder you chose${NC}"
    echo ""
    echo "${YELLOW}Tip: Use Anti-FUP mode to save data on mobile networks${NC}"
    echo ""
    read -p "Press Enter to continue..."
}
