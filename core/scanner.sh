# =========================================================
#  SCANNING ENGINES – SMOOTH BATCH COUNTER
# =========================================================

ANIM_FRAMES=("-R@-------" "--R@------" "---R@-----" "----R@----" "-----R@---" "------R@--" "-------R@-" "--------R@" "-------R@-" "------R@--" "-----R@---" "----R@----" "---R@-----" "--R@------" "-R@-------")
ANIM_LEN=${#ANIM_FRAMES[@]}

clear_line() { printf "\r\033[K"; }

check_host_zero() {
    local host="$1" timeout="$2" dns_mode="$3" scan_mode="$4"
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
        local port=443; [ "$proto" = "http" ] && port=80
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout "$timeout" --max-time "$timeout" --resolve "$host:$port:$ip" "$proto://$host" 2>/dev/null)
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

do_deadlock_wait() {
    case "$1" in
        1) return 0 ;;
        3) for i in $(seq 10 -1 1); do printf "\r$YELLOW[!] Auto-waiting: %2ds $NC" "$i"; sleep 1; done; printf "\r\033[K" ;;
        4) for i in $(seq 4 -1 1); do printf "\r$YELLOW[!] Auto-waiting: %2ds $NC" "$i"; sleep 1; done; printf "\r\033[K" ;;
    esac
}

# ─── Core Scan Loop (shared by both engines) ─────────────
run_scan_core() {
    local MODE="$1"
    shift
    local TARGET_FILE="$1" TOTAL="$2" TIMEOUT="$3" BATCH="$4" CARRIER="$5" WORK_DIR="$6" TAG="$7" THREADS="$8" DEADLOCK_MODE="$9"
    shift 9
    local START_POS="$1" INIT_A="$2" INIT_B="$3" INIT_C="$4" DNS_MODE="$5" BATCH_ENABLED="$6" SCAN_MODE="$7"

    local counter_a=$INIT_A counter_b=$INIT_B counter_c=$INIT_C
    local total_scanned=$START_POS

    local start_time
    if [ -n "$RESUME_ELAPSED" ] && [ "$RESUME_ELAPSED" -gt 0 ] 2>/dev/null; then
        start_time=$(( $(date +%s) - RESUME_ELAPSED ))
    else
        start_time=$(date +%s)
    fi

    local detail_log full_log
    if [ "$MODE" = "zero" ]; then
        detail_log="$RAT_LOGS/last_scan_detail.log"
        full_log="$RAT_LOGS/last_scan.log"
        export -f check_host_zero
    else
        detail_log="$RAT_LOGS/last_scan_active_detail.log"
        full_log="$RAT_LOGS/last_scan_active.log"
        export -f check_host_active
    fi

    [ "$START_POS" -eq 0 ] && { > "$detail_log"; > "$full_log"; }

    export -f resolve_host
    export TIMEOUT DNS_MODE SCAN_MODE THREADS TOTAL detail_log full_log MODE

    local PAUSED=0
    trap 'PAUSED=1; echo ""; echo "$YELLOW [!] Saving state...$NC"; STATE_FILE=$(save_scan_state); echo "$GREEN [+] Saved: $STATE_FILE$NC"; show_next_prompt; return' INT TERM

    echo "$CYAN ╔═══════════════════════════════════════════════════════╗$NC"
    if [ "$MODE" = "zero" ]; then
        echo "$CYAN ║           Scanning in progress...🚀                   ║$NC"
    else
        echo "$CYAN ║           Scanning in progress (ACTIVE)...🚀          ║$NC"
    fi
    echo "$CYAN ║ [!] To pause: press CTRL+C                            ║$NC"
    echo "$CYAN ╚═══════════════════════════════════════════════════════╝$NC"

    local tmp_dir="$RAT_CONFIG/tmp_batch"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    local scan_source="$TARGET_FILE"
    if [ "$START_POS" -gt 0 ]; then
        tail -n +$((START_POS + 1)) "$TARGET_FILE" > "$tmp_dir/resume.txt"
        scan_source="$tmp_dir/resume.txt"
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

        # ── PHASE 1: Test entire batch with live progress ──
        local tmp_res="$tmp_dir/res.txt"
        local prog="$tmp_dir/prog.bin"
        > "$tmp_res"; > "$prog"

        if [ "$MODE" = "zero" ]; then
            echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c '
                r=$(check_host_zero "{}" "$TIMEOUT" "$DNS_MODE" "$SCAN_MODE")
                echo "$r {}" >> "'"$tmp_res"'"
                echo -n "x" >> "'"$prog"'"
            ' &
        else
            echo "$batch_hosts" | xargs -P "$THREADS" -I {} bash -c '
                r=$(check_host_active "{}" "$TIMEOUT" "$DNS_MODE")
                echo "$r {}" >> "'"$tmp_res"'"
                echo -n "x" >> "'"$prog"'"
            ' &
        fi
        local XPID=$!

# Smooth counter: display moves toward real count 1-by-1
local display=0
while kill -0 $XPID 2>/dev/null; do
    local real=$(wc -c < "$prog" 2>/dev/null | tr -d ' ')
    [ -z "$real" ] && real=0

    # Move display toward real, one step at a time
    if [ $display -lt $real ]; then
        local gap=$(( real - display ))
        if [ $gap -gt 50 ]; then
            display=$(( display + gap / 10 ))   # big burst — catch up fast
        elif [ $gap -gt 10 ]; then
            display=$(( display + 2 ))           # medium burst
        else
            display=$(( display + 1 ))           # normal 1-by-1
        fi
    fi

    # Animation frame follows the DISPLAY value (smooth)
    local frame="${ANIM_FRAMES[$(( display % ANIM_LEN ))]}"

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
    if [ "$MODE" = "zero" ]; then
        printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 0Rated:$counter_a$NC | $RED🔥Bugs:$counter_c$NC" \
            "$frame" "$display" "$batch_size" "$total_scanned" "$TOTAL"
    else
        printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 LIVE:$counter_a$NC | $RED❌ DEAD:$counter_b$NC" \
            "$frame" "$display" "$batch_size" "$total_scanned" "$TOTAL"
    fi
    printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$estr" "$etastr"
    printf "\033[1A"
    sleep 0.04
done
wait $XPID 2>/dev/null

# Snap display to real count before revealing results
local real=$(wc -c < "$prog" 2>/dev/null | tr -d ' ')
[ -z "$real" ] && real=0
while [ $display -lt $real ]; do
    display=$(( display + 1 ))
    local frame="${ANIM_FRAMES[$(( display % ANIM_LEN ))]}"
    clear_line
    if [ "$MODE" = "zero" ]; then
        printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 0Rated:$counter_a$NC | $RED🔥Bugs:$counter_c$NC" \
            "$frame" "$display" "$batch_size" "$total_scanned" "$TOTAL"
    else
        printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 LIVE:$counter_a$NC | $RED❌ DEAD:$counter_b$NC" \
            "$frame" "$display" "$batch_size" "$total_scanned" "$TOTAL"
    fi
    sleep 0.01
done
clear_line
            if [ "$MODE" = "zero" ]; then
                printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 0Rated:$counter_a$NC | $RED🔥Bugs:$counter_c$NC" \
                    "$frame" "$done" "$batch_size" "$total_scanned" "$TOTAL"
            else
                printf "[ %s ] $AQUA⚡$NC %d/%d(⚙️) | $CYAN🌐$NC %d/%d | $GREEN🟢 LIVE:$counter_a$NC | $RED❌ DEAD:$counter_b$NC" \
                    "$frame" "$done" "$batch_size" "$total_scanned" "$TOTAL"
            fi
            printf "\n⚪Elapsed:%s | ⏳ETA:%s | 👻Pshd:0" "$estr" "$etastr"
            printf "\033[1A"
            sleep 0.01
        done
        wait $XPID 2>/dev/null
        clear_line

        # ── PHASE 2: Reveal all results fast (no blank lines) ──
        while IFS=' ' read -r result host; do
            [ -z "$host" ] && continue
            results+=("$result|$host")
            local st="${result%|*}"
            local code="${result#*|}"
            if [ "$MODE" = "zero" ]; then
                case "$st" in
                    ZERO_RATED) sc="$GREEN"; counter_a=$((counter_a+1)) ;;
                    BILLED) sc="$RED"; counter_b=$((counter_b+1)) ;;
                    BUG) sc="$RED"; counter_c=$((counter_c+1)) ;;
                    *) sc="$RED"; ;;
                esac
                echo "$WHITE$host $NC-> $sc$st $NC(HTTP:$WHITE$code$NC)"
            else
                if [ "$st" = "LIVE" ]; then
                    sc="$GREEN"; counter_a=$((counter_a+1))
                    echo "$GREEN$host -> LIVE (HTTP:$code)${NC}"
                else
                    sc="$RED"; counter_b=$((counter_b+1))
                    echo "$RED$host -> DEAD${NC}"
                fi
            fi
            echo "$st $host" >> "$detail_log"
            echo "[$st] $host" >> "$full_log"
        done < "$tmp_res"
        rm -f "$tmp_res" "$prog"

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
    if [ "$MODE" = "zero" ]; then
        echo "  ZERO-RATED FOUND    : $counter_a🟢"
        echo "  HIDDEN BUGS         : $counter_c🔥"
        echo "  BLOCKED/UNKNOWN     : $counter_b❌"
    else
        echo "  🟢 LIVE             : $counter_a"
        echo "  ❌ DEAD             : $counter_b"
    fi
    echo "$CYAN ╚═════════════════════════════════════════════════════════════╝$NC"

    local dstr2=$(date +%Y%m%d_%H%M)
    local sc2=$(echo "$CARRIER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
    local tp=""
    [ -n "$TAG" ] && tp="_$TAG"
    local bn="R0scan@_${sc2}_${dstr2}${tp}"

    cp "$full_log" "$WORK_DIR/${bn}_fullogs.txt" 2>/dev/null
    echo "$GREEN !] Full log: ${bn}_fullogs.txt$NC"

    if [ "$MODE" = "zero" ]; then
        [ $counter_a -gt 0 ] && grep "^ZERO_RATED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_zero_rated.txt" && echo "$GREEN !] Zero-rated: ${bn}_zero_rated.txt$NC"
        [ $counter_b -gt 0 ] && grep "^BLOCKED" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_blocked.txt" && echo "$GREEN !] Blocked: ${bn}_blocked.txt$NC"
        [ $counter_c -gt 0 ] && grep "^BUG" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_bugs.txt" && echo "$GREEN !] Bugs: ${bn}_bugs.txt$NC"
    else
        [ $counter_a -gt 0 ] && grep "^LIVE" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_live.txt" && echo "$GREEN !] Live list: ${bn}_live.txt$NC"
        [ $counter_b -gt 0 ] && grep "^DEAD" "$detail_log" | awk '{print $2}' > "$WORK_DIR/${bn}_dead.txt" && echo "$GREEN !] Dead list: ${bn}_dead.txt$NC"
    fi

    show_next_prompt
}

run_scan_zero() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    run_scan_core "zero" "$@"
}

run_scan_active() {
    mkdir -p "$RAT_LOGS" "$RAT_CONFIG"
    run_scan_core "active" "$@"
}
