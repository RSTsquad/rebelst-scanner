#!/bin/bash
# =========================================================
#  R@t Scanner – One-Click Installer
# =========================================================

REPO="https://raw.githubusercontent.com/RSTsquad/rebelst-scanner/main"

clear
echo -e "\033[0;34m══════════════════════════════════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;34m   [R•S•T]🇦🇶 🩵INSTALLATION HUB| THANKS😇 FOR INSTALLING ME R@t 0-SCANNER 💙\033[0m"
echo -e "\033[0;34m══════════════════════════════════════════════════════════════════════════════════════\033[0m"
echo ""
echo -e "\033[1;33m[!] STORAGE PERMISION REQUIRED [!]\033[0m"
echo -e "\033[1;36m   1. A settings screen will open in a moment.\033[0m"
echo -e "\033[1;36m   2. Scroll down or use search bar/icon to find 'termux'.\033[0m"
echo -e "\033[1;36m   3. Tap the switch to turn it 'on' (Allowing access to manage all files).\033[0m"
echo -e "\033[1;36m   4. Then press your phone's back button to return here in termux app.\033[0m"
echo ""
echo -e "\033[1;33m[*] Opening settings in 6 seconds... please carefully read the steps above!\033[0m"
sleep 6
termux-setup-storage 2>/dev/null
sleep 2
echo -e "\033[1;32m[+] It appears this action is already set now tool will proceed in 2s...\033[0m"
sleep 2
echo ""

while true; do
    echo -n -e "\033[1;33m[🔒] Enter The tool PIN to proceed: \033[0m"
    read -r pin < /dev/tty
    if [ "$pin" = "083312" ]; then break; fi
    echo -e "\033[0;31m[!] INCORRECT PIN, CORRECT PIN IS REQUIRED RE ENTER THE CORRECT PIN NOW\033[0m"
done

echo ""
echo -e "\033[1;36m[*] Setting up the tool (This may take 1 - 2 minutes)...\033[0m"
DEBIAN_FRONTEND=noninteractive pkg update -y >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive pkg install -y curl jq coreutils dig termux-api >/dev/null 2>&1
mkdir -p ~/R@t/core ~/R@t/saved ~/R@t/logs ~/R@t/results ~/R@t/.config
echo -e "\033[1;32m[+] Tool framework set successfully✓\033[0m"
echo -e "\033[1;32m[+] Member login sections for auto-login set✓\033[0m"
echo ""
echo -e "\033[1;36m[📥] Installing dependencies...\033[0m"
cd ~/R@t
for file in rat.sh install.sh core/config.sh core/utils.sh core/ui.sh core/login.sh core/scanner.sh; do
    dir=$(dirname "$file")
    [ "$dir" != "." ] && mkdir -p "$dir"
    curl -s -o "$file" "$REPO/$file"
done
chmod +x rat.sh core/*.sh 2>/dev/null
echo -e "\033[1;32m[+] Tool folders set✓\033[0m"
echo -e "\033[1;32m[+] curl installed✓\033[0m"
echo -e "\033[1;32m[+] jq installed✓\033[0m"
echo -e "\033[1;32m[+] coreutils installed✓\033[0m"
echo -e "\033[1;32m[+] dig installed✓\033[0m"
echo -e "\033[1;32m[+] termux-api installed✓\033[0m"
for a in R@t R@tscan RSTzscan; do
    if ! grep -q "alias $a=" ~/.bashrc 2>/dev/null; then
        echo "alias $a=\"bash ~/R@t/rat.sh --run\"" >> ~/.bashrc
    fi
done
echo ""
echo -e "\033[1;32m[++] Tool is installed and set successfully✓\033[0m"
echo ""
echo -e "\033[1;33m[*] You can now launch the scanner from anywhere by typing any of these:\033[0m"
echo ""
echo -e "\033[1;33m     R@t\033[0m"
echo -e "\033[1;33m     R@tscan\033[0m"
echo -e "\033[1;33m     RSTzscan\033[0m"
echo ""
echo -n -e "\033[1;33m~R@enter: \033[0m"
read -r cmd < /dev/tty
case "$cmd" in
    R@t|R@tscan|RSTzscan|RSTscan|R@scan) exec bash ~/R@t/rat.sh --run ;;
    *) echo -e "\033[1;33m[*] Run any of the commands to start the tool.\033[0m" ;;
esac
