#!/bin/bash
# =========================================================
#  R@t Scanner – One‑Click Installer
# =========================================================

REPO="https://raw.githubusercontent.com/RSTsquad/rebelst-scanner/main"

echo -e "\033[1;36m[+] Installing R@t Scanner...\033[0m"
mkdir -p ~/R@t/core
cd ~/R@t

for file in rat.sh core/config.sh core/utils.sh core/ui.sh core/login.sh core/scanner.sh; do
    echo -e "\033[1;33m[+] Downloading $file...\033[0m"
    # Create subdirectory if needed
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
echo -e "\033[1;36m[+] You can now run: R@t\033[0m"
echo -e "\033[1;33m[!] Restart Termux or run: source ~/.bashrc\033[0m"
echo -e "\033[1;33m[!!] Press ENTER to continue...\033[0m"
read
