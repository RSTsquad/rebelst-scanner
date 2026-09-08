#!/bin/bash
# =========================================================
#  R@t Scanner – One‑Click Installer
# =========================================================

REPO="https://raw.githubusercontent.com/RSTsquad/rebelst-scanner/main"

echo -e "\033[1;36m[+] Installing R@t Scanner Tool v2.8...\033[0m"
echo -e "\033[1;33m[+] Installing dependencies...\033[0m"
pkg update -y 2>/dev/null
pkg install -y curl jq coreutils dig 2>/dev/null
echo -e "\033[1;32m[+] curl installed ✓\033[0m"
echo -e "\033[1;32m[+] jq installed ✓\033[0m"
echo -e "\033[1;32m[+] coreutils installed ✓\033[0m"
echo -e "\033[1;32m[+] dig installed ✓\033[0m"
echo -e "\033[1;33m[+] This may take a few minutes...\033[0m"
sleep 1

mkdir -p ~/R@t/core
cd ~/R@t

for file in rat.sh core/config.sh core/utils.sh core/ui.sh core/login.sh core/scanner.sh; do
    echo -e "\033[1;33m[+] Downloading $file...\033[0m"
    dir=$(dirname "$file")
    [ "$dir" != "." ] && mkdir -p "$dir"
    curl -s -o "$file" "$REPO/$file"
done

chmod +x rat.sh core/*.sh

# Create aliases
for alias_name in R@t R@tscan RSTzscan; do
    if ! grep -q "alias $alias_name=" ~/.bashrc 2>/dev/null; then
        echo "alias $alias_name=\"bash ~/R@t/rat.sh --run\"" >> ~/.bashrc
    fi
done

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo -e "\033[1;36m[+] YOU CAN NOW LAUNCH THE SCANNER FROM ANYWHERE BY TYPING ANY OF THESE:\033[0m"
echo -e "\033[1;36m  R@t\033[0m"
echo -e "\033[1;36m  R@tscan\033[0m"
echo -e "\033[1;36m  RSTzscan\033[0m"
echo -e "\033[1;33m[!] Restart Termux or run: source ~/.bashrc\033[0m"
echo -e "\033[1;33m[!!] Press ENTER to continue...\033[0m"
read
