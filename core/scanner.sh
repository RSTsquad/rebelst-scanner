# =========================================================
#  SCANNING ENGINES
# =========================================================

ANIM_FRAMES=("R@ - - -" "- R@ - -" "- - R@ -" "- - - R@")
ANIM_COLOURS=("$YELLOW" "$CYAN" "$CYAN" "$YELLOW")
ANIM_LEN=${#ANIM_FRAMES[@]}

clear_line() { printf "\r\033[K"; }

check_host_zero() {
    local host="$1" timeout="$2" dns_mode="$3" scan_mode="$4"
    local code="000"
    # Anti-FUP modes = faster (2s less timeout)
    local eff_timeout=$timeout
    [ "$scan_mode" = "2" ] && eff_timeout=$(( timeout > 3 ? timeout - 2 : timeout ))
    [ "$scan_mode" = "4" ] && eff_timeout=$(( timeout > 3 ? timeout - 2 : timeout ))
    if [ "$scan_mode" = "1" ] || [ "$scan_mode" = "2" ]; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$eff_timeout" --max-time "$eff_timeout" "https://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && code="$http_code"
        if [ "$code" != "000" ]; then
            if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then echo "ZERO_RATED|$code"; return
            elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then echo "BILLED|$code"; return
            elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then echo "BUG|$code"; return
            else echo "BLOCKED|$code"; return; fi
        fi
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$eff_timeout" --max-time "$eff_timeout" "http://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && code="$http_code"
        if [ "$code" != "000" ]; then
            if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then echo "ZERO_RATED|$code"; return
            elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then echo "BILLED|$code"; return
            elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then echo "BUG|$code"; return
            else echo "BLOCKED|$code"; return; fi
        fi
        echo "BLOCKED|000"; return
    fi
    local ip=$(resolve_host "$host" "$dns_mode")
    [ -z "$ip" ] && { echo "BLOCKED|000"; return; }
    for proto in https http; do
        local port=443; [ "$proto" = "http" ] && port=80
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$eff_timeout" --max-time "$eff_timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done
    if [ "$code" != "000" ]; then
        if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then echo "ZERO_RATED|$code"
        elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then echo "BILLED|$code"
        elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then echo "BUG|$code"
        else echo "BLOCKED|$code"; fi
    else echo "BLOCKED|000"; fi
}

check_host_active() {
    local host="$1" timeout="$2" dns_mode="$3"
    local code="000"
    local ip=$(resolve_host "$host" "$dns_mode")
    [ -z "$ip" ] && { echo "DEAD"; return; }
    for proto in https http; do
        local port=443; [ "$proto" = "http" ] && port=80
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done
    if [ "$code" != "000" ] && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then echo "LIVE|$code"; else echo "DEAD"; fi
}

# ─── Shizuku Airplane Mode Recovery ──────────────────────
shizuku_airplane_cycle() {
    echo "${RED}[!] DEADLOCK DETECTED. EXECUTING AUTO-RECOVERY...${NC}"
    echo "${AQUA}[:.] SHIZUKU TOGGLED NETWORK. HANDSHAKING WITH CELL TOWER...${NC}"
    termux-wifi-connectioninfo >/dev/null 2>&1
    # Try via termux-api (Shizuku-like behaviour via Termux:API)
    cmd connectivity airplane-mode enable 2>/dev/null
    sleep 3
    cmd connectivity airplane-mode disable 2>/dev/null
    sleep 3
    echo "${AQUA}[:.] NETWORK HANDSHAKE COMPLETE. VERIFYING INTEGRITY...${NC}"
    sleep 2
    echo "${GREEN}[+] NETWORK VERIFIED. RESUMING MATRIX SCAN...${NC}"
}

# ─── Handler for CTRL+C (interrupt) ──────────────────────
handle_interrupt() {
    echo ""
    echo "${RED}[!] INTERRUPT DETECTED (Kill Switch Confirmed)${NC}"
    echo "${YELLOW}[?] Action: [P]ause session, [R]esume Scan, [E]xit & Save, or [S]top Entirely?${NC}"
    printf "${YELLOW}[?] (P/R/E/S): ${NC}"
    read intr_choice
    case "$intr_choice" in
        e|E)
            echo ""
            echo "${YELLOW}[!] Preserving Matrix State to Vault. Preparing Safe Exit...${NC}"
            # Balance the current batch
            sleep 1
            local state_file=$(save_scan_state)
            echo "${GREEN}[*] Vault saved successfully: $state_file${NC}"
            show_partial_summary
            show_next_prompt
            return 1
            ;;
        p|P)
            echo "${YELLOW}[!] Session paused. Press CTRL+C again to exit.${NC}"
            sleep 3
            return 0
            ;;
        s|S)
            echo "${RED}[!] Stopping without saving.${NC}"
            exit 0
            ;;
        *)
            return 0
            ;;
    esac
}

# ─── Full completion summary ─────────────────────────────
show_full_summary() {
    local duration="$1" total="$2" zr="$3" bug="$4" blk="$5" bil="$6" pshd="$7" carrier="$8" target="$9" dns="${10}" logfile="${11}" zrfile="${12}" bugfile="${13}" blkfile="${14}"
    echo ""
    echo "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${MAGENTA}║              ${YELLOW}R•S•T ZERO-RATED SCANNER COMPLETE✓${NC}                   ${MAGENTA}║${NC}"
    echo "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo "${AQUA}Network Carrier   : $carrier${NC}"
    echo "${AQUA}Target List       : $target${NC}"
    echo "${AQUA}DNS Cascade       : $dns${NC}"
    echo "${AQUA}Scan Duration     : $duration${NC}"
    echo "${AQUA}Total Scanned     : $total${NC}"
    echo "${GREEN}Zero-Rated Found  : $zr 🟢${NC}"
    echo "${RED}Hidden Bugs       : $bug 🔥${NC}"
    echo "${RED}Blocked/Unknown   : $blk ❌${NC}"
    echo "${RED}Billed/Redirect   : $bil 🚫${NC}"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${AQUA}[!] Log Saved To:${NC} $logfile"
    echo "${GREEN}[!] Clean Zero-Rated List Saved To:${NC} $zrfile"
    echo "${RED}[!] Clean Hidden-Bugs List Saved To:${NC} $bugfile"
    echo "${RED}[!] Evidence Ledger Saved To:${NC} $blkfile"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    printf "${PURPLE}[Press Enter to return to Hub...]${NC}"
    read
}

show_partial_summary() {
    local duration="$1" total="$2" zr="$3" bug="$4" blk="$5" bil="$6" carrier="$7" target="$8" dns="${9}" logfile="${10}" zrfile="${11}" bugfile="${12}" blkfile="${13}"
    echo ""
    echo "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║          R•S•T PARTIAL SCAN SAVED SUCCESSFULLY✓${NC}                   ${GREEN}║${NC}"
    echo "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo "${AQUA}Network Carrier   : $carrier${NC}"
    echo "${AQUA}Target List       : $target${NC}"
    echo "${AQUA}DNS Cascade       : $dns${NC}"
    echo "${AQUA}Scan Duration     : $duration${NC}"
    echo "${AQUA}Total Scanned     : $total${NC}"
    echo "${GREEN}Zero-Rated Found  : $zr 🟢${NC}"
    echo "${GREEN}Hidden Bugs       : $bug 🔥${NC}"
    echo "${RED}Blocked/Unknown   : $blk ❌${NC}"
    echo "${RED}Billed/Redirect   : $bil 🚫${NC}"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${AQUA}[!] Log Saved To:${NC} $logfile"
    echo "${GREEN}[!] Clean Zero-Rated List Saved To:${NC} $zrfile"
    echo "${RED}[!] Clean Hidden-Bugs List Saved To:${NC} $bugfile"
    echo "${RED}[!] Evidence Ledger Saved To:${NC} $blkfile"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ─── Zero-Rated Engine ───────────────────────────────────
run_scan_zero() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    local TARGET_FILE="$1" TOTAL="$2" TIMEOUT="$3" BATCH="$4"
    local CARRIER="$5" WORK_DIR="$6" TAG="$7" THREADS="$8" DEADLOCK_MODE="$9"
    shift 9
    local START_POS="$1" INIT_ZR="$2" INIT_BLK="$3" INIT_BIL="$4"
    local DNS_MODE="$5" BATCH_ENABLED="$6" SCAN_MODE="$7"

    zero_rated=$INIT_ZR; blocked=$INIT_BLK; billed=$INIT_BIL; bugs=0; pshd=0
    local total_scanned=$START_POS
    local start_time
    if [ -n "$RESUME_ELAPSED" ] && [ "$RESUME_ELAPSED" -gt 0 ] 2>/dev/null; then
        start_time=$(( $(date +%s) - RESUME_ELAPSED ))
    else
        start_time=$(date +%s)
    fi
    local anim_pos=0

    local detail_log="$RAT_LOGS/last_scan_detail.log"
    local full_log="$RAT_LOGS/last_scan.log"
    [ "$START_POS" -eq 0 ] && { > "$detail_log"; > "$full_log"; }

    export -f check_host_zero resolve_host
    export TIMEOUT DNS_MODE SCAN_MODE THREADS TOTAL detail_log full_log

    local PAUSED=0
    trap 'handle_interrupt; [ $? -eq 1 ] && return' INT

    echo ""
    echo "${AQUA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}Scanning in progress...🚀 ${NC}"
    echo "${YELLOW}!]To pause or stop long press CTRL + C(or tap 6times)${NC}"
    echo "${AQUA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    rm -rf "$tmp_dir"; mkdir -p "$tmp_dir"

    local scan_source="$TARGET_FILE"
    if [ "$START_POS" -gt 0 ]; then
        tail -n +$((START_POS + 1)) "$TARGET_FILE" > "$tmp_dir/resume_hosts.txt"
        scan_source="$tmp_dir/resume_hosts.txt"
    fi

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ]; then
        batches=("$scan_source")
    else
        split -l "$BATCH" "$scan_source" "$tmp_dir/batch_"
        for f in "$tmp_dir"/batch_*; do [ -f "$f" ] && batches+=("$f"); done
    fi

    local num_batches=${#batches[@]}
    local batch_idx=0

    for batch_file in "${batches[@]}"; do
        [ $PAUSED -eq 1 ] && break
        batch_idx=$((batch_idx + 1))
        local batch_hosts=$(cat "$batch_file" | grep -v '^$')
        [ -z "$batch_hosts" ] && continue
        local batch_size=$(echo "$batch_hosts" | wc -l)
        local results=()
        local batch_done=0

        local tmp_res="$tmp_dir/tmp_res.txt"
        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c 'r=$(check_host_zero "{}" "$TIMEOUT" "$DNS_MODE" "$SCAN_MODE"); printf "%s %s\n" "$r" "{}"' > "$tmp_res" 2>/dev/null

        # PHASE 1: count batch (counters frozen)
        while IFS=' ' read -r result host || [ -n "$host" ]; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            batch_done=$((batch_done + 1))
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local fcol="${ANIM_COLOURS[anim_pos]}"
            local elapsed_sec=$(( $(date +%s) - start_time ))
            local em=$((elapsed_sec / 60)); local er=$((elapsed_sec % 60))
            local estr=$(printf "%02dm:%02ds" $em $er)
            local etastr="Calculating..."
            local eta_basis=$((total_scanned + batch_done))
            if [ $eta_basis -gt 5 ] && [ $elapsed_sec -gt 5 ]; then
                local eta=$(( (TOTAL - eta_basis) * elapsed_sec / eta_basis ))
                local etm=$((eta / 60)); local etr=$((eta % 60))
                etastr=$(printf "%02dm:%02ds" $etm $etr)
            fi
            clear_line
            printf "${fcol}[%s]${NC} ⚡ %d/%d (⚙️) | %02d/%d 🌐 | ${GREEN}🟢 0Rated: $zero_rated${NC} | ${RED}🔥 Bugs: $bugs${NC}" \
                "$frame" "$batch_done" "$batch_size" "$total_scanned" "$TOTAL"
            printf "\n⏱️Elapsed: %s | ⏳ ETA: %s | 👻 Pshd: $pshd" "$estr" "$etastr"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        # PHASE 2: scroll results
        clear_line
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            local host="${entry##*|}"
            local code="${st#*|}"
            st="${st%|*}"
            case "$st" in
                ZERO_RATED) echo "${GREEN}✅ ZERO-RATED ➜ ↓↓${NC}"; echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                BILLED)     echo "${RED}🚫 BILLED ➜ ↓↓${NC}";     echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                BUG)        echo "${RED}🔥 HIDDEN-BUG ➜ ↓↓${NC}"; echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                *)          echo "${RED}❌ BLOCKED ➜ ↓↓${NC}";   echo "${WHITE}$host (HTTP:$code)${NC}" ;;
            esac
            echo "$st $host" >> "$detail_log"
            echo "[$st] $host" >> "$full_log"
        done

        # Update counters
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            st="${st%|*}"
            case "$st" in
                ZERO_RATED) zero_rated=$((zero_rated+1)) ;;
                BILLED)     billed=$((billed+1)) ;;
                BUG)        bugs=$((bugs+1)) ;;
                *)          blocked=$((blocked+1)) ;;
            esac
        done
        total_scanned=$((total_scanned + batch_size))
        [ "$BATCH_ENABLED" != "n" ] && rm -f "$batch_file"

        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$is_last" != "yes" ]; then
            if [ "$DEADLOCK_MODE" = "2" ]; then
                if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                    echo "${RED}[!] Network down. Waiting to heal...${NC}"
                    while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do sleep 2; done
                    echo "${GREEN}[+] Network back.${NC}"
                fi
            elif [ "$DEADLOCK_MODE" = "3" ]; then
                shizuku_airplane_cycle
            fi
        fi
    done

    trap - INT
    rm -rf "$tmp_dir"

    local end_time=$(date +%s)
    local dsec=$((end_time - start_time))
    local dstr=$(printf "%02dh:%02dm:%02ds" $((dsec/3600)) $(((dsec%3600)/60)) $((dsec%60)))

    local dstr2=$(date +%Y%m%d_%H%M)
    local sc2=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tp=""; [ -n "$TAG" ] && tp="_$TAG"
    local bn="0rtdscan_${sc2}_nn_${dstr2}${tp}"

    cp "$full_log" "$WORK_DIR/${bn}_fullogs.txt" 2>/dev/null
    local logfile="$WORK_DIR/${bn}_fullogs.txt"
    local zrfile="$WORK_DIR/0rtdscan_0list_${sc2}_nn_${dstr2}${tp}.txt"
    local bugfile="$WORK_DIR/0rtdscan_bugslist_${sc2}_nn_${dstr2}${tp}.txt"
    local blkfile="$WORK_DIR/0rtdscan_blocked_${sc2}_nn_${dstr2}${tp}.txt"
    [ $zero_rated -gt 0 ] && grep "^ZERO_RATED" "$detail_log" | awk '{print $2}' > "$zrfile"
    [ $bugs -gt 0 ] && grep "^BUG" "$detail_log" | awk '{print $2}' > "$bugfile"
    grep "^BLOCKED\|^BILLED" "$detail_log" | awk '{print $2}' > "$blkfile"

    show_full_summary "$dstr" "$total_scanned/$TOTAL" "$zero_rated" "$bugs" "$blocked" "$billed" "$pshd" "$CARRIER" "$(basename "$TARGET_FILE")" "$DNS_MODE" "$logfile" "$zrfile" "$bugfile" "$blkfile"
    show_next_prompt
}

# ─── Active Engine ───────────────────────────────────────
run_scan_active() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    local TARGET_FILE="$1" TOTAL="$2" TIMEOUT="$3" BATCH="$4"
    local CARRIER="$5" WORK_DIR="$6" TAG="$7" THREADS="$8" DEADLOCK_MODE="$9"
    shift 9
    local DNS_MODE="$1" BATCH_ENABLED="$2" SCAN_MODE="$3"

    live=0; dead=0
    local total_done=0
    local start_time=$(date +%s)
    local anim_pos=0
    local detail_log="$RAT_LOGS/last_scan_active_detail.log"
    local full_log="$RAT_LOGS/last_scan_active.log"
    > "$detail_log"; > "$full_log"

    export -f check_host_active resolve_host
    export TIMEOUT DNS_MODE THREADS TOTAL detail_log full_log

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "${YELLOW}[!] Saving state...${NC}"; STATE_FILE=$(save_scan_state); echo "${GREEN}[+] Saved: $STATE_FILE${NC}"; show_next_prompt; return' INT TERM

    echo ""
    echo "${AQUA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}Scanning in progress (ACTIVE MODE)...🚀${NC}"
    echo "${AQUA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    rm -rf "$tmp_dir"; mkdir -p "$tmp_dir"

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ]; then
        batches=("$TARGET_FILE")
    else
        split -l "$BATCH" "$TARGET_FILE" "$tmp_dir/batch_"
        for f in "$tmp_dir"/batch_*; do [ -f "$f" ] && batches+=("$f"); done
    fi

    local num_batches=${#batches[@]}
    local batch_idx=0

    for batch_file in "${batches[@]}"; do
        [ $PAUSED -eq 1 ] && break
        batch_idx=$((batch_idx + 1))
        local batch_hosts=$(cat "$batch_file" | grep -v '^$')
        [ -z "$batch_hosts" ] && continue
        local batch_size=$(echo "$batch_hosts" | wc -l)
        local results=()
        local batch_done=0

        local tmp_res="$tmp_dir/tmp_res.txt"
        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c 'r=$(check_host_active "{}" "$TIMEOUT" "$DNS_MODE"); printf "%s %s\n" "$r" "{}"' > "$tmp_res" 2>/dev/null

        while IFS=' ' read -r result host || [ -n "$host" ]; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            batch_done=$((batch_done + 1))
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local fcol="${ANIM_COLOURS[anim_pos]}"
            local elapsed_sec=$(( $(date +%s) - start_time ))
            local estr=$(printf "%02dm:%02ds" $((elapsed_sec / 60)) $((elapsed_sec % 60)))
            local etastr="Calculating..."
            local eta_basis=$((total_done + batch_done))
            if [ $eta_basis -gt 5 ] && [ $elapsed_sec -gt 5 ]; then
                local eta=$(( (TOTAL - eta_basis) * elapsed_sec / eta_basis ))
                etastr=$(printf "%02dm:%02ds" $((eta / 60)) $((eta % 60)))
            fi
            clear_line
            printf "${fcol}[%s]${NC} ⚡ %d/%d (⚙️) | %02d/%d 🌐 | ${GREEN}🟢 LIVE: $live${NC} | ${RED}❌ DEAD: $dead${NC}" \
                "$frame" "$batch_done" "$batch_size" "$total_done" "$TOTAL"
            printf "\n⏱️Elapsed: %s | ⏳ ETA: %s | 👻 Pshd: 0" "$estr" "$etastr"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        clear_line
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            local host="${entry##*|}"
            local code="${st#*|}"
            st="${st%|*}"
            if [ "$st" = "LIVE" ]; then
                echo "${GREEN}$host -> LIVE (HTTP:$code)${NC}"
                echo "LIVE $host" >> "$detail_log"; echo "[LIVE] $host" >> "$full_log"
            else
                echo "${RED}$host -> DEAD${NC}"
                echo "DEAD $host" >> "$detail_log"; echo "[DEAD] $host" >> "$full_log"
            fi
        done

        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            st="${st%|*}"
            [ "$st" = "LIVE" ] && live=$((live+1)) || dead=$((dead+1))
        done
        total_done=$((total_done + batch_size))
        [ "$BATCH_ENABLED" != "n" ] && rm -f "$batch_file"

        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$is_last" != "yes" ]; then
            if [ "$DEADLOCK_MODE" = "2" ]; then
                if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                    echo "${RED}[!] Network down. Waiting...${NC}"
                    while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do sleep 2; done
                    echo "${GREEN}[+] Network back.${NC}"
                fi
            elif [ "$DEADLOCK_MODE" = "3" ]; then
                shizuku_airplane_cycle
            fi
        fi
    done

    trap - INT TERM
    rm -rf "$tmp_dir"

    local dsec=$(( $(date +%s) - start_time ))
    local dstr=$(printf "%02dh:%02dm:%02ds" $((dsec/3600)) $(((dsec%3600)/60)) $((dsec%60)))

    echo ""
    echo "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║             R•S•T ACTIVE SCAN COMPLETE✓${NC}                       ${GREEN}║${NC}"
    echo "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo "${AQUA}Network Carrier : $CARRIER${NC}"
    echo "${AQUA}Scan Duration   : $dstr${NC}"
    echo "${AQUA}Total Scanned   : $total_done / $TOTAL${NC}"
    echo "${GREEN}🟢 LIVE         : $live${NC}"
    echo "${RED}❌ DEAD         : $dead${NC}"
    echo ""
    printf "${PURPLE}[Press Enter to return to Hub...]${NC}"
    read
    show_next_prompt
}
