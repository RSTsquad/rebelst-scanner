# =========================================================
#  SCANNING ENGINES
# =========================================================

ANIM_FRAMES=("R@ - - -" "- R@ - -" "- - R@ -" "- - - R@")
ANIM_COLOURS=("$YELLOW" "$CYAN" "$CYAN" "$YELLOW")
ANIM_LEN=${#ANIM_FRAMES[@]}

clear_line() { printf "\r\033[K"; }

# ─── Fmt helper: 00h:00m:00s ─────────────────────────────
fmt_time() {
    local t=$1
    printf "%02dh:%02dm:%02ds" $((t/3600)) $(((t%3600)/60)) $((t%60))
}

check_host_zero() {
    local host="$1" timeout="$2" dns_mode="$3" scan_mode="$4"
    local code="000"
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

# ─── Shizuku Airplane-cycle with REAL deadlock test ──────
shizuku_airplane_cycle() {
    # Real check: is the network ACTUALLY down right now?
    local test=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "https://www.google.com/generate_204" 2>/dev/null)
    if [ "$test" != "000" ]; then
        # Network is alive — no deadlock, skip recovery
        return 0
    fi
    echo "${RED}[!] DEADLOCK DETECTED. EXECUTING AUTO-RECOVERY...${NC}"
    echo "${AQUA}[:.] SHIZUKU TOGGLED NETWORK. HANDSHAKING WITH CELL TOWER...${NC}"
    cmd connectivity airplane-mode enable 2>/dev/null
    sleep 3
    cmd connectivity airplane-mode disable 2>/dev/null
    sleep 4
    echo "${AQUA}[:.] NETWORK HANDSHAKE COMPLETE. VERIFYING INTEGRITY...${NC}"
    # Verify it's really back
    local tries=0
    while [ $tries -lt 6 ]; do
        test=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "https://www.google.com/generate_204" 2>/dev/null)
        [ "$test" != "000" ] && break
        sleep 3
        tries=$((tries+1))
    done
    echo "${GREEN}[+] NETWORK VERIFIED. RESUMING MATRIX SCAN...${NC}"
}

handle_interrupt() {
    echo ""
    echo "${RED}[!] INTERRUPT DETECTED (Kill Switch Confirmed)${NC}"
    echo "${YELLOW}[?] Action: [P]ause session, [R]esume Scan, [E]xit & Save, or [S]top Entirely?${NC}"
    prompt_rat
    read intr_choice
    case "$intr_choice" in
        e|E)
            echo ""
            echo "${YELLOW}[!] Preserving Matrix State to Vault. Preparing Safe Exit...${NC}"
            sleep 1
            local state_file=$(save_scan_state)
            echo "${GREEN}[*] Vault saved successfully: $state_file${NC}"
            show_next_prompt
            return 1
            ;;
        p|P) echo "${YELLOW}[!] Session paused. Press CTRL+C again to exit.${NC}"; sleep 3; return 0 ;;
        s|S) echo "${RED}[!] Stopping without saving.${NC}"; exit 0 ;;
        *) return 0 ;;
    esac
}

show_full_summary() {
    local duration="$1" total="$2" zr="$3" bug="$4" blk="$5" bil="$6" pshd="$7" carrier="$8" target="$9" dns="${10}" logfile="${11}" zrfile="${12}" bugfile="${13}" blkfile="${14}"
    echo ""
    echo "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${MAGENTA}║              ${YELLOW}R•S•T ZERO-RATED SCANNER COMPLETE✓${MAGENTA}                   ║${NC}"
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
        batch_idx=$((batch_idx + 1))
        local batch_hosts=$(cat "$batch_file" | grep -v '^$')
        [ -z "$batch_hosts" ] && continue
        local batch_size=$(echo "$batch_hosts" | wc -l)
        local results=()
        local batch_done=0

        local tmp_res="$tmp_dir/tmp_res.txt"
        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c 'r=$(check_host_zero "{}" "$TIMEOUT" "$DNS_MODE" "$SCAN_MODE"); printf "%s %s\n" "$r" "{}"' > "$tmp_res" 2>/dev/null

        while IFS=' ' read -r result host || [ -n "$host" ]; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            batch_done=$((batch_done + 1))
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local fcol="${ANIM_COLOURS[anim_pos]}"
            local esec=$(( $(date +%s) - start_time ))
            local estr=$(fmt_time $esec)
            local etastr="Calculating..."
            local eta_basis=$((total_scanned + batch_done))
            if [ $eta_basis -gt 5 ] && [ $esec -gt 5 ]; then
                local eta=$(( (TOTAL - eta_basis) * esec / eta_basis ))
                etastr=$(fmt_time $eta)
            fi
            clear_line
            printf "${fcol}[%s]${NC} ⚡ %d/%d (⚙️) | %02d/%d 🌐 | ${GREEN}🟢 0Rated: $zero_rated${NC} | ${RED}🔥 Bugs: $bugs${NC}" \
                "$frame" "$batch_done" "$batch_size" "$total_scanned" "$TOTAL"
            printf "\n⏱️Elapsed: %s | ⏳ ETA: %s | 👻 Pshd: $pshd" "$estr" "$etastr"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        # WATCHDOG
        echo ""
        printf "${YELLOW}[..] WATCHDOG: Verifying Batch $batch_idx Integrity...${NC}"
        sleep 1
        printf "\r\033[K"

        # Scroll results (arrows NOT colored)
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            local host="${entry##*|}"
            local code="${st#*|}"
            st="${st%|*}"
            case "$st" in
                ZERO_RATED) echo "${GREEN}✅ ZERO-RATED${NC} ➜ ↓↓"; echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                BILLED)     echo "${RED}🚫 BILLED${NC} ➜ ↓↓";     echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                BUG)        echo "${RED}🔥 HIDDEN-BUG${NC} ➜ ↓↓"; echo "${WHITE}$host (HTTP:$code)${NC}" ;;
                *)          echo "${RED}❌ BLOCKED${NC} ➜ ↓↓";   echo "${WHITE}$host (HTTP:$code)${NC}" ;;
            esac
            echo "$st $host" >> "$detail_log"
            echo "[$st] $host" >> "$full_log"
        done

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
            # Mode 1: no wait at all
        fi
    done

    trap - INT
    rm -rf "$tmp_dir"

    local esec=$(( $(date +%s) - start_time ))
    local dstr=$(fmt_time $esec)

    local dstr2=$(date +%Y%m%d)
    local rnd=$(printf "%04d" $((RANDOM % 10000)))
    local sc2=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tp="nn"; [ -n "$TAG" ] && tp="$TAG"

    local bn="0rtdscan"
    local logfile="$WORK_DIR/${bn}_fullogs_${sc2}_${tp}_${dstr2}_${rnd}.txt"
    local zrfile="$WORK_DIR/${bn}_0list_${sc2}_${tp}_${dstr2}_${rnd}.txt"
    local bugfile="$WORK_DIR/${bn}_bugslist_${sc2}_${tp}_${dstr2}_${rnd}.txt"
    local blkfile="$WORK_DIR/${bn}_blocked_${sc2}_${tp}_${dstr2}_${rnd}.txt"

    cp "$full_log" "$logfile" 2>/dev/null
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
            local esec=$(( $(date +%s) - start_time ))
            local estr=$(fmt_time $esec)
            local etastr="Calculating..."
            local eta_basis=$((total_done + batch_done))
            if [ $eta_basis -gt 5 ] && [ $esec -gt 5 ]; then
                local eta=$(( (TOTAL - eta_basis) * esec / eta_basis ))
                etastr=$(fmt_time $eta)
            fi
            clear_line
            printf "${fcol}[%s]${NC} ⚡ %d/%d (⚙️) | %02d/%d 🌐 | ${GREEN}🟢 LIVE: $live${NC} | ${RED}❌ DEAD: $dead${NC}" \
                "$frame" "$batch_done" "$batch_size" "$total_done" "$TOTAL"
            printf "\n⏱️Elapsed: %s | ⏳ ETA: %s | 👻 Pshd: 0" "$estr" "$etastr"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        echo ""
        printf "${YELLOW}[..] WATCHDOG: Verifying Batch $batch_idx Integrity...${NC}"
        sleep 1
        printf "\r\033[K"

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

    local esec=$(( $(date +%s) - start_time ))
    local dstr=$(fmt_time $esec)

    echo ""
    echo "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║             ${YELLOW}R•S•T ACTIVE SCAN COMPLETE✓${GREEN}                       ║${NC}"
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
