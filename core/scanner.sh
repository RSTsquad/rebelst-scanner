# =========================================================
#  SCANNING ENGINES – CLEAN PROGRESS BAR
# =========================================================

# ─── Animation Frames ─────────────────────────────────────
ANIM_FRAMES=("-R@-------" "--R@------" "---R@-----" "----R@----" "-----R@---" "------R@--" "-------R@-" "--------R@" "-------R@-" "------R@--" "-----R@---" "----R@----" "---R@-----" "--R@------" "-R@-------")
ANIM_LEN=${#ANIM_FRAMES[@]}

# ─── Helpers ──────────────────────────────────────────────
clear_line() { printf "\r\033[K"; }

# ─── Check Functions ──────────────────────────────────────

# Zero‑rated check (returns category|code)
check_host_zero() {
    local host="$1"
    local timeout="$2"
    local dns_mode="$3"
    local scan_mode="$4"
    local code="000"

    if [ "$scan_mode" = "1" ] || [ "$scan_mode" = "2" ]; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" "https://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && code="$http_code"
        if [ "$code" != "000" ]; then
            if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then
                echo "ZERO_RATED|$code"; return
            elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then
                echo "BILLED|$code"; return
            elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then
                echo "BUG|$code"; return
            else
                echo "BLOCKED|$code"; return
            fi
        fi
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" "http://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && code="$http_code"
        if [ "$code" != "000" ]; then
            if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then
                echo "ZERO_RATED|$code"; return
            elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then
                echo "BILLED|$code"; return
            elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then
                echo "BUG|$code"; return
            else
                echo "BLOCKED|$code"; return
            fi
        fi
        echo "BLOCKED|000"; return
    fi

    local ip
    ip=$(resolve_host "$host" "$dns_mode")
    [ -z "$ip" ] && { echo "BLOCKED|000"; return; }

    for proto in https http; do
        local port=443
        [ "$proto" = "http" ] && port=80
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done

    if [ "$code" != "000" ]; then
        if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then
            echo "ZERO_RATED|$code"
        elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then
            echo "BILLED|$code"
        elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then
            echo "BUG|$code"
        else
            echo "BLOCKED|$code"
        fi
    else
        echo "BLOCKED|000"
    fi
}

# Active check (returns LIVE|code or DEAD)
check_host_active() {
    local host="$1"
    local timeout="$2"
    local dns_mode="$3"
    local code="000"
    local ip
    ip=$(resolve_host "$host" "$dns_mode")
    [ -z "$ip" ] && { echo "DEAD"; return; }

    for proto in https http; do
        local port=443
        [ "$proto" = "http" ] && port=80
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done

    if [ "$code" != "000" ] && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
        echo "LIVE|$code"
    else
        echo "DEAD"
    fi
}

# ─── Zero‑Rated Engine ────────────────────────────────────
run_scan_zero() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"

    local TARGET_FILE="$1"
    local TOTAL="$2"
    local TIMEOUT="$3"
    local BATCH="$4"
    local CARRIER="$5"
    local WORK_DIR="$6"
    local TAG="$7"
    local THREADS="$8"
    local DEADLOCK_MODE="$9"
    shift 9
    local START_POS="$1"
    local INIT_ZR="$2"
    local INIT_BLK="$3"
    local INIT_BIL="$4"
    local DNS_MODE="$5"
    local BATCH_ENABLED="$6"
    local SCAN_MODE="$7"

    zero_rated=$INIT_ZR
    blocked=$INIT_BLK
    billed=$INIT_BIL
    bugs=0
    local total_scanned=$START_POS
    local start_time
    start_time=$(date +%s)
    local anim_pos=0

    local detail_log="$RAT_LOGS/last_scan_detail.log"
    local full_log="$RAT_LOGS/last_scan.log"
    [ "$START_POS" -eq 0 ] && { > "$detail_log"; > "$full_log"; }

    export -f check_host_zero
    export -f resolve_host
    export TIMEOUT
    export DNS_MODE
    export SCAN_MODE
    export THREADS
    export TOTAL
    export detail_log
    export full_log

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "$YELLOW [!] Scan paused by user/signal. Saving state...$NC"; STATE_FILE=$(save_scan_state); echo "$GREEN [+] State saved to $STATE_FILE.$NC"; show_next_prompt; return' INT TERM

    echo ""
    echo "$CYAN ╔═══════════════════════════════════════════════════════╗$NC"
    echo "$CYAN ║           Scanning in progress...🚀                   ║$NC"
    echo "$CYAN ║ [!] To pause: press CTRL+C                            ║$NC"
    echo "$CYAN ╚═══════════════════════════════════════════════════════╝$NC"
    echo ""

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    mkdir -p "$tmp_dir"

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ] || [ "$BATCH_ENABLED" = "N" ]; then
        batches=("$TARGET_FILE")
    else
        split -l "$BATCH" "$TARGET_FILE" "$tmp_dir/batch_"
        for f in "$tmp_dir"/batch_*; do
            [ -f "$f" ] && batches+=("$f")
        done
    fi

    local num_batches=${#batches[@]}
    local batch_idx=0
    local total_done=0
    local current_batch_size=0

    for batch_file in "${batches[@]}"; do
        [ $PAUSED -eq 1 ] && break
        batch_idx=$((batch_idx + 1))
        local batch_hosts
        batch_hosts=$(cat "$batch_file" | grep -v '^$')
        [ -z "$batch_hosts" ] && continue
        local batch_size=$(echo "$batch_hosts" | wc -l)
        current_batch_size=$batch_size
        local results=()
        local batch_done=0

        # Phase 1: test the whole batch, update progress bar (counters stay at current accumulated values)
        local tmp_res="$RAT_CONFIG/tmp_batch_res"
        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c 'r=$(check_host_zero "{}" "$TIMEOUT" "$DNS_MODE" "$SCAN_MODE"); echo "$r {}"' > "$tmp_res" 2>/dev/null

        while IFS=' ' read -r result host; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            batch_done=$((batch_done + 1))
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            # Build progress bar with cyan R@ and plain dashes
            local bar="[ ${CYAN}R@${NC}${frame//R@/} ]"  # Remove the R@ from frame and put coloured R@
            # Actually frame has R@ in it; we'll replace it with cyan R@
            local bar_display="[ ${CYAN}R@${NC}${frame#R@} ]"
            local elapsed_sec=$(( $(date +%s) - start_time ))
            local elapsed_min=$((elapsed_sec / 60))
            local elapsed_sec_rem=$((elapsed_sec % 60))
            local elapsed_str=$(printf "%02dm:%02ds" $elapsed_min $elapsed_sec_rem)
            local eta_str="Calculating..."
            if [ $total_done -gt 0 ] && [ $elapsed_sec -gt 5 ]; then
                local eta_sec=$(( (TOTAL - total_done) * elapsed_sec / total_done ))
                local eta_min=$((eta_sec / 60))
                local eta_sec_rem=$((eta_sec % 60))
                eta_str=$(printf "%02dm:%02ds" $eta_min $eta_sec_rem)
            fi
            clear_line
            printf "%s $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 0Rated:$zero_rated$NC | $RED🔥Bugs:$bugs$NC" \
                "$bar_display" "$batch_done" "$batch_size" "$total_done" "$TOTAL"
            printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$elapsed_str" "$eta_str"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        # Phase 2: clear progress bar and reveal results crawl-style
        clear_line
        printf "\n"
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            local host="${entry##*|}"
            local code="${st#*|}"
            st="${st%|*}"
            case "$st" in
                ZERO_RATED) status_colour="$GREEN" ;;
                BILLED)     status_colour="$RED" ;;
                BUG)        status_colour="$RED" ;;
                *)          status_colour="$RED" ;;
            esac
            echo "$WHITE$host $NC-> $status_colour$st $NC(HTTP:$WHITE$code$NC)"
            echo ""
            echo "$st $host" >> "$detail_log"
            echo "[$st] $host" >> "$full_log"
            sleep 0.02
        done

        # Update counters after results are printed
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
        total_done=$((total_done + batch_size))

        if [ "$BATCH_ENABLED" != "n" ] && [ "$BATCH_ENABLED" != "N" ]; then
            rm -f "$batch_file"
        fi

        # Deadlock recovery
        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$DEADLOCK_MODE" = "2" ]; then
            if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                echo "$RED[!] Network down. Waiting to auto-heal...$NC"
                while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do
                    sleep 5
                done
                echo "$GREEN[+] Network back.$NC"
            fi
        elif [ "$DEADLOCK_MODE" = "3" ]; then
            [ "$is_last" != "yes" ] && sleep 10
        elif [ "$DEADLOCK_MODE" = "4" ]; then
            [ "$is_last" != "yes" ] && sleep 4
        fi
    done

    trap - INT TERM
    local end_time
    end_time=$(date +%s)
    local duration_sec=$((end_time - start_time))
    local dur_h=$((duration_sec / 3600))
    local dur_m=$(((duration_sec % 3600) / 60))
    local dur_s=$((duration_sec % 60))
    local duration_str=$(printf "%02dh:%02dm:%02ds" $dur_h $dur_m $dur_s)

    echo ""
    echo "$CYAN ╔═════════════════════════════════════════════════════════════╗$NC"
    echo "$GREEN║ SCAN COMPLETED SUCCESSFULLY                                 ║$NC"
    echo "$CYAN ╠═════════════════════════════════════════════════════════════╣$NC"
    echo "  NETWORK CARRIER     : $CARRIER"
    echo "  TARGET LIST         : $(basename "$TARGET_FILE")"
    echo "  DNS CASCADE         : $DNS_MODE"
    echo "  SCAN DURATION       : $duration_str"
    echo "  TOTAL SCANNED       : $total_done / $TOTAL"
    echo "  ZERO-RATED FOUND    : $zero_rated🟢"
    echo "  HIDDEN BUGS         : $bugs🔥"
    echo "  BLOCKED/UNKNOWN     : $blocked❌"
    echo "  BILLED/REDIRECT     : $billed🚫"
    echo "$CYAN ╚═════════════════════════════════════════════════════════════╝$NC"
    echo ""

    local date_str
    date_str=$(date +%Y%m%d_%H%M)
    local safe_carrier
    safe_carrier=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tag_part=""
    [ -n "$TAG" ] && tag_part="_$TAG"
    local base_name="R0scan@_${safe_carrier}_${date_str}${tag_part}"

    cp "$full_log" "$WORK_DIR/${base_name}_fullogs.txt" 2>/dev/null
    echo "$GREEN !] Full log saved to:$NC $WORK_DIR/${base_name}_fullogs.txt"

    if [ $zero_rated -gt 0 ]; then
        grep "^ZERO_RATED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_zero_rated.txt"
        echo "$GREEN !] Zero-rated list saved to:$NC $WORK_DIR/${base_name}_zero_rated.txt"
    fi
    if [ $blocked -gt 0 ]; then
        grep "^BLOCKED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_blocked.txt"
        echo "$GREEN !] Blocked list saved to:$NC $WORK_DIR/${base_name}_blocked.txt"
    fi
    if [ $billed -gt 0 ]; then
        grep "^BILLED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_billed.txt"
        echo "$GREEN !] Billed list saved to:$NC $WORK_DIR/${base_name}_billed.txt"
    fi
    if [ $bugs -gt 0 ]; then
        grep "^BUG" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_bugs.txt"
        echo "$GREEN !] Bugs list saved to:$NC $WORK_DIR/${base_name}_bugs.txt"
    fi

    show_next_prompt
}

# ─── Active Engine ────────────────────────────────────────
run_scan_active() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"

    local TARGET_FILE="$1"
    local TOTAL="$2"
    local TIMEOUT="$3"
    local BATCH="$4"
    local CARRIER="$5"
    local WORK_DIR="$6"
    local TAG="$7"
    local THREADS="$8"
    local DEADLOCK_MODE="$9"
    shift 9
    local DNS_MODE="$1"
    local BATCH_ENABLED="$2"
    local SCAN_MODE="$3"

    live=0
    dead=0
    local total_done=0
    local start_time
    start_time=$(date +%s)
    local anim_pos=0
    local detail_log="$RAT_LOGS/last_scan_active_detail.log"
    local full_log="$RAT_LOGS/last_scan_active.log"
    > "$detail_log"
    > "$full_log"

    export -f check_host_active
    export -f resolve_host
    export TIMEOUT
    export DNS_MODE
    export THREADS
    export TOTAL
    export detail_log
    export full_log

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "$YELLOW [!] Scan paused by user. Saving state...$NC"; show_next_prompt; return' INT TERM

    echo ""
    echo "$CYAN ╔═══════════════════════════════════════════════════════╗$NC"
    echo "$CYAN ║           Scanning in progress (ACTIVE MODE)...🚀    ║$NC"
    echo "$CYAN ║ [!] To pause: press CTRL+C                            ║$NC"
    echo "$CYAN ╚═══════════════════════════════════════════════════════╝$NC"
    echo ""

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    mkdir -p "$tmp_dir"

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ] || [ "$BATCH_ENABLED" = "N" ]; then
        batches=("$TARGET_FILE")
    else
        split -l "$BATCH" "$TARGET_FILE" "$tmp_dir/batch_"
        for f in "$tmp_dir"/batch_*; do
            [ -f "$f" ] && batches+=("$f")
        done
    fi

    local num_batches=${#batches[@]}
    local batch_idx=0

    for batch_file in "${batches[@]}"; do
        [ $PAUSED -eq 1 ] && break
        batch_idx=$((batch_idx + 1))
        local batch_hosts
        batch_hosts=$(cat "$batch_file" | grep -v '^$')
        [ -z "$batch_hosts" ] && continue
        local batch_size=$(echo "$batch_hosts" | wc -l)
        local results=()
        local batch_done=0

        local tmp_res="$RAT_CONFIG/tmp_batch_res"
        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c 'r=$(check_host_active "{}" "$TIMEOUT" "$DNS_MODE"); echo "$r {}"' > "$tmp_res" 2>/dev/null

        while IFS=' ' read -r result host; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            batch_done=$((batch_done + 1))
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local bar_display="[ ${CYAN}R@${NC}${frame#R@} ]"
            local elapsed_sec=$(( $(date +%s) - start_time ))
            local elapsed_min=$((elapsed_sec / 60))
            local elapsed_sec_rem=$((elapsed_sec % 60))
            local elapsed_str=$(printf "%02dm:%02ds" $elapsed_min $elapsed_sec_rem)
            local eta_str="Calculating..."
            if [ $total_done -gt 0 ] && [ $elapsed_sec -gt 5 ]; then
                local eta_sec=$(( (TOTAL - total_done) * elapsed_sec / total_done ))
                local eta_min=$((eta_sec / 60))
                local eta_sec_rem=$((eta_sec % 60))
                eta_str=$(printf "%02dm:%02ds" $eta_min $eta_sec_rem)
            fi
            clear_line
            printf "%s $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 LIVE:$live$NC | $RED❌ DEAD:$dead$NC" \
                "$bar_display" "$batch_done" "$batch_size" "$total_done" "$TOTAL"
            printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$elapsed_str" "$eta_str"
            printf "\033[1A"
        done < "$tmp_res"
        rm -f "$tmp_res"

        clear_line
        printf "\n"
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            local host="${entry##*|}"
            local code="${st#*|}"
            st="${st%|*}"
            if [ "$st" = "LIVE" ]; then
                echo "$GREEN$host -> LIVE (HTTP:$code)${NC}"
                echo "LIVE $host" >> "$detail_log"
                echo "[LIVE] $host" >> "$full_log"
            else
                echo "$RED$host -> DEAD${NC}"
                echo "DEAD $host" >> "$detail_log"
                echo "[DEAD] $host" >> "$full_log"
            fi
            echo ""
            sleep 0.02
        done

        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            st="${st%|*}"
            if [ "$st" = "LIVE" ]; then
                live=$((live+1))
            else
                dead=$((dead+1))
            fi
        done
        total_done=$((total_done + batch_size))

        if [ "$BATCH_ENABLED" != "n" ] && [ "$BATCH_ENABLED" != "N" ]; then
            rm -f "$batch_file"
        fi

        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$DEADLOCK_MODE" = "2" ]; then
            if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                echo "$RED[!] Network down. Waiting to auto-heal...$NC"
                while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do
                    sleep 5
                done
                echo "$GREEN[+] Network back.$NC"
            fi
        elif [ "$DEADLOCK_MODE" = "3" ]; then
            [ "$is_last" != "yes" ] && sleep 10
        elif [ "$DEADLOCK_MODE" = "4" ]; then
            [ "$is_last" != "yes" ] && sleep 4
        fi
    done

    trap - INT TERM
    local end_time
    end_time=$(date +%s)
    local duration_sec=$((end_time - start_time))
    local dur_h=$((duration_sec / 3600))
    local dur_m=$(((duration_sec % 3600) / 60))
    local dur_s=$((duration_sec % 60))
    local duration_str=$(printf "%02dh:%02dm:%02ds" $dur_h $dur_m $dur_s)

    echo ""
    echo "$CYAN ╔═════════════════════════════════════════════════════════════╗$NC"
    echo "$GREEN║ SCAN COMPLETED SUCCESSFULLY                                 ║$NC"
    echo "$CYAN ╠═════════════════════════════════════════════════════════════╣$NC"
    echo "  NETWORK CARRIER     : $CARRIER"
    echo "  TARGET LIST         : $(basename "$TARGET_FILE")"
    echo "  DNS CASCADE         : $DNS_MODE"
    echo "  SCAN DURATION       : $duration_str"
    echo "  TOTAL SCANNED       : $total_done / $TOTAL"
    echo "  🟢 LIVE             : $live"
    echo "  ❌ DEAD             : $dead"
    echo "$CYAN ╚═════════════════════════════════════════════════════════════╝$NC"
    echo ""

    local date_str
    date_str=$(date +%Y%m%d_%H%M)
    local safe_carrier
    safe_carrier=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tag_part=""
    [ -n "$TAG" ] && tag_part="_$TAG"
    local base_name="R0scan@_${safe_carrier}_${date_str}${tag_part}"

    cp "$full_log" "$WORK_DIR/${base_name}_fullogs.txt" 2>/dev/null
    echo "$GREEN !] Full log saved to:$NC $WORK_DIR/${base_name}_fullogs.txt"

    if [ $live -gt 0 ]; then
        grep "^LIVE" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_live.txt"
        echo "$GREEN !] Live list saved to:$NC $WORK_DIR/${base_name}_live.txt"
    fi
    if [ $dead -gt 0 ]; then
        grep "^DEAD" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${base_name}_dead.txt"
        echo "$GREEN !] Dead list saved to:$NC $WORK_DIR/${base_name}_dead.txt"
    fi

    show_next_prompt
}
