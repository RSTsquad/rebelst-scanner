# =========================================================
#  SCANNING ENGINES – FIXED
# =========================================================

ANIM_FRAMES=("-R@-------" "--R@------" "---R@-----" "----R@----" "-----R@---" "------R@--" "-------R@-" "--------R@" "-------R@-" "------R@--" "-----R@---" "----R@----" "---R@-----" "--R@------" "-R@-------")
ANIM_LEN=${#ANIM_FRAMES[@]}

clear_line() { printf "\r\033[K"; }

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
            if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then echo "ZERO_RATED|$code"; return
            elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then echo "BILLED|$code"; return
            elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then echo "BUG|$code"; return
            else echo "BLOCKED|$code"; return; fi
        fi
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" "http://$host" 2>/dev/null)
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
        local port=443
        [ "$proto" = "http" ] && port=80
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done
    if [ "$code" != "000" ]; then
        if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "204" ]; then echo "ZERO_RATED|$code"
        elif [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then echo "BILLED|$code"
        elif [[ "$code" =~ ^[4-5][0-9][0-9]$ ]]; then echo "BUG|$code"
        else echo "BLOCKED|$code"; fi
    else
        echo "BLOCKED|000"
    fi
}

check_host_active() {
    local host="$1"
    local timeout="$2"
    local dns_mode="$3"
    local code="000"
    local ip=$(resolve_host "$host" "$dns_mode")
    [ -z "$ip" ] && { echo "DEAD"; return; }
    for proto in https http; do
        local port=443
        [ "$proto" = "http" ] && port=80
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
        [ -n "$http_code" ] && [ "$http_code" != "000" ] && { code="$http_code"; break; }
    done
    if [ "$code" != "000" ] && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
        echo "LIVE|$code"
    else
        echo "DEAD"
    fi
}

do_deadlock_wait() {
    case "$1" in
        1) return 0 ;;
        3) for i in $(seq 10 -1 1); do printf "\r$YELLOW[!] Auto-waiting: %2ds $NC" "$i"; sleep 1; done; printf "\r\033[K" ;;
        4) for i in $(seq 4 -1 1); do printf "\r$YELLOW[!] Auto-waiting: %2ds $NC" "$i"; sleep 1; done; printf "\r\033[K" ;;
    esac
}

# ─── Zero‑Rated Engine ────────────────────────────────────
run_scan_zero() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    local TARGET_FILE="$1" TOTAL="$2" TIMEOUT="$3" BATCH="$4" CARRIER="$5" WORK_DIR="$6" TAG="$7" THREADS="$8" DEADLOCK_MODE="$9"
    shift 9
    local START_POS="$1" INIT_ZR="$2" INIT_BLK="$3" INIT_BIL="$4" DNS_MODE="$5" BATCH_ENABLED="$6" SCAN_MODE="$7"

    zero_rated=$INIT_ZR
    blocked=$INIT_BLK
    billed=$INIT_BIL
    bugs=0
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
    if [ "$START_POS" -eq 0 ]; then > "$detail_log"; > "$full_log"; fi

    export -f check_host_zero
    export -f resolve_host
    export TIMEOUT DNS_MODE SCAN_MODE THREADS TOTAL detail_log full_log

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "$YELLOW [!] Saving state...$NC"; STATE_FILE=$(save_scan_state); echo "$GREEN [+] Saved: $STATE_FILE$NC"; show_next_prompt; return' INT TERM

    echo "$CYAN ╔═══════════════════════════════════════════════════════╗$NC"
    echo "$CYAN ║           Scanning in progress...🚀                   ║$NC"
    echo "$CYAN ║ [!] To pause: press CTRL+C                            ║$NC"
    echo "$CYAN ╚═══════════════════════════════════════════════════════╝$NC"

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    local scan_source="$TARGET_FILE"
    if [ "$START_POS" -gt 0 ]; then
        local resume_file="$tmp_dir/resume_hosts.txt"
        tail -n +$((START_POS + 1)) "$TARGET_FILE" > "$resume_file"
        scan_source="$resume_file"
    fi

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ] || [ "$BATCH_ENABLED" = "N" ]; then
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
        local batch_size=$(echo "$batch_hosts" | wc -l | tr -d ' ')
        local results=()

        # ── REAL-TIME SCAN (frozen 🌐 and counters) ──
        local tmp_res="$tmp_dir/res.txt"
        local prog="$tmp_dir/prog.txt"
        > "$tmp_res"; > "$prog"

        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c '
            r=$(check_host_zero "{}" "$TIMEOUT" "$DNS_MODE" "$SCAN_MODE")
            echo "$r {}" >> "'"$tmp_res"'"
            echo "." >> "'"$prog"'"
        ' &
        local XPID=$!

        while kill -0 $XPID 2>/dev/null; do
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local done=$(wc -l < "$prog" 2>/dev/null | tr -d ' ')
            [ -z "$done" ] && done=0
            local esec=$(( $(date +%s) - start_time ))
            local emin=$((esec / 60)); local erem=$((esec % 60))
            local estr=$(printf "%02dm:%02ds" $emin $erem)
            local etastr="Calculating..."
            if [ $total_scanned -gt 0 ] && [ $esec -gt 5 ]; then
                local eta=$(( (TOTAL - total_scanned) * esec / total_scanned ))
                local em=$((eta / 60)); local er=$((eta % 60))
                etastr=$(printf "%02dm:%02ds" $em $er)
            fi
            clear_line
            printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 0Rated:$zero_rated$NC | $RED🔥Bugs:$bugs$NC" \
                "$frame" "$done" "$batch_size" "$total_scanned" "$TOTAL"
            printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$estr" "$etastr"
            printf "\033[1A"
            sleep 0.1
        done
        wait $XPID 2>/dev/null
        clear_line

        # ── REVEAL RESULTS (fast, no blank lines) ──
        while IFS=' ' read -r result host; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            local st="${result%|*}"
            local code="${result#*|}"
            case "$st" in
                ZERO_RATED) sc="$GREEN" ;;
                BILLED) sc="$RED" ;;
                BUG) sc="$RED" ;;
                *) sc="$RED" ;;
            esac
            echo "$WHITE$host $NC-> $sc$st $NC(HTTP:$WHITE$code$NC)"
            echo "$st $host" >> "$detail_log"
            echo "[$st] $host" >> "$full_log"
        done < "$tmp_res"
        rm -f "$tmp_res" "$prog"

        # ── NOW UPDATE COUNTERS ──
        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            st="${st%|*}"
            case "$st" in
                ZERO_RATED) zero_rated=$((zero_rated+1)) ;;
                BILLED) billed=$((billed+1)) ;;
                BUG) bugs=$((bugs+1)) ;;
                *) blocked=$((blocked+1)) ;;
            esac
        done
        total_scanned=$((total_scanned + batch_size))

        [ "$BATCH_ENABLED" != "n" ] && [ "$BATCH_ENABLED" != "N" ] && rm -f "$batch_file"

        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$is_last" != "yes" ]; then
            if [ "$DEADLOCK_MODE" = "2" ]; then
                if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                    echo "$RED[!] Network down. Waiting to heal...$NC"
                    while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do sleep 2; done
                    echo "$GREEN[+] Network back.$NC"
                fi
            else
                do_deadlock_wait "$DEADLOCK_MODE"
            fi
        fi
    done

    trap - INT TERM
    rm -rf "$tmp_dir"

    local end_time=$(date +%s)
    local dsec=$((end_time - start_time))
    local dh=$((dsec/3600)); local dm=$(((dsec%3600)/60)); local ds=$((dsec%60))
    local dstr=$(printf "%02dh:%02dm:%02ds" $dh $dm $ds)

    echo "$CYAN ╔═════════════════════════════════════════════════════════════╗$NC"
    echo "$GREEN║ SCAN COMPLETED SUCCESSFULLY                                 ║$NC"
    echo "$CYAN ╠═════════════════════════════════════════════════════════════╣$NC"
    echo "  NETWORK CARRIER     : $CARRIER"
    echo "  TARGET LIST         : $(basename "$TARGET_FILE")"
    echo "  DNS CASCADE         : $DNS_MODE"
    echo "  SCAN DURATION       : $dstr"
    echo "  TOTAL SCANNED       : $total_scanned / $TOTAL"
    echo "  ZERO-RATED FOUND    : $zero_rated🟢"
    echo "  HIDDEN BUGS         : $bugs🔥"
    echo "  BLOCKED/UNKNOWN     : $blocked❌"
    echo "  BILLED/REDIRECT     : $billed🚫"
    echo "$CYAN ╚═════════════════════════════════════════════════════════════╝$NC"

    local dstr2=$(date +%Y%m%d_%H%M)
    local sc2=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tp=""
    [ -n "$TAG" ] && tp="_$TAG"
    local bn="R0scan@_${sc2}_${dstr2}${tp}"

    cp "$full_log" "$WORK_DIR/${bn}_fullogs.txt" 2>/dev/null
    echo "$GREEN !] Full log: ${bn}_fullogs.txt$NC"
    [ $zero_rated -gt 0 ] && grep "^ZERO_RATED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_zero_rated.txt" && echo "$GREEN !] Zero-rated: ${bn}_zero_rated.txt$NC"
    [ $blocked -gt 0 ] && grep "^BLOCKED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_blocked.txt" && echo "$GREEN !] Blocked: ${bn}_blocked.txt$NC"
    [ $billed -gt 0 ] && grep "^BILLED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_billed.txt" && echo "$GREEN !] Billed: ${bn}_billed.txt$NC"
    [ $bugs -gt 0 ] && grep "^BUG" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_bugs.txt" && echo "$GREEN !] Bugs: ${bn}_bugs.txt$NC"

    show_next_prompt
}

# ─── Active Engine ────────────────────────────────────────
run_scan_active() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    local TARGET_FILE="$1" TOTAL="$2" TIMEOUT="$3" BATCH="$4" CARRIER="$5" WORK_DIR="$6" TAG="$7" THREADS="$8" DEADLOCK_MODE="$9"
    shift 9
    local DNS_MODE="$1" BATCH_ENABLED="$2" SCAN_MODE="$3"

    live=0
    dead=0
    local total_done=0
    local start_time=$(date +%s)
    local anim_pos=0
    local detail_log="$RAT_LOGS/last_scan_active_detail.log"
    local full_log="$RAT_LOGS/last_scan_active.log"
    > "$detail_log"; > "$full_log"

    export -f check_host_active
    export -f resolve_host
    export TIMEOUT DNS_MODE THREADS TOTAL detail_log full_log

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "$YELLOW [!] Saving state...$NC"; show_next_prompt; return' INT TERM

    echo "$CYAN ╔═══════════════════════════════════════════════════════╗$NC"
    echo "$CYAN ║           Scanning in progress (ACTIVE)...🚀          ║$NC"
    echo "$CYAN ║ [!] To pause: press CTRL+C                            ║$NC"
    echo "$CYAN ╚═══════════════════════════════════════════════════════╝$NC"

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    local batches=()
    if [ "$BATCH_ENABLED" = "n" ] || [ "$BATCH_ENABLED" = "N" ]; then
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
        local batch_size=$(echo "$batch_hosts" | wc -l | tr -d ' ')
        local results=()

        local tmp_res="$tmp_dir/res.txt"
        local prog="$tmp_dir/prog.txt"
        > "$tmp_res"; > "$prog"

        echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c '
            r=$(check_host_active "{}" "$TIMEOUT" "$DNS_MODE")
            echo "$r {}" >> "'"$tmp_res"'"
            echo "." >> "'"$prog"'"
        ' &
        local XPID=$!

        while kill -0 $XPID 2>/dev/null; do
            anim_pos=$(( (anim_pos + 1) % ANIM_LEN ))
            local frame="${ANIM_FRAMES[anim_pos]}"
            local done=$(wc -l < "$prog" 2>/dev/null | tr -d ' ')
            [ -z "$done" ] && done=0
            local esec=$(( $(date +%s) - start_time ))
            local emin=$((esec / 60)); local erem=$((esec % 60))
            local estr=$(printf "%02dm:%02ds" $emin $erem)
            local etastr="Calculating..."
            if [ $total_done -gt 0 ] && [ $esec -gt 5 ]; then
                local eta=$(( (TOTAL - total_done) * esec / total_done ))
                local em=$((eta / 60)); local er=$((eta % 60))
                etastr=$(printf "%02dm:%02ds" $em $er)
            fi
            clear_line
            printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 LIVE:$live$NC | $RED❌ DEAD:$dead$NC" \
                "$frame" "$done" "$batch_size" "$total_done" "$TOTAL"
            printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$estr" "$etastr"
            printf "\033[1A"
            sleep 0.1
        done
        wait $XPID 2>/dev/null
        clear_line

        while IFS=' ' read -r result host; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            local st="${result%|*}"
            local code="${result#*|}"
            if [ "$st" = "LIVE" ]; then
                echo "$GREEN$host -> LIVE (HTTP:$code)${NC}"
                echo "LIVE $host" >> "$detail_log"
                echo "[LIVE] $host" >> "$full_log"
            else
                echo "$RED$host -> DEAD${NC}"
                echo "DEAD $host" >> "$detail_log"
                echo "[DEAD] $host" >> "$full_log"
            fi
        done < "$tmp_res"
        rm -f "$tmp_res" "$prog"

        for entry in "${results[@]}"; do
            local st="${entry%|*}"
            st="${st%|*}"
            [ "$st" = "LIVE" ] && live=$((live+1)) || dead=$((dead+1))
        done
        total_done=$((total_done + batch_size))

        [ "$BATCH_ENABLED" != "n" ] && [ "$BATCH_ENABLED" != "N" ] && rm -f "$batch_file"

        is_last=$([ $batch_idx -eq $num_batches ] && echo "yes" || echo "no")
        if [ "$is_last" != "yes" ]; then
            if [ "$DEADLOCK_MODE" = "2" ]; then
                if ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
                    echo "$RED[!] Network down. Waiting...$NC"
                    while ! curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; do sleep 2; done
                    echo "$GREEN[+] Network back.$NC"
                fi
            else
                do_deadlock_wait "$DEADLOCK_MODE"
            fi
        fi
    done

    trap - INT TERM
    rm -rf "$tmp_dir"

    local end_time=$(date +%s)
    local dsec=$((end_time - start_time))
    local dh=$((dsec/3600)); local dm=$(((dsec%3600)/60)); local ds=$((dsec%60))
    local dstr=$(printf "%02dh:%02dm:%02ds" $dh $dm $ds)

    echo "$CYAN ╔═════════════════════════════════════════════════════════════╗$NC"
    echo "$GREEN║ SCAN COMPLETED SUCCESSFULLY                                 ║$NC"
    echo "$CYAN ╠═════════════════════════════════════════════════════════════╣$NC"
    echo "  NETWORK CARRIER     : $CARRIER"
    echo "  TARGET LIST         : $(basename "$TARGET_FILE")"
    echo "  DNS CASCADE         : $DNS_MODE"
    echo "  SCAN DURATION       : $dstr"
    echo "  TOTAL SCANNED       : $total_done / $TOTAL"
    echo "  🟢 LIVE             : $live"
    echo "  ❌ DEAD             : $dead"
    echo "$CYAN ╚═════════════════════════════════════════════════════════════╝$NC"

    local dstr2=$(date +%Y%m%d_%H%M)
    local sc2=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tp=""
    [ -n "$TAG" ] && tp="_$TAG"
    local bn="R0scan@_${sc2}_${dstr2}${tp}"

    cp "$full_log" "$WORK_DIR/${bn}_fullogs.txt" 2>/dev/null
    echo "$GREEN !] Full log: ${bn}_fullogs.txt$NC"
    [ $live -gt 0 ] && grep "^LIVE" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_live.txt" && echo "$GREEN !] Live list: ${bn}_live.txt$NC"
    [ $dead -gt 0 ] && grep "^DEAD" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_dead.txt" && echo "$GREEN !] Dead list: ${bn}_dead.txt$NC"

    show_next_prompt
}
