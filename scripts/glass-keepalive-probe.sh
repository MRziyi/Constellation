#!/usr/bin/env bash
# P1.8 / Phase β — FGS keepalive probe.
# Polls process state every N seconds. When the process disappears,
# captures comprehensive dumpsys to identify the cause.
#
# Usage: ./scripts/glass-keepalive-probe.sh [interval_s] [max_runtime_s]
# Default: 10s interval, 30 min runtime.
#
# Companion: docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md §6.2.5
# NOT set -e: grep returning empty (no whitelist match etc.) is normal and
# should not abort the script. Pipefail is also off to tolerate the same.
set -u

DEV=${ADB_DEV:-<glass-serial>}
PKG=${PKG:-com.constellation.glass}
INTERVAL=${1:-10}
MAX_SEC=${2:-1800}
TS=$(date +%Y%m%d-%H%M%S)
OUT=profile-out/keepalive-probe-$TS
mkdir -p "$OUT"

echo "[$TS] FGS keepalive probe → $OUT/"
echo "  device=$DEV  pkg=$PKG  interval=${INTERVAL}s  max_runtime=${MAX_SEC}s"
echo

START=$(date +%s)
LAST_PID=""
LAST_NOTIF_PRESENT=""
KILL_OBSERVED=false

# Helper: get current pid (empty if not running)
get_pid() {
    adb -s "$DEV" shell pidof "$PKG" 2>/dev/null | tr -d '\r'
}

# Helper: check if our notification is still posted (NOTIF_ID = 1001)
notif_present() {
    adb -s "$DEV" shell dumpsys notification 2>/dev/null \
        | grep -q "NotificationRecord.*$PKG" && echo y || echo n
}

# Helper: log a single sample line
log_sample() {
    local t=$1
    local elapsed=$((t - START))
    local pid=$2
    local notif=$3
    local topact=$4
    printf "[t+%03ds] pid=%s notif=%s top=%s\n" "$elapsed" "${pid:-DEAD}" "$notif" "$topact"
}

# === Initial baseline ===
{
    echo "# Keepalive probe baseline at t=0"
    echo "device=$DEV pkg=$PKG"
    echo
    echo "## Topmost activity"
    adb -s "$DEV" shell dumpsys activity activities 2>/dev/null | grep -E "topResumedActivity|mResumedActivity" | head -3
    echo
    echo "## App process record"
    adb -s "$DEV" shell dumpsys activity processes 2>/dev/null | grep -A 20 "$PKG" | head -30
    echo
    echo "## Power state"
    adb -s "$DEV" shell dumpsys power 2>/dev/null | head -50
    echo
    echo "## Device idle whitelist (system + user)"
    adb -s "$DEV" shell dumpsys deviceidle whitelist 2>/dev/null | grep -E "$PKG|^[0-9]" | head -30
    echo
    echo "## App standby bucket"
    adb -s "$DEV" shell dumpsys usagestats 2>/dev/null | grep -A 1 "$PKG" | head -10
    echo
    echo "## Notification posts"
    adb -s "$DEV" shell dumpsys notification 2>/dev/null | grep -B 1 -A 10 "$PKG" | head -40
} > "$OUT/baseline.txt"
echo "Baseline written → $OUT/baseline.txt"
echo

# === Watch loop ===
echo "Watching... (Ctrl-C to stop)"
echo "elapsed pid notif top" > "$OUT/samples.tsv"
while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))
    if [ "$ELAPSED" -ge "$MAX_SEC" ]; then
        echo "Max runtime reached ($MAX_SEC s) — exiting"
        break
    fi

    PID=$(get_pid)
    NOTIF=$(notif_present)
    TOP=$(adb -s "$DEV" shell dumpsys activity activities 2>/dev/null \
        | grep "topResumedActivity" | head -1 \
        | sed -n 's/.*ActivityRecord{[^ ]* u0 \([^ ]*\).*/\1/p')

    log_sample "$NOW" "$PID" "$NOTIF" "$TOP"
    echo -e "$ELAPSED\t$PID\t$NOTIF\t$TOP" >> "$OUT/samples.tsv"

    # === Kill detection ===
    if [ -n "$LAST_PID" ] && [ -z "$PID" ] && [ "$KILL_OBSERVED" = false ]; then
        KILL_OBSERVED=true
        echo
        echo "🔴 KILL DETECTED at t+${ELAPSED}s (last pid=$LAST_PID is gone)"
        echo "Capturing post-kill dumpsys..."
        {
            echo "# POST-KILL DUMP at t+${ELAPSED}s"
            echo "last pid: $LAST_PID  last notif: $LAST_NOTIF_PRESENT"
            echo
            echo "## logcat -d (recent crash / kill events)"
            adb -s "$DEV" shell "logcat -d -t 500" 2>/dev/null | grep -iE "$PKG|killing|low.memory|oom|fg.service|anr" | tail -50
            echo
            echo "## dumpsys activity processes (any references to $PKG)"
            adb -s "$DEV" shell dumpsys activity processes 2>/dev/null | grep -B 2 -A 10 "$PKG" | head -40
            echo
            echo "## dumpsys notification (still posted?)"
            adb -s "$DEV" shell dumpsys notification 2>/dev/null | grep -B 1 -A 5 "$PKG" | head -30
            echo
            echo "## dumpsys deviceidle"
            adb -s "$DEV" shell dumpsys deviceidle | head -50
        } > "$OUT/kill-moment.txt"
        echo "Post-kill dump → $OUT/kill-moment.txt"
    fi

    LAST_PID="$PID"
    LAST_NOTIF_PRESENT="$NOTIF"
    sleep "$INTERVAL"
done

echo
echo "Done. Samples → $OUT/samples.tsv"
[ "$KILL_OBSERVED" = true ] && echo "Kill captured → $OUT/kill-moment.txt" || echo "(no kill observed during this run)"
